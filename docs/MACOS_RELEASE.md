# Phát hành AZpdf cho macOS

## Điều kiện bắt buộc

- Apple Developer Program và **Developer ID Application** certificate có private key trong Keychain.
- Xcode command-line tools.
- Keychain profile cho `notarytool` nếu muốn notarize.

Identity Apple Development hiện chỉ dùng để phát triển; không đủ để phát hành notarized ra ngoài Mac App Store.

## Đóng gói và ký

```bash
export SIGNING_IDENTITY='Developer ID Application: Your Name (TEAMID)'
./script/package_release.sh
```

Lệnh tạo `dist/release/AZpdf-macOS.zip`, ký Hardened Runtime và kiểm tra bằng `codesign`/`spctl`.

## Notarization

Tạo Keychain profile một lần theo Apple Developer account rồi chạy:

```bash
export NOTARY_PROFILE='AZpdf-notary'
./script/package_release.sh
```

Script chờ kết quả notarization và staple ticket vào app. Không đưa Apple ID, app-specific password hay private key vào repository/CI log.

## Plugin và App Sandbox

AZpdf chưa bật App Sandbox cho app chính, vì sandbox đó không cô lập an toàn executable plugin tùy ý. Plugin v1 chỉ discovery/validation; trước khi bật thực thi, cần XPC service sandbox riêng, quyền theo tài liệu và audit capability. `Config/AZpdf.entitlements` được giữ tối thiểu, không cấp network entitlement.
