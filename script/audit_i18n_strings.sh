#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# Files already swept to L(_:) (i18n sub-slice 1, plan.md). A file not listed
# here is not checked at all — extend this list one entry per file as later
# sub-slices sweep the remaining ~14 views + Stores/Services, so the gate
# keeps pace with the sweep instead of blocking every not-yet-swept view.
SWEPT_FILES=(
  "App/OpenPaperApp.swift"
  "Models/ShapeAnnotation.swift"
  "Support/Localization.swift"
  "Views/ContentView.swift"
  "Views/DocumentPropertiesSheet.swift"
  "Views/EmptyDocumentView.swift"
  "Views/SidebarView.swift"
  "Views/SettingsView.swift"
)

# Uppercase + lowercase Vietnamese diacritics, spelled out explicitly: BSD
# grep/rg regex here has no \p{L}/Unicode-script class to lean on.
VN_CHARS='àáâãèéêìíòóôõùúýăđĩũơưạảấầẩẫậắằẳẵặẹẻẽềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂĐĨŨƠƯẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸ'

EN_STRINGS="Resources/en.lproj/Localizable.strings"

# Prints "file:line:content" for every hit; nothing if the file is clean.
# Strips `//` comments first — a comment quoting the pre-sweep Vietnamese
# string (allowed, e.g. ContentView.swift's shape-menu comment) must not
# trip the gate. Only lines that still contain a `"` after stripping are
# checked, since a literal string is what this gate exists to catch, not
# prose; this also means a `/* */` block comment holding Vietnamese text
# next to an unrelated `"` on the same line could false-positive — the
# convention in swept files is `//` comments only, per plan.md.
# A line ending in `// i18n-exempt: <reason>` is skipped. The one real case is
# a language's own name in a language picker ("Tiếng Việt"), which must NOT be
# translated — someone who cannot read the current UI finds their language by
# recognising it. The marker is dropped before comments are stripped, and
# requires a written reason so it cannot become a silent mute button.
scan_file() {
  local file="$1"
  rg -v 'i18n-exempt:' "$file" | sed 's|//.*$||' | rg -n '"' | rg "[$VN_CHARS]" | sed "s|^|$file:|" || true
}

# Every plain L("...") key must have an entry in the en strings table. A key
# missing from BOTH tables never crashes — it silently renders as its raw key
# text under en (invisible, since en is an identity map) AND under vi (an
# English leak). The diacritics scan above cannot catch this: the key is pure
# ASCII. Caught for real in review: L("Export Current Page…") shipped with no
# entry, showing English in the vi menu. Interpolated keys (L("Page \(n)"))
# are excluded — their .strings key is the %lld format string, not the source
# text; the LocalizationTests parity test still covers their en/vi symmetry.
scan_missing_keys() {
  local file="$1"
  sed 's|//.*$||' "$file" | rg -o 'L\("[^"\\]+"\)' | sed -E 's/^L\("//; s/"\)$//' | sort -u | {
    while IFS= read -r key; do
      if ! rg -qF "\"$key\" = " "$EN_STRINGS"; then
        echo "$file: L(\"$key\") has no entry in $EN_STRINGS"
      fi
    done
  } || true
}

run_audit() {
  local hits=0
  for file in "${SWEPT_FILES[@]}"; do
    local out
    out="$(scan_file "$file"; scan_missing_keys "$file")"
    if [[ -n "$out" ]]; then
      echo "$out" >&2
      hits=1
    fi
  done
  return $hits
}

self_test() {
  # Not `local`: the EXIT trap below fires after this function has already
  # returned, once the whole script exits — it needs $tmp to still resolve
  # in the (by then) global scope.
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT

  printf 'import SwiftUI\nText("Xin chào")\n' >"$tmp/must_fail.swift"
  printf 'import SwiftUI\nText(L("Hello")) // chú thích tiếng Việt\n' >"$tmp/must_pass.swift"
  printf 'import SwiftUI\nText(L("Key Missing From Strings ZZZ"))\n' >"$tmp/must_fail_key.swift"
  printf 'import SwiftUI\nText(L("Cancel"))\n' >"$tmp/must_pass_key.swift"

  if [[ -z "$(scan_file "$tmp/must_fail.swift")" ]]; then
    echo "self-test failed: bare Vietnamese string literal was not detected" >&2
    exit 1
  fi
  if [[ -n "$(scan_file "$tmp/must_pass.swift")" ]]; then
    echo "self-test failed: L(_:) call flagged because of a Vietnamese *comment* (comments must be stripped, not fail the gate)" >&2
    exit 1
  fi
  if [[ -z "$(scan_missing_keys "$tmp/must_fail_key.swift")" ]]; then
    echo "self-test failed: L(_:) key absent from $EN_STRINGS was not detected" >&2
    exit 1
  fi
  if [[ -n "$(scan_missing_keys "$tmp/must_pass_key.swift")" ]]; then
    echo "self-test failed: L(_:) key that exists in $EN_STRINGS was flagged as missing" >&2
    exit 1
  fi
  if ! run_audit; then
    echo "self-test failed: real audit over SWEPT_FILES is not clean" >&2
    exit 1
  fi

  echo "i18n audit self-test passed."
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if run_audit; then
  echo "i18n audit passed: no literal Vietnamese strings or unresolved L(_:) keys in swept files."
else
  echo "i18n audit failed (see lines above): either a literal Vietnamese string in an already-swept file (route it through L(_:) — see Support/Localization.swift) or an L(_:) key with no entry in $EN_STRINGS (add it to BOTH en and vi tables; the parity test enforces the pair)." >&2
  exit 1
fi
