#!/usr/bin/env bash
# Chặn chuỗi tiếng Việt hardcode quay lại vỏ Flutter.
#
# Song song với script/audit_i18n_strings.sh (app macOS). Vỏ desktop từng có
# 142 chuỗi tiếng Việt nằm thẳng trong code, khiến giao diện Linux/Windows chỉ
# có một ngôn ngữ trong khi macOS có hai. Sau khi đưa hết qua L(), gate này giữ
# cho nó không quay lại từng chuỗi một.
#
# Chỉ soi *string literal*, không soi comment: comment tiếng Việt là tài liệu
# code, không phải chuỗi giao diện.
#
# Ngoại lệ được đánh dấu bằng `// i18n-exempt: <lý do>` trên cùng dòng. Trường
# hợp thật duy nhất là tên một ngôn ngữ trong bộ chọn ngôn ngữ ("Tiếng Việt"),
# thứ tuyệt đối không được dịch: người không đọc được UI hiện tại tìm ra ngôn
# ngữ của mình bằng cách nhận ra chính tên đó.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

# BSD grep khớp bracket class THEO BYTE ngoài locale UTF-8, khiến dấu câu nhiều
# byte như "•" đụng byte nối của các chữ có dấu và báo nhầm. Xem ghi chú dài
# trong script/audit_i18n_strings.sh.
export LC_ALL=en_US.UTF-8

VN_CHARS='àáâãèéêìíòóôõùúýăđĩũơưạảấầẩẫậắằẳẵặẹẻẽềểễệỉịọỏốồổỗộớờởỡợụủứừửữựỳỵỷỹÀÁÂÃÈÉÊÌÍÒÓÔÕÙÚÝĂĐĨŨƠƯẠẢẤẦẨẪẬẮẰẲẴẶẸẺẼỀỂỄỆỈỊỌỎỐỒỔỖỘỚỜỞỠỢỤỦỨỪỬỮỰỲỴỶỸ'
SHELL_LIB="Shell/azpdf_desktop/lib"
TABLE="$SHELL_LIB/src/l10n/strings.dart"

scan() {
  local target="$1"
  # Đánh số dòng TRƯỚC để số dòng báo ra vẫn đúng sau khi lọc.
  grep -rn '' --include='*.dart' "$target" \
    | grep -v "^$TABLE:" \
    | grep -v 'i18n-exempt:' \
    | sed 's|//.*$||' \
    | grep "'" \
    | grep "[$VN_CHARS]" || true
}

self_test() {
  tmp="$(mktemp -d)"
  trap 'rm -rf "$tmp"' EXIT
  mkdir -p "$tmp/lib"
  printf "import 'x';\nfinal a = Text('Xin chào');\n" >"$tmp/lib/must_fail.dart"
  printf "import 'x';\n// chú thích tiếng Việt\nfinal b = Text(L('hello'));\n" >"$tmp/lib/must_pass.dart"
  printf "import 'x';\nfinal c = Text('Tiếng Việt'); // i18n-exempt: tên ngôn ngữ\n" >"$tmp/lib/exempt.dart"
  # Dấu câu nhiều byte KHÔNG phải tiếng Việt — bẫy locale, xem ghi chú trên.
  printf "import 'x';\nfinal d = Text('v1.0 • 14+ … — ·');\n" >"$tmp/lib/punct.dart"

  if [[ -z "$(scan "$tmp/lib/must_fail.dart")" ]]; then
    echo "self-test hỏng: không phát hiện chuỗi tiếng Việt trần" >&2; exit 1
  fi
  if [[ -n "$(scan "$tmp/lib/must_pass.dart")" ]]; then
    echo "self-test hỏng: comment tiếng Việt bị tính là chuỗi giao diện" >&2; exit 1
  fi
  if [[ -n "$(scan "$tmp/lib/exempt.dart")" ]]; then
    echo "self-test hỏng: dòng có i18n-exempt vẫn bị báo" >&2; exit 1
  fi
  if [[ -n "$(scan "$tmp/lib/punct.dart")" ]]; then
    echo "self-test hỏng: dấu câu (• … — ·) bị đọc thành tiếng Việt — lớp dấu đang khớp theo BYTE; kiểm LC_ALL có phải locale UTF-8 tồn tại trên máy này" >&2; exit 1
  fi
  echo "self-test gate i18n vỏ Flutter: đạt."
}

if [[ "${1:-}" == "--self-test" ]]; then
  self_test
  exit 0
fi

if [[ ! -d "$SHELL_LIB" ]]; then
  echo "Không thấy $SHELL_LIB — gate này không quét được gì." >&2
  exit 1
fi

hits="$(scan "$SHELL_LIB")"
if [[ -n "$hits" ]]; then
  echo "$hits" >&2
  echo "Gate i18n vỏ Flutter: có chuỗi tiếng Việt hardcode. Đưa qua L('key') và thêm cặp vào CẢ HAI bảng trong $TABLE (test chẵn lẻ sẽ bắt nếu thiếu một bên). Ngoại lệ thật thì đánh dấu // i18n-exempt: <lý do>." >&2
  exit 1
fi

echo "Gate i18n vỏ Flutter: đạt — không còn chuỗi tiếng Việt hardcode."
