#!/usr/bin/env bash
# PHA 2 — mutation tester. ĐO chất lượng test, KHÔNG sửa code thật vĩnh viễn.
#
# Áp các mutation văn bản lên Core/Models/Services/Stores, chạy `swift test`, phân loại
# killed / survived / skipped, rồi LUÔN khôi phục file (git checkout + trap EXIT). Mọi file
# về nguyên trạng sau khi chạy — `git status --porcelain` phải rỗng.
#
# Catalogue (thuần văn bản, dễ áp + dễ hoàn tác; ~tối đa bằng nhau mỗi loại):
#   cmp    đảo so sánh   ==/!=/<=/>=
#   guard  phủ định      guard/if <cond>  ->  guard/if !(<cond>)
#   const  đổi hằng số   0 <-> 1  (off-by-one cổ điển)
#   bool   đảo literal    true <-> false
# Phạm vi: Core/ Models/ Services/ Stores/. Bỏ Views/ (test GUI mỏng, nhiễu).
# Cap MAX_MUTATIONS (mặc định 80) để một lượt dưới ~20 phút.
#
# Phân loại: `: error:` trong output → build gãy → skipped (không tính killed, tránh thổi
# phồng kill rate). rc!=0 (không có error build) → killed. rc==0 → survived.
set -uo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
SCOPE=(Core Models Services Stores)
MAX_MUTATIONS="${MAX_MUTATIONS:-80}"
WORK="$(mktemp -d)"
SURVIVED_TSV="$WORK/survived.tsv"
RUNLOG="$WORK/run.out"
: > "$SURVIVED_TSV"

restore_all() { git checkout -q -- "${SCOPE[@]}" 2>/dev/null || true; }

# Khôi phục bằng `git checkout --` nghĩa là XOÁ mọi sửa đổi chưa commit trong scope.
# Đo được: thêm một dòng vào Core/DocumentIR.swift rồi chạy đúng lệnh khôi phục đó →
# dòng biến mất, không một lời cảnh báo. Với một script nằm trong repo và người ta chạy
# tại máy mình, đó là mất việc thật. Từ chối chạy còn hơn âm thầm nuốt.
dirty="$(git status --porcelain -- "${SCOPE[@]}" 2>/dev/null)"
if [ -n "$dirty" ]; then
  {
    echo "Từ chối chạy: có thay đổi chưa commit trong ${SCOPE[*]}:"
    echo "$dirty"
    echo
    echo "Script khôi phục sau mỗi mutation bằng 'git checkout --', thao tác đó sẽ XOÁ"
    echo "những thay đổi trên. Hãy commit hoặc 'git stash' trước khi chạy."
  } >&2
  exit 1
fi

trap 'restore_all' EXIT INT TERM

# classify <logfile> <rc>  → đặt $status toàn cục
classify() {
  if grep -qE '\.swift:[0-9]+:[0-9]+: error:' "$1"; then status=skipped
  elif [ "$2" -ne 0 ]; then status=killed
  else status=survived; fi
}

# apply_mutation <file> <line> <op>  → sửa đúng dòng đó (python). THOÁT !=0 khi không áp được.
apply_mutation() {
python3 - "$1" "$2" "$3" <<'PY'
import sys, re
path, line, op = sys.argv[1], int(sys.argv[2]), sys.argv[3]
try:
    lines = open(path, encoding='utf-8').read().split('\n')
except Exception:
    sys.exit(1)
if line < 1 or line > len(lines):
    sys.exit(1)
s = lines[line - 1]

def flip_cmp(t):
    m = re.search(r'(?<![<>=!])(<=|>=|==|!=)(?![=])', t)
    if not m:
        return None
    repl = {'<=': '>=', '>=': '<=', '==': '!=', '!=': '=='}[m.group(1)]
    return t[:m.start()] + repl + t[m.end():]

def flip_const(t):
    m = re.search(r'(?<![\w.])([01])(?![\w.])', t)
    if not m:
        return None
    return t[:m.start()] + ('1' if m.group(1) == '0' else '0') + t[m.end():]

def flip_bool(t):
    m = re.search(r'\b(true|false)\b', t)
    if not m:
        return None
    return t[:m.start()] + ('false' if m.group(1) == 'true' else 'true') + t[m.end():]

def neg_cond(t):
    m = re.search(r'\bguard\b\s+(.+?)\belse\b', t)
    if m:
        return t[:m.start(1)] + '!(' + m.group(1) + ')' + t[m.end(1):]
    m = re.search(r'\bif\b\s+(.+?)\{', t)
    if m:
        return t[:m.start(1)] + '!(' + m.group(1) + ')' + t[m.end(1):]
    return None

fn = {'cmp': flip_cmp, 'guard': neg_cond, 'const': flip_const, 'bool': flip_bool}.get(op)
if not fn:
    sys.exit(1)
ns = fn(s)
if not ns or ns == s:
    sys.exit(1)
lines[line - 1] = ns
open(path, 'w', encoding='utf-8').write('\n'.join(lines))
PY
}

