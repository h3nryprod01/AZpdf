# Khả thi Windows — spike 2026-07-29

> Phạm vi ban đầu (29/07): **đo khả thi**, không build — số liệu lấy từ tài liệu chính thức
> (swift.org, mupdf.com, ocrmypdf.readthedocs.io, verapdf.org) và inspect VM Windows cục bộ.
>
> **Cập nhật 30/07 — phạm vi đã vượt qua "chỉ đo":** CI thực sự đã **build Swift core trên
> Windows thành công**. Mục "Sự thật từ CI" bên dưới là đo trực tiếp trên runner, và nó **lật
> ngược** kết luận của bản nháp đầu. Các mục sau đó (ma trận, chỗ chặn cứng, đường lùi) vẫn là
> phân tích tài liệu từ 29/07 — chưa đo — nên đọc chúng với ưu tiên thấp hơn phần đo được.

## Sự thật từ CI (2026-07-30, đã đo)

Bản nháp đầu viết như thể Swift-for-Windows chưa từng được thử trong CI. Sai — job `windows-core`
đã có từ trước, chỉ chưa bao giờ chạy tới `swift build`. Toàn bộ số dưới đây là **đo trực tiếp
trên runner**, không suy luận:

| Job CI | Trạng thái | Sự thật đo được |
|---|---|---|
| `windows-shell` | ✅ success | `flutter build windows --release` xanh. Vỏ GUI Flutter Windows **đã chứng minh**, không còn là ẩn số. |
| `windows-core` | 🟡 **build XANH, test chưa** | Xem chuỗi 5 lớp bên dưới. |
| `macos-tests` | ✅ success | Đỏ 10 lần liên tiếp vì **lệch phiên bản Swift**: Mac dev có 6.3.3, runner tối đa 6.2.4, và 6.2.4 **từ chối** mẫu `DispatchQueue.main.async` + `@MainActor` ở `DocumentStore+OCR.swift:103` (`sending 'self' risks causing data races`) trong khi 6.3.3 chấp nhận. Sửa bằng cách cài toolchain 6.3.3 chính thức thay vì chọn Xcode. Lộ tiếp một lỗi thật: test keychain dùng `XCTAssertNoThrow` trong khi `availableIdentities()` **cố tình** throw `.noIdentity` khi keychain rỗng ⇒ test assert vào cấu hình **máy chủ**, xanh trên Mac có Developer ID, đỏ trên runner không có. |

### Swift trên Windows: 5 lớp, đo từng lớp một

Không lớp nào có trong tài liệu swift.org — trang cài đặt hiện chỉ hướng dẫn `winget`, mà image
`windows-2022` **không có** `winget` (đối chiếu software manifest 537 dòng của runner).

1. **Installer CÓ tồn tại.** Kết luận cũ "6.3.3 và 6.3.2 đều 404, installer Windows không còn ở
   đường dẫn canonical, phải chuyển sang Swiftly/WinGet" là **sai**. Đoạn thư mục viết THƯỜNG,
   tên file giữ HOA: `download.swift.org/swift-6.3.3-release/windows10/swift-6.3.3-RELEASE/swift-6.3.3-RELEASE-windows10.exe`
   → HTTP **200**, tải về đủ **1.759.717.984 byte**. Không cần lệch dòng Swift với Linux/macOS.
   Swift **không** publish sidecar `.sha256`/`.sha512`/`.sig` cạnh artifact này (cả ba 404), khác
   với Flutter SDK zip — nên bước cài chỉ dựa vào HTTPS tới download.swift.org.
2. **Cài PER-USER, không phải Program Files.** Đích thật là
   `%LOCALAPPDATA%\Programs\Swift`; `C:\Program Files\Swift` **không bao giờ tồn tại**. Cây thư
   mục: `Platforms`, `Python-3.10.1`, `Redistributables`, `Runtimes`, `Toolchains`. Hardcode một
   phỏng đoán đường dẫn là cách vòng trước chết. Thêm nữa `Start-Process -Wait` **thiếu
   `-PassThru`** nên nuốt mất exit code, khiến một lần cài hỏng hiện ra dưới dạng lỗi lạc đề.
3. **Cần DLL runtime trên PATH.** `swift.exe` nằm ở `Toolchains\6.3.3+Asserts\usr\bin` nhưng link
   tới `swiftCore.dll` ở **cây khác**: `Runtimes\6.3.3\usr\bin`. Thiếu nó, `swift --version` thoát
   `-1073741515` = `0xC0000135` **STATUS_DLL_NOT_FOUND**, **không in gì cả** — trông y hệt lỗi
   compile, thực chất là process không khởi động nổi.
4. **Cần môi trường MSVC + Windows SDK.** Toolchain Windows không mang theo libc hay linker riêng;
   nó biên dịch dựa vào MSVC toolset + Windows SDK, mà `INCLUDE`/`LIB`/`PATH` bình thường đến từ
   Visual Studio developer prompt. Runner có VS 2022 nhưng mở shell trắng ⇒ thiếu thì báo
   `error: unable to load standard library for target 'x86_64-unknown-windows-msvc'`. Sửa: dùng
   `vswhere` tìm VS → chạy `vcvars64.bat` trong `cmd` → chép biến sang `GITHUB_ENV` (file .bat
   không đổi được shell gọi nó), cộng `SDKROOT` trỏ vào `Platforms\...\Windows.sdk`.
5. **Kết quả: PORTABLE CORE BUILD XANH TRÊN WINDOWS.** Đủ 5 lớp trên thì **toàn bộ target biên
   dịch sạch** — `AZpdfCore`, `AZpdfMuPDF`, `AZpdfPAdES`, `AZpdfStructuredOCR`, `AZpdfEngineCLI`
   và mọi test target — `Build complete! (90.50s)`, **không một dòng `error:`**. Đây là câu trả
   lời cho ẩn số (a): **Swift core dựng được trên Windows.**

**Còn lại:** chạy `swift test` trên Windows. Test binary khởi động rồi chết ngay ở
`-1073741510` = `0xC000013A` **STATUS_CONTROL_C_EXIT**, chưa in nổi một dòng test nào (và
PowerShell đọc mã đó thành "người dùng bấm Ctrl+C" rồi nhảy vào debug mode, khiến lỗi thư viện
trông như một lần chạy bị huỷ). Giả thuyết đang kiểm: thiếu `XCTest.dll` / `Testing.dll` — hai
DLL này nằm trong cây `Platforms` riêng chứ không cạnh compiler.

**Hệ quả cho report này:** hai ẩn số ban đầu giờ còn một. Vỏ Flutter Windows: xanh. Swift core
trên Windows: **build xanh** (test chưa xác nhận). Rào cản thật sự còn lại **không phải Swift**
mà là **đóng gói 4 runtime Windows** — đặc biệt OCRmyPDF cần Tesseract + Ghostscript + qpdf,
đều installer-based.

## Kết luận (1 câu)

Windows v1 **khả thi**, và rào cản đã dịch chỗ: CI chứng minh **cả vỏ Flutter (`windows-shell`
success) lẫn Swift core (`Build complete`, 90.5s, đủ target kể cả `azpdf-engine`) đều dựng được
trên Windows** — điều mà bản nháp trước kết luận ngược lại vì một lỗi chữ hoa/thường trong URL;
việc còn thiếu để gọi là "chạy được đã kiểm chứng" là `swift test` chạy được trên Windows,
đóng gói 4 runtime (OCRmyPDF là phần khó nhất), và một smoke test trong VM thật.

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
