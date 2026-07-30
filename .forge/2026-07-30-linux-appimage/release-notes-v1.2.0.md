# AZpdf 1.2.0

**English** | [Tiếng Việt](#tiếng-việt)

Linux x86_64 AppImage. macOS 1.1.0 remains the latest macOS release; 1.2.0 is the first
Linux download.

## Linux AppImage (first Linux release)

- One file: `AZpdf-x86_64.AppImage` (~170 MB). Make it executable and run:
  `chmod +x AZpdf-x86_64.AppImage && ./AZpdf-x86_64.AppImage`.
- SHA-256: `6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848`
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

Windows is **not** released in 1.2.0, but the blocker has moved and it is no longer Swift. CI
now builds **both halves on Windows**: the Flutter shell (`windows-shell`) and the Swift core
including `azpdf-engine` (`windows-core`), the latter in about 90 seconds with no errors.

An earlier draft of these notes said no stable Swift-for-Windows installer URL could be found.
That was wrong. The download.swift.org path needs its directory segment lowercased while the
file name keeps `-RELEASE`; get the case wrong and it 404s, which is what the draft mistook for
a missing installer. It is there, 1.68 GB, HTTP 200.

Two things still stand between this and a Windows release. Packaging the four runtimes is the
real one — OCRmyPDF needs Tesseract, Ghostscript and qpdf, all installer-based. And `swift test`
does not yet run on Windows: the built test binary exits `0xC000013A` before printing a single
line, so `windows-core` builds the test targets without running them and says so in its step
name rather than pretending otherwise. Exit codes and the five layers the Windows toolchain
needs are recorded in
[`qa-report/windows-feasibility-2026-07-29.md`](../../qa-report/windows-feasibility-2026-07-29.md).

## Verify / install

```bash
sha256sum AZpdf-x86_64.AppImage
# expect: 6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848
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
- SHA-256: `6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848`
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

Windows **không** phát hành trong 1.2.0, nhưng rào cản đã dịch chỗ và không còn là Swift nữa.
CI giờ build được **cả hai nửa trên Windows**: vỏ Flutter (`windows-shell`) và Swift core kể cả
`azpdf-engine` (`windows-core`), nửa sau mất khoảng 90 giây, không một lỗi nào.

Bản nháp trước của ghi chú này nói không tìm được URL installer Swift-for-Windows ổn định. Sai.
Đường dẫn download.swift.org cần viết **thường** ở đoạn thư mục trong khi tên file giữ
`-RELEASE`; nhầm chữ hoa/thường là 404, và bản nháp đã tưởng nhầm đó là "installer không tồn
tại". Nó có thật, 1.68 GB, HTTP 200.

Còn hai việc trước khi có bản Windows. Thật sự khó là đóng gói 4 runtime — OCRmyPDF cần
Tesseract, Ghostscript và qpdf, đều installer-based. Và `swift test` chưa chạy được trên
Windows: test binary thoát `0xC000013A` trước khi in nổi một dòng, nên `windows-core` chỉ biên
dịch test target chứ không chạy, và **nói thẳng điều đó trong tên step** thay vì giả vờ. Mã lỗi
và 5 lớp mà toolchain Windows cần đều được ghi trong

## Kiểm tra / cài đặt

```bash
sha256sum AZpdf-x86_64.AppImage
# kỳ vọng: 6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848
chmod +x AZpdf-x86_64.AppImage
sudo apt-get install -y libgtk-3-0t64 libegl1 libgl1 libgles2   # chỉ khi hệ thống thiếu
./AZpdf-x86_64.AppImage
```
