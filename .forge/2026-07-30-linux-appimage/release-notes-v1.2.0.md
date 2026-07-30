# AZpdf 1.2.0

**English** | [Tiếng Việt](#tiếng-việt)

Linux x86_64 AppImage. macOS 1.1.0 remains the latest macOS release; 1.2.0 is the first
Linux download.

## Linux AppImage (first Linux release)

- One file: `AZpdf-x86_64.AppImage` (~170 MB). Make it executable and run:
  `chmod +x AZpdf-x86_64.AppImage && ./AZpdf-x86_64.AppImage`.
- SHA-256: `ae5bde06c2669c30dee434cbda42f1e56295e32af7946e105c685683d5357112`
  (verify with `sha256sum AZpdf-x86_64.AppImage`).
- **x86_64 only.** There is no arm64 build yet.
- The engine and its runtimes (MuPDF 1.28.0, OCRmyPDF/Tesseract, pyHanko) are self-contained
  and were verified to run in a clean Ubuntu 24.04 container. The Flutter GUI shell, like every
  Flutter Linux app, dynamically links GTK3 and OpenGL, so it needs four system libraries
  present: `libgtk-3-0t64` (or `libgtk-3-0` on older distributions), `libegl1`, `libgl1`,
  `libgles2`. Any GTK desktop (GNOME, XFCE, Cinnamon, MATE) already has them; only a minimal
  system or bare container needs to install them, plus a display server. The AppImage is **not**
  advertised as "self-contained" — that is the engine, not the shell.
- An SPDX SBOM (`AZpdf-Linux-SBOM.spdx`) is published alongside the download, tracing every
  bundled component and its license (important for the AGPL obligation).

## What changed since 1.1.0

- **AppImage packaging.** A reproducible `build_linux_appimage.sh` assembles the Flutter bundle
  into an AppDir and packs it with `appimagetool`.
- **Valid Linux SBOM.** The OCRmyPDF and pyHanko runtimes are now built by the official
  `build_*_runtime.sh` scripts, which emit a `components.tsv` each; `generate_linux_sbom.sh`
  then succeeds, so every release bundle ships provenance.
- **README** now has a Linux download section (English + Vietnamese).
- **CI** macOS runner and Windows Swift install were reworked (see below).

## Windows status (not in this release)

Windows is **not** released in 1.2.0. CI proves the Flutter Windows shell builds
(`windows-shell` is green); whether the Swift `azpdf-engine` builds on Windows is still open
because no stable, pinned Swift-for-Windows installer URL could be found for the versions this
project targets. The full feasibility analysis is in
[`qa-report/windows-feasibility-2026-07-29.md`](../../qa-report/windows-feasibility-2026-07-29.md).

## Verify / install

```bash
sha256sum AZpdf-x86_64.AppImage
# expect: ae5bde06c2669c30dee434cbda42f1e56295e32af7946e105c685683d5357112
chmod +x AZpdf-x86_64.AppImage
sudo apt-get install -y libgtk-3-0t64 libegl1 libgl1 libgles2   # only if your system lacks them
./AZpdf-x86_64.AppImage
```

---

# Tiếng Việt

Bản Linux x86_64 AppImage. macOS 1.1.0 vẫn là bản macOS mới nhất; 1.2.0 là bản tải Linux đầu tiên.

## Linux AppImage (bản Linux đầu tiên)

- Một file: `AZpdf-x86_64.AppImage` (~170 MB). Cấp quyền chạy rồi mở:
  `chmod +x AZpdf-x86_64.AppImage && ./AZpdf-x86_64.AppImage`.
- SHA-256: `ae5bde06c2669c30dee434cbda42f1e56295e32af7946e105c685683d5357112`
  (kiểm bằng `sha256sum AZpdf-x86_64.AppImage`).
- **Chỉ x86_64.** Chưa có bản arm64.
- Engine và runtime (MuPDF 1.28.0, OCRmyPDF/Tesseract, pyHanko) tự chứa và đã được kiểm chạy
  trong container Ubuntu 24.04 trắng. Còn vỏ GUI Flutter, như mọi ứng dụng Flutter Linux, link
  động GTK3 và OpenGL nên cần bốn thư viện hệ thống: `libgtk-3-0t64` (hoặc `libgtk-3-0` trên
  bản phân phối cũ), `libegl1`, `libgl1`, `libgles2`. Mọi desktop dùng GTK (GNOME, XFCE,
  Cinnamon, MATE) đã có sẵn; chỉ hệ thống tối giản hoặc container trống mới cần cài, cộng thêm
  display server. AppImage **không** được quảng cáo là "self-contained" — đó là engine, không
  phải vỏ GUI.
- SBOM SPDX (`AZpdf-Linux-SBOM.spdx`) đi kèm bản tải về, truy nguồn từng thành phần và giấy
  phép (quan trọng cho nghĩa vụ AGPL).

## Đã thay đổi từ 1.1.0

- **Đóng gói AppImage.** Script `build_linux_appimage.sh` dựng reproducible, gom bundle Flutter
  vào AppDir rồi đóng gói bằng `appimagetool`.
- **SBOM Linux hợp lệ.** Runtime OCRmyPDF và pyHanko giờ được dựng bằng script chính thức
  `build_*_runtime.sh`, mỗi runtime sinh `components.tsv`; `generate_linux_sbom.sh` chạy qua,
  mọi bundle phát hành đều có xuất xứ truy được.
- **README** có mục tải Linux (Anh + Việt).
- **CI** runner macOS và cách cài Swift trên Windows được làm lại (xem dưới).

## Trạng thái Windows (không có trong bản này)

Windows **không** phát hành trong 1.2.0. CI chứng minh vỏ Flutter Windows build được
(`windows-shell` xanh); việc `azpdf-engine` (Swift) có build được trên Windows hay không vẫn
mở vì không tìm được URL installer Swift-for-Windows ổn định và đã pin cho các version dự án
dùng. Phân tích khả thi đầy đủ ở
[`qa-report/windows-feasibility-2026-07-29.md`](../../qa-report/windows-feasibility-2026-07-29.md).

## Kiểm tra / cài đặt

```bash
sha256sum AZpdf-x86_64.AppImage
# kỳ vọng: ae5bde06c2669c30dee434cbda42f1e56295e32af7946e105c685683d5357112
chmod +x AZpdf-x86_64.AppImage
sudo apt-get install -y libgtk-3-0t64 libegl1 libgl1 libgles2   # chỉ khi hệ thống thiếu
./AZpdf-x86_64.AppImage
```