# ── --self-test: áp 1 mutation đã biết chắc ĐỎ, phải báo killed ──────────────────────────
if [ "${1:-}" = "--self-test" ]; then
  echo "[self-test] mutation đã biết đỏ: bỏ '!' trong guard cancel của PDFSearchRunner"
  echo "[self-test]   (guard !Task.isCancelled -> guard Task.isCancelled) → testCancelStopsDelivery phải đỏ"
  f="Stores/DocumentStore+Search.swift"
  perl -i -pe 's/guard !Task\.isCancelled/guard Task.isCancelled/' "$f"
  swift test --filter PDFSearchRunnerTests >"$RUNLOG" 2>&1; rc=$?
  classify "$RUNLOG" "$rc"
  restore_all
  if [ "$status" = "killed" ]; then
    echo "[self-test] KILLED ✓ — pipeline bắt được mutation đã biết đỏ (status=$status)."
    exit 0
  fi
  echo "[self-test] THẤT BẠI — mutation đã biết đỏ lại $status. Pipeline mutation đang sai." >&2
  exit 1
fi

# ── sinh candidate (file<TAB>line<TAB>op), cap đều mỗi loại ──────────────────────────────
CANDS="$WORK/cands.tsv"
python3 - "$MAX_MUTATIONS" <<'PY' > "$CANDS"
import sys, os, re
maxn = int(sys.argv[1])
dirs = ["Core", "Models", "Services", "Stores"]
per = max(1, maxn // 4)
counts = {"cmp": 0, "guard": 0, "const": 0, "bool": 0}
order = ["cmp", "const", "bool", "guard"]  # ưu tiên op ít nhiễu trước
comp = re.compile(r'(?<![<>=!])(?:<=|>=|==|!=)(?![=])')
const = re.compile(r'(?<![\w.])[01](?![\w.])')
boolt = re.compile(r'\b(?:true|false)\b')
guardif = re.compile(r'\b(?:guard|if)\b\s+.+?(?:\belse\b|\{)')
cands = []
done = False
for d in dirs:
    if done:
        break
    if not os.path.isdir(d):
        continue
    for root, _, files in os.walk(d):
        if done:
            break
        for fn in files:
            if not fn.endswith(".swift"):
                continue
            p = os.path.join(root, fn)
            try:
                raw = open(p, encoding='utf-8').read().split('\n')
            except Exception:
                continue
            for i, line in enumerate(raw, 1):
                s = line.strip()
                if not s or s.startswith("//") or s.startswith("*"):
                    continue
                # chọn op đầu tiên khớp (theo `order`) còn dưới ngưỡng
                hits = []
                if comp.search(line): hits.append("cmp")
                if const.search(line): hits.append("const")
                if boolt.search(line): hits.append("bool")
                if guardif.search(line): hits.append("guard")
                op = next((o for o in order if o in hits and counts[o] < per), None)
                if op:
                    cands.append((p, i, op))
                    counts[op] += 1
                    if sum(counts.values()) >= maxn:
                        done = True
                        break
            if done:
                break
for p, i, op in cands:
    print("%s\t%d\t%s" % (p, i, op))
PY

total=$(wc -l < "$CANDS" | tr -d ' ')
echo "[mutation] $total candidate(s) (cap $MAX_MUTATIONS, ~$((MAX_MUTATIONS/4))/loại). Phạm vi: ${SCOPE[*]}"
echo "[mutation] warm build (để mỗi mutation chỉ rebuild incremental)..."
swift build --build-tests >/dev/null 2>&1 || true

# ── vòng lặp chính ───────────────────────────────────────────────────────────────────────
killed=0; survived=0; skipped=0; idx=0
while IFS=$'\t' read -r f line op; do
  [ -z "${f:-}" ] && continue
  idx=$((idx + 1))
  if apply_mutation "$f" "$line" "$op" 2>/dev/null; then
    swift test >"$RUNLOG" 2>&1; rc=$?
    classify "$RUNLOG" "$rc"
  else
    status=skipped   # candidate không áp được (regex trượt sau khi sinh) → không tính killed
  fi
  restore_all
  case "$status" in
    killed)   killed=$((killed + 1)) ;;
    survived) survived=$((survived + 1)); printf "%s\t%s\t%s\n" "$f" "$line" "$op" >> "$SURVIVED_TSV" ;;
    skipped)  skipped=$((skipped + 1)) ;;
  esac
  printf "  [%02d/%d] %-9s %s:%s (%s)\n" "$idx" "$total" "$status" "$f" "$line" "$op"
done < "$CANDS"

effective=$((killed + survived))
if [ "$effective" -gt 0 ]; then
  rate=$(python3 -c "print('%.0f%%' % (100.0 * $killed / $effective))")
else
  rate="n/a"
fi
echo "────────────────────────────────────────────────────────────────────────"
echo "mutation SUMMARY: killed=$killed survived=$survived skipped=$skipped  effective=$effective  kill rate=$rate"
echo "survived (file<TAB>line<TAB>op):"
cat "$SURVIVED_TSV"
echo "────────────────────────────────────────────────────────────────────────"
