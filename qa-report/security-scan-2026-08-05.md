# Quét bảo mật — 2026-08-05

**Phạm vi:** cây làm việc tại `2a60afd` + README cập nhật · bí mật, supply chain, quyền CI,
5 gate chính sách, bề mặt tấn công mới của Pha 3.5.

**Kết quả: 0 CRITICAL · 0 HIGH · 2 MEDIUM · 1 LOW.**

---

## Kiểm soát đã xác minh là ĐANG hoạt động

| # | Kiểm soát | Bằng chứng |
|---|---|---|
| 1 | Không có bí mật trong cây | Quét mẫu AWS/GitHub/OpenAI/Slack token + PEM private key → 0 khớp. `git ls-files` không có `.env`/`.pem`/`.p12`/`.key`/`keystore`. |
| 2 | Quyền CI tối thiểu | Đúng **một** workflow (`ci.yml`), `permissions: contents: read`. Không có job nào xin quyền ghi. |
| 3 | Không có `pull_request_target` | Không workflow nào dùng — nên PR từ fork không chạy được với secret của repo. |
| 4 | 4 gate chính sách xanh | `audit_local_first`, `audit_portable_core`, `audit_i18n_strings`, `audit_shell_i18n` → rc=0. (`audit_runtime.sh` là helper **có tham số** `<runtime-dir> <exe>`, không phải gate độc lập — gọi trống sẽ ra usage + rc≠0. Không phải lỗi.) |
| 5 | **Gate tự chứng minh mình đang quét** | CI cấy `URLSession.shared` thật vào `Core/__ci_probe.swift` mỗi lần chạy và **fail build nếu gate không bắt được**; tương tự cấy `import PDFKit` cho portable-core, helper Python không self-contained và symlink thoát thư mục cho `audit_runtime`. Đây là bản vá cho lỗi fail-open lịch sử (hai gate "pass" nhiều tháng mà chưa quét gì). |
| 6 | SwiftPM: bề mặt cực nhỏ, ghim chặt | Đúng **1** dependency (`swift-subprocess`), ghim theo **commit SHA** `11633673…`, không phải khoảng phiên bản. Không thể bị đẩy phiên bản mới ngầm. |
| 7 | Flutter: 3 gói, đã khoá | `file_selector`, `url_launcher`, `window_manager`. `pubspec.yaml` dùng caret nhưng có `Shell/azpdf_desktop/pubspec.lock` + `Packaging/flatpak/flutter-3.44.0-tools-pubspec.lock` ⇒ phiên bản thực tế được ghim khi dựng. |
| 8 | **Script dựng runtime không tải gì từ mạng** | `build_{mupdf,ocrmypdf,pyhanko,verapdf}_runtime.sh`: 0 lần `curl`/`wget`/`pip install`/`git clone`. Chúng bắt người vận hành trỏ `GHOSTSCRIPT_RESOURCE_DIR` v.v. và **dừng cứng** nếu thiếu (`: "${VAR:?...}"`). Không có cửa tải-rồi-chạy. |
| 9 | Pha 3.5 không thêm bề mặt tấn công | Hai hàm thuần (`letterRatio`, `flaggedPageIndices`), một `NSAlert`, hai script chỉ dùng khi phát triển (`make_scanned_fixtures.swift`, `ocr_lines.swift`) nằm ngoài mọi target (`script` có trong `exclude` của `Package.swift`). Không I/O mạng, không parse dữ liệu không tin cậy, không dựng đường dẫn từ input người dùng. |

---

## MEDIUM

### M1 — GitHub Actions ghim theo tag di động, không phải commit SHA

```
uses: actions/checkout@v4
uses: actions/upload-artifact@v4
```

`v4` là tag **có thể trỏ lại**. Ai chiếm được quyền đẩy tag trong repo action đó sẽ chạy được
code tuỳ ý trong CI của AZpdf.

*Vì sao chưa phải HIGH ở đây:* workflow chỉ có `contents: read`, không dùng secret nào, và
không publish gì — nên thiệt hại tối đa là đầu độc kết quả build/test, không phải rò khoá hay
chèn artifact phát hành. Nhưng chính vì rẻ nên nên vá: đổi sang SHA đầy đủ kèm chú thích phiên bản.

### M2 — Chưa có gói phát hành nào được ký cho macOS/Windows, và Windows chưa có gói

Release công khai duy nhất là `AZpdf-x86_64.AppImage` (v1.2.0).

**Đã tự kiểm:** tải asset thật từ release và băm lại —
`6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848`, **khớp chính xác** SHA-256
in trong README. Hướng dẫn `sha256sum` trong README là đúng, không phải khẳng định suông.

Nhưng AppImage **không** có chữ ký GPG kèm theo, và SHA đối chiếu nằm cùng một nơi có thể bị
sửa (chính repo) — nên nó chống được lỗi tải hỏng chứ không chống được kẻ kiểm soát repo. Ký
detached GPG (hoặc Sigstore/cosign) là bước đúng khi bắt đầu phát hành đều.

---

## LOW

### L1 — QR ủng hộ công bố số tài khoản ngân hàng thật, vĩnh viễn trong lịch sử git

`Assets/donate-vietqr.jpg` chứa tên chủ tài khoản và số tài khoản Techcombank. Đây **là chủ
đích** — nó là QR nhận ủng hộ, và repo đã public ảnh cùng loại từ trước. Ghi ra chỉ để rõ một
điều: ảnh cũ vẫn nằm trong lịch sử git và không xoá được bằng cách thay file.

---

## Đã kiểm và KHÔNG có vấn đề

- Không có secret nào được tham chiếu trong `ci.yml`.
- Không có endpoint mạng nào trong app/core (gate + self-test chứng minh).
- Không có file thực thi bên thứ ba nào được chạy ở v1 (theo `docs/PLUGIN_PROTOCOL.md`).
- Không có `eval`/`exec` trên chuỗi dựng từ input trong các script mới của Pha 3.5.

## Không kiểm được trong lượt này

- **CVE của runtime đóng gói** (MuPDF 1.28.0, Ghostscript, qpdf, Tesseract, pyHanko): các script
  không ghim phiên bản trong biến, chúng lấy từ nguồn người vận hành cung cấp — nên không có
  danh sách phiên bản nào để đối chiếu CVE từ trong repo. SBOM đi kèm release là chỗ đúng để
  làm việc này; cần một bước đối chiếu SBOM ↔ NVD, chưa có.
- Quét động (fuzz PDF hỏng, kiểm tra sandbox lúc chạy) — ngoài phạm vi lượt quét tĩnh này.
