# Phát hành AZpdf cho macOS

## Điều kiện bắt buộc

- Apple Developer Program và **Developer ID Application** certificate có private key trong Keychain.
- Xcode command-line tools.
- Keychain profile cho `notarytool` nếu muốn notarize.
- `MUTOOL_RUNTIME_DIR`: thư mục runtime MuPDF có `mutool` và toàn bộ dylib phụ thuộc, được build/đóng gói để chạy độc lập khỏi Homebrew.
- `VERAPDF_RUNTIME_DIR`: thư mục veraPDF self-contained có executable `verapdf`, runtime Java và model kiểm tra PDF/A/PDF/UA.
- `PYHANKO_RUNTIME_DIR`: thư mục pyHanko self-contained có executable `pyhanko` **relocatable** cùng Python interpreter/dependencies của nó; không dùng script có shebang trỏ vào virtualenv build machine.
- `PDFSIG_RUNTIME_DIR`: thư mục Poppler self-contained có `pdfsig` và toàn bộ dylib phụ thuộc để kiểm tra integrity/certificate chữ ký PDF.
- `OCRMY_PDF_RUNTIME_DIR`: OCRmyPDF self-contained cùng Tesseract, Ghostscript, qpdf và language data (`eng`, `vie`) để tạo searchable PDF offline.

Identity Apple Development hiện chỉ dùng để phát triển; không đủ để phát hành notarized ra ngoài Mac App Store.

## Tạo điều kiện phát hành

1. Đăng nhập Apple Developer account có hiệu lực và tạo/tải **Developer ID Application** certificate kèm private key vào Keychain Access.
2. Tạo notarytool keychain profile (Apple ID hoặc App Store Connect API key), ví dụ `AZpdf-notary`.
3. Xác nhận bằng `security find-identity -p codesigning -v`; kết quả phải có `Developer ID Application`, không chỉ `Apple Development`.

## Đóng gói và ký

```bash
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
export MUTOOL_RUNTIME_DIR='/path/to/redistributable-mupdf-runtime'
export VERAPDF_RUNTIME_DIR='/path/to/redistributable-verapdf-runtime'
export PYHANKO_RUNTIME_DIR='/path/to/redistributable-pyhanko-runtime'
export PDFSIG_RUNTIME_DIR='/path/to/redistributable-pdfsig-runtime'
export OCRMY_PDF_RUNTIME_DIR='/path/to/redistributable-ocrmypdf-runtime'
./script/package_release.sh
```

Lệnh tạo `dist/release/AZpdf-macOS.zip`, ký Hardened Runtime và kiểm tra bằng `codesign`/`spctl`.

Không copy trực tiếp binary từ Homebrew: chúng thường liên kết tới dylib ngoài app. Runtime được đặt tại `AZpdf.app/Contents/Helpers/`, phải self-contained, kiểm tra giấy phép tương ứng và được ký cùng app trước notarization. PyHanko runtime phải là executable relocatable (ví dụ bundle Python/pyoxidizer được kiểm chứng), không phải virtualenv developer. `package_release.sh` dừng nếu một trong các runtime không có, chạy `audit_runtime.sh` để chặn symlink/dependency Homebrew còn sót, và dùng `codesign --verify --deep --strict` để chặn nested helper không hợp lệ.

## Notarization

Tạo Keychain profile một lần theo Apple Developer account rồi chạy:

```bash
export NOTARY_PROFILE='AZpdf-notary'
./script/package_release.sh
```

Script chờ kết quả notarization và staple ticket vào app. Không đưa Apple ID, app-specific password hay private key vào repository/CI log.

## Plugin và App Sandbox

AZpdf chưa bật App Sandbox cho app chính, vì sandbox đó không cô lập an toàn executable plugin tùy ý. Plugin v1 chỉ discovery/validation; trước khi bật thực thi, cần XPC service sandbox riêng, quyền theo tài liệu và audit capability. `Config/AZpdf.entitlements` được giữ tối thiểu, không cấp network entitlement.
