# Phát hành AZpdf cho macOS

## Điều kiện bắt buộc

- Apple Developer Program và **Developer ID Application** certificate có private key trong Keychain.
- Xcode command-line tools.
- Keychain profile cho `notarytool` nếu muốn notarize.
- `MUTOOL_RUNTIME_DIR`: thư mục runtime MuPDF có `mutool` và toàn bộ dylib phụ thuộc, được build/đóng gói để chạy độc lập khỏi Homebrew.
- `VERAPDF_RUNTIME_DIR`: thư mục veraPDF self-contained có executable `verapdf`, runtime Java và model kiểm tra PDF/A/PDF/UA.
- `PYHANKO_RUNTIME_DIR`: thư mục pyHanko self-contained có executable `pyhanko` **relocatable** cùng Python interpreter/dependencies của nó; không dùng script có shebang trỏ vào virtualenv build machine.
- `OCRMY_PDF_RUNTIME_DIR`: OCRmyPDF self-contained cùng Tesseract, Ghostscript, qpdf và language data (`eng`, `vie`) để tạo searchable PDF offline.

Identity Apple Development hiện chỉ dùng để phát triển; không đủ để phát hành notarized ra ngoài Mac App Store.

## Build runtime PAdES

Tạo environment Python đã pin `pyhanko-cli` và `PyInstaller`, rồi build executable một file:

```bash
export PYHANKO_PYTHON='/path/to/pinned-python/bin/python'
./script/build_pyhanko_runtime.sh
export PYHANKO_RUNTIME_DIR="$PWD/dist/runtime/pyhanko"
```

Script chạy `audit_runtime.sh`, `pyhanko --version` và `pyhanko sign validate --help` sau khi build. Ghi lại phiên bản pyHanko/PyInstaller cùng SBOM trước khi phát hành. pyHanko dùng MIT; PyInstaller có GPL-2.0 kèm ngoại lệ cho phép phân phối executable, nhưng vẫn phải kiểm kê license của toàn bộ dependency Python trong SBOM.

`package_release.sh` gọi `sign_bundle.sh`: script này ký mọi Mach-O nhúng trước, rồi ký app chính với hardened runtime và entitlement. Không thay thế bước notarization.

## Build runtime veraPDF

Bundle veraPDF cùng JRE/JDK đã kiểm tra license; không dùng launcher Homebrew trong release:

```bash
export VERAPDF_SOURCE_DIR='/path/to/verapdf/libexec'
export JAVA_HOME='/path/to/jdk/Contents/Home'
./script/build_verapdf_runtime.sh
export VERAPDF_RUNTIME_DIR="$PWD/dist/runtime/veraPDF"
```

Builder chạy veraPDF từ bundle vừa tạo. Đọc kỹ license GPL-3.0-or-later hoặc MPL-2.0 của veraPDF và GPLv2+Classpath Exception của OpenJDK, rồi ghi chúng trong SBOM/notices trước phát hành.

## Build runtime MuPDF

Build MuPDF từ source chính thức với thư viện bundled; helper chỉ gồm `mutool` static cho chèn ảnh. Crypto và OpenGL viewer được tắt vì AZpdf không dùng chúng:

```bash
export MUPDF_SOURCE_DIR='/path/to/mupdf-source'
export MUPDF_ARCHFLAGS='-arch arm64'
./script/build_mupdf_runtime.sh
export MUTOOL_RUNTIME_DIR="$PWD/dist/runtime/mutool"
```

MuPDF mang AGPL-3.0-or-later, phù hợp với license AGPL-3.0-only của AZpdf. Ghi lại source SHA-256, version và toàn bộ third-party notices của archive vào SBOM trước phát hành.

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
export OCRMY_PDF_RUNTIME_DIR='/path/to/redistributable-ocrmypdf-runtime'
./script/package_release.sh
```

Lệnh tạo `dist/release/AZpdf-macOS.zip`, ký Hardened Runtime và kiểm tra bằng `codesign`/`spctl`.

Không copy trực tiếp binary từ Homebrew: chúng thường liên kết tới dylib ngoài app. Runtime được đặt tại `AZpdf.app/Contents/Helpers/`, phải self-contained, kiểm tra giấy phép tương ứng và được ký cùng app trước notarization. PyHanko runtime phải là executable relocatable (ví dụ bundle Python/pyoxidizer được kiểm chứng), không phải virtualenv developer. `package_release.sh` dừng nếu một trong các runtime không có, chạy `audit_runtime.sh` để chặn symlink trỏ ra ngoài bundle, Homebrew path, `@rpath` ngoài bundle và Python entrypoint ngoài bundle, rồi dùng `codesign --verify --deep --strict` để chặn nested helper không hợp lệ.

## Notarization

Tạo Keychain profile một lần theo Apple Developer account rồi chạy:

```bash
export NOTARY_PROFILE='AZpdf-notary'
./script/package_release.sh
```

Script chờ kết quả notarization và staple ticket vào app. Không đưa Apple ID, app-specific password hay private key vào repository/CI log.

## Plugin và App Sandbox

AZpdf chưa bật App Sandbox cho app chính, vì sandbox đó không cô lập an toàn executable plugin tùy ý. Plugin v1 chỉ discovery/validation; trước khi bật thực thi, cần XPC service sandbox riêng, quyền theo tài liệu và audit capability. `Config/AZpdf.entitlements` được giữ tối thiểu, không cấp network entitlement.
