# Khả thi Windows — spike 2026-07-29

> Phạm vi: **đo khả thi**, không build. Không có file `.exe` nào được tạo. Mọi số liệu
> dưới đây lấy từ tài liệu chính thức (swift.org, mupdf.com, ocrmypdf.readthedocs.io,
> verapdf.org) và inspect trực tiếp VM Windows cục bộ.

## Sự thật từ CI (2026-07-30)

Phiên bản nháp đầu viết như thể Swift-for-Windows chưa từng được thử trong CI. Sai — CI đã có
job `windows-core` từ trước, chỉ là nó chưa từng chạy tới `swift build`. Bảng dưới là trạng thái
thật của 3 job CI liên quan Windows/macOS tại baseline `c75f7a5` (10/10 lần chạy gần nhất đỏ):

| Job CI | Trạng thái | Nguyên nhân |
|---|---|---|
| `windows-shell` | ✅ **success** | `flutter build windows --release` xanh — **Flutter Windows đã được chứng minh**, không còn là ẩn số. |
| `windows-core` | ❌ **failure** (chưa từng build) | `winget` không tồn tại trên image `windows-2022` → chết ở bước cài Swift, chưa chạy tới `swift test`/`swift build` lần nào. Đã bỏ winget, tải installer trực tiếp + verify SHA256 sidecar. **Cả Swift 6.3.3 LẪN 6.3.2 đều 404** trên `download.swift.org/swift-<ver>-RELEASE/windows10/...` (xác nhận từ runner, không phải sandbox) → installer Windows không còn ở đường dẫn canonical; Windows distribution chuyển sang WinGet/Swiftly. **BLOCKED** (vấp #2): không tìm được URL installer pinned ổn định; không thử thêm version ngẫu nhiên để lách. Cần người quyết: dùng Swiftly/WinGet, hoặc pin thủ công một version Windows thật có SHA. |
| `macos-tests` | ❌ **failure** | Lần 1 (runner `macos-14`): Swift 5.10 < 6.0 cần cho `Package.swift`. Lần 2 (đã nâng `macos-15`): runner mặc định Swift **6.1**, nhưng dep `swift-subprocess` (commit pin `1163367…`) yêu cầu tools **6.2.0**. Đang sửa: `xcode-select` chọn Xcode version cao nhất trên runner (có Swift ≥ 6.2). |

**Hệ quả cho report này:** Flutter Windows (vỏ GUI) là chuyện đã xanh trong CI, gỡ khỏi danh
sách ẩn số. Phần chưa biết thu hẹp còn: (a) `azpdf-engine` (Swift) có `swift test`/`swift build`
được trên Windows không — đúng câu mà `windows-core` sẽ trả lời; (b) đóng gói 4 runtime Windows
(đặc biệt OCRmyPDF cần Tesseract+Ghostscript+qpdf installer-based). Đợi kết quả `windows-core`
ở mục D2 để chốt lời kết chính thức.

## Kết luận (1 câu)

Windows v1 **khả thi có điều kiện**: CI đã chứng minh **Flutter Windows build xanh**
(`windows-shell` success), nhưng **`azpdf-engine` (Swift) chưa build được trên Windows trong
CI** — cả Swift 6.3.3 lẫn 6.3.2 đều không có installer Windows ở đường dẫn canonical (404 từ
runner; Windows distribution đã chuyển sang WinGet/Swiftly), nên `windows-core` chết ở bước
cài toolchain và chưa bao giờ chạy `swift build`; rào cản còn lại là đóng gói 4 runtime (đặc
biệt OCRmyPDF cần Tesseract+Ghostscript+qpdf installer-based). Đến khi chọn được nguồn cài
Swift Windows ổn định + `windows-core` xanh + smoke test trong VM thành công thì mới đứng ở
mức "chạy được đã kiểm chứng".

## Ma trận khả thi

| Hạng mục | Có sẵn cho Windows? | Phải tự build? | License redistribute OK? | Ước lượng công |
|---|---|---|---|---|
| **Swift toolchain** | Có — hỗ trợ Windows chính thức (installer x86_64 + ARM64, winget/Swiftly/.exe). **Phiên bản: xem lại trước khi làm** — bản release mới nhất là **6.3.3 (2026-06-30)**, kiểm từ feed release `swiftlang/swift`; số 6.2.3 nêu ở bản nháp đầu là đã cũ. Spike này **không xác minh được** installer Windows cho đúng 6.3.3 (Swift phát hành qua CDN swift.org, GitHub release không có asset) → phải mở swift.org/install/windows xác nhận | Không (dùng installer) | Apache 2.0 — OK | Thấp (cài), nhưng **yêu cầu Visual Studio 2022 + C++ Build Tools (~7–10 GB)** |
| **azpdf-engine (Swift)** | Toolchain có; `Package.swift` build được | Có — `swift build` trên Windows | AGPL (MuPDF) + dự án — OK | Trung bình. Rủi ro: link `Foundation`/`swift-subprocess` trên Windows cần kiểm chứng |
| **mutool (MuPDF 1.28)** | Có — bản Windows chính thức trên mupdf.com/releases | Không cần (dùng bản chính thức) | **AGPL** — redistribute đi kèm nghĩa vụ source-disclosure (giống mac/Linux) | Thấp |
| **pyHanko** | Thuần Python → **PyInstaller** ra `.exe` portable | Có — build PyInstaller Windows | MIT/BSD — OK | Thấp–trung bình (lập lại đúng đường Linux `build_pyhanko_runtime.sh`) |
| **OCRmyPDF** | Phụ thuộc **Tesseract + Ghostscript + qpdf** | Cả 3 đều có installer Windows nhưng **không phải portable single-binary** | OCRmyPDF MPL-3.0; Tesseract Apache; Ghostscript AGPL; qpdf Apache — OK nhưng **lộn xộn** | **Cao** — phần khó nhất. Phải đóng gói 3 native dep + traineddata + registry/path |
| **veraPDF** | Có — installer Windows chính thức (JVM) | Không (dùng installer) | MPL-2.0 — OK | Thấp (chỉ cần bundling JVM hoặc yêu cầu JRE) |
| **Flutter Windows** | Có — `flutter build windows --release` (hỗ trợ chính thức) | Không | OK | Thấp |

> **Lưu ý nhất quán phiên bản.** Đường build Linux của chính dự án đã dùng Docker image
> `swift:6.3.3` (`script/build_linux_release.sh`). Nếu Windows dùng một dòng Swift khác thì
> `AZpdfCore` phải build xanh trên **cả hai** — chọn version cho Windows nên bám theo dòng Linux
> đang dùng, đừng chọn độc lập.

## Chỗ chặn cứng

1. **Không verify được trong VM.** VM `win11` (container `dockurr/windows`) Up 10 ngày, cổng
   RDP 3389 và web-viewer 8006 đều mở từ host — nhưng **mọi đường vào guest đều cần đăng
   nhập GUI tương tác**. `dockurr/windows` không lộ kênh chạy lệnh headless; compose chỉ mount
   `/storage` (ổ đĩa của chính VM), không có shared folder hay guest agent. Theo ràng buộc
   #1, **không dùng mật khẩu** trong compose file → **cần người** đăng nhập để chạy/kiểm bất
   kỳ thứ gì bên trong Windows. Xem `## CẦN NGƯỜI` ở `activeContext.md`.

2. **OCR portability.** Trên Linux, OCRmyPDF portable đi kèm Tesseract+Ghostscript+qpdf trong
   cùng runtime dir. Trên Windows, 3 dep này là installer-based (đăng ký registry, tìm qua
   Program Files). Đóng gói chúng thành một đơn vị self-contained như bản Linux là **chưa có
   công thức sẵn** — cần thiết kế riêng (bundle 3 bộ binary Windows + set `TESSDATA_PREFIX`/
   path tại runtime, tương tự `AppRun` export `LD_LIBRARY_PATH` của AppImage).

## Đường lùi nếu Swift-for-Windows không dựng nổi

`docs/ARCHITECTURE.md:26` đã định nghĩa `azpdf-engine` là **"executable bridge JSON version 1
dùng chung Windows/Linux"** — shell Flutter giao tiếp qua intent JSON qua stdin/stdout. Nếu
`swift build` trên Windows vấp (link `Foundation`, `swift-subprocess`, static stdlib…), đường
lùi thực tế là **bridge C/C++ mỏng giữ nguyên JSON contract**: một executable nhỏ (MSVC build)
đọc cùng intent JSON, gọi MuPDF qua C API, ghi response JSON y hệt. UI Flutter không phải
đ viết lại vì contract không đổi. Đánh giá: **thực tế**, vì contract đã được versioning
(`protocolVersion: 1`) và boundary này được ARCHITECTURE.md chỉ rõ là điểm thay worker/IPC.
Tuy nhiên Swift-for-Windows hiện đã ổn (6.2.3 + workgroup riêng từ 01/2026), nên khả năng phải
dùng đường lùi thấp.

## Đề xuất phạm vi Windows v1

Dựa trên runtime nào có thật và dễ port:

- **Khuyến nghị: viewer chỉ-đọc + annotation cơ bản (text highlight/note).** mutool (MuPDF)
  port sạch và là engine chính; pyHanko cho signature cũng port sạch. Nhận/khớp đúng phạm vi
  macOS v1.1.0 nhưng bỏ bớt tính năng phụ thuộc runtime nặng.
- **OCR (searchable PDF) nên để v1.1+:** phụ thuộc đóng gói Tesseract+Ghostscript+qpdf trên
  Windows — tách ra để không chặn v1. Đã có tiền lệ Linux portable nhưng cần công thức riêng
  cho Windows.
- **veraPDF:** nếu v1 cần validate PDF/A, JVM bundle là khả thi nhưng làm tăng kích thước
  installer đáng kể — đánh giá sau.

## Điều kiện để đi tiếp (cần quyết)

1. Người đăng nhập VM Windows để chạy spike build thật (không thể tự động trong môi trường
   hiện tại).
2. Quyết định phạm vi: **viewer+annotation (không OCR)** cho v1, hay **đầy đủ bao gồm OCR**.
3. Chấp nhận dependency Visual Studio 2022 C++ Build Tools trên máy build Windows.

## Tham khảo

- [Swift.org — Install on Windows](https://swift.org/install/windows/) · [MuPDF releases](https://mupdf.com/releases) · [OCRmyPDF installation](https://ocrmypdf.readthedocs.io/en/latest/installation.html) · [veraPDF software](https://verapdf.org/software/)
