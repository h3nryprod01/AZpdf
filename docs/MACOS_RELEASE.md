# Phát hành AZpdf cho macOS

## Điều kiện bắt buộc

- Apple Developer Program và **Developer ID Application** certificate có private key trong Keychain.
- Xcode command-line tools.
- Keychain profile cho `notarytool` nếu muốn notarize.
- `MUTOOL_RUNTIME_DIR`: thư mục runtime MuPDF có `mutool` và toàn bộ dylib phụ thuộc, được build/đóng gói để chạy độc lập khỏi Homebrew.
- `VERAPDF_RUNTIME_DIR`: thư mục veraPDF self-contained có executable `verapdf`, runtime Java và model kiểm tra PDF/A/PDF/UA.

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
./script/package_release.sh
```

Lệnh tạo `dist/release/AZpdf-macOS.zip`, ký Hardened Runtime và kiểm tra bằng `codesign`/`spctl`.

Không copy trực tiếp `/opt/homebrew/bin/mutool`: binary Homebrew thường liên kết tới dylib ngoài app. Runtime phải được chuẩn bị self-contained, kiểm tra giấy phép AGPL-3.0 của MuPDF và được ký cùng app trước notarization. Tương tự, veraPDF phải đi kèm Java runtime/model của chính nó, không phụ thuộc Homebrew trên máy người dùng. `package_release.sh` dừng nếu một trong hai runtime không có, thay vì phát hành bản có tính năng không chạy được.

## Notarization

Tạo Keychain profile một lần theo Apple Developer account rồi chạy:

```bash
export NOTARY_PROFILE='AZpdf-notary'
./script/package_release.sh
```

Script chờ kết quả notarization và staple ticket vào app. Không đưa Apple ID, app-specific password hay private key vào repository/CI log.

## Plugin và App Sandbox

AZpdf chưa bật App Sandbox cho app chính, vì sandbox đó không cô lập an toàn executable plugin tùy ý. Plugin v1 chỉ discovery/validation; trước khi bật thực thi, cần XPC service sandbox riêng, quyền theo tài liệu và audit capability. `Config/AZpdf.entitlements` được giữ tối thiểu, không cấp network entitlement.
