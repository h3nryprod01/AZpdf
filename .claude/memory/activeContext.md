---
status: SUPERSEDED
note: GLM chạy từ thư mục cha. Plan canonical ở ../../.claude/memory/activeContext.md (tức /Users/nguyenphucuong/Documents/Codex/2026-07-16/.claude/memory/activeContext.md). Đừng đọc bản này.
---

<!-- Bản dưới đây giữ lại làm lịch sử. Nguồn thật là file ở thư mục cha. -->

# Goal

Đóng hai lỗi còn mở của AZpdf một cách **triệt để, không tô vẽ**:
1. **F** — chữ ký tay (ink) đã render đúng trên `main` nhưng **không có test nào canh**; từng regress im lặng (d85f1b1) chỉ vì một dòng toạ độ. Thêm test ghim chặt để không tái diễn.
2. **C2** — nhấn Escape không đóng được sheet có ô nhập. Thử một cách đã đặc tả, build-verify, rồi **dừng cho người kiểm GUI** (không loop mù).

# Ground truth (planner đã xác minh read-only — GLM KHÔNG cần điều tra lại)

- **F đã đúng trong code.** `PDFReaderView.signaturePoint` (Views/PDFReaderView.swift ~182) hiện map về **annotation-local space**:
  `CGPoint(x: point.x / 520 * bounds.width, y: bounds.height - point.y / 190 * bounds.height)`.
  Tái hiện đúng công thức này (ink annotation + `add(path)`) rồi render bằng `azpdf-engine render` → **891 pixel mực** (hiện rõ). `/InkList` và `/AP` đều có.
- **Bug cũ (d85f1b1)** dùng `bounds.minX + …, bounds.maxY - …` (page-space) → ink ra ngoài `/Rect` → mọi renderer clip mất. Đúng một dòng đó gây ra bug "chữ ký im lặng".
- **Không có test nào chạm tới đường này**: `AZpdfMuPDFTests` stub command runner; `DocumentStoreTests` không render. Đó là lý do bug sống sót qua suite xanh.
- `520`/`190` trong `signaturePoint` = kích thước canvas `SignatureSheet.swift:13` (`.frame(width: 520, height: 190)`). Trùng nhưng **không ràng buộc** → sửa canvas mà quên `signaturePoint` sẽ lệch tỉ lệ.
- **C2 còn hỏng thật.** Root cause: `NSTextField`/`TextEditor` đang focus nuốt Escape qua `cancelOperation:` trước khi tới SwiftUI `.cancelAction`. Ảnh hưởng **cả 4 sheet** có ô nhập. Đã thử 5 cách (cancelAction, onExitCommand, onKeyPress, NSEvent monitor, monitor+frame) — đều trượt. Bấm chuột nút "Hủy" vẫn chạy.

# Files — được phép đụng

- `Views/PDFReaderView.swift` (đổi `signaturePoint` thành `static` + dùng hằng canvas chung; sửa 2 call site)
- `Views/SignatureSheet.swift` (thêm hằng canvas chung; C2 installer)
- `Views/DocumentPropertiesSheet.swift`, `Views/TextAnnotationSheet.swift`, `Views/PasswordProtectSheet.swift` (C2 installer)
- `Views/EscapeDismissInstaller.swift` (file mới, Phase 2)
- `Tests/AZpdfTests/SignaturePointTests.swift` (file mới)
- `Tests/AZpdfMuPDFTests/MuPDFSignatureRenderTests.swift` (file mới, tùy chọn)

# Files — TUYỆT ĐỐI KHÔNG đụng

- `Adapters/MuPDF/Resources/azpdf_annotations.js` — C1 đã sửa xong ở đây (commit trước), đừng động.
- `Package.swift`, `Core/*`, `Stores/*`, mọi thứ trên nhánh `codex/cross-platform-wip`.
- KHÔNG `git push`. Commit local theo từng phase thì được; đẩy remote là việc của người.
- KHÔNG viết lại lịch sử git.

---

# PHASE 1 — F: ghim chặt fix (mechanical, executor tự verify được hết)

## B1. Rút kích thước canvas thành hằng chung + đổi signaturePoint sang static

Trong `Views/SignatureSheet.swift`, thêm ở đầu file (sau import), scope file-level:
```swift
enum SignatureCanvas {
    static let size = CGSize(width: 520, height: 190)
}
```
Sửa `SignatureSheet.swift:13` từ `.frame(width: 520, height: 190)` → `.frame(width: SignatureCanvas.size.width, height: SignatureCanvas.size.height)`.

Trong `Views/PDFReaderView.swift`, đổi `signaturePoint`:
```swift
static func signaturePoint(_ point: CGPoint, in bounds: CGRect) -> CGPoint {
    CGPoint(x: point.x / SignatureCanvas.size.width * bounds.width,
            y: bounds.height - point.y / SignatureCanvas.size.height * bounds.height)
}
```
(Bỏ `private`, thêm `static`. Giữ nguyên phép tính — chỉ thay số magic bằng hằng.)
Sửa 2 call site (~dòng 163-164): `signaturePoint(first, in: bounds)` → `Self.signaturePoint(first, in: bounds)`; `signaturePoint(point, in: bounds)` → `Self.signaturePoint(point, in: bounds)`.

**verify:** `swift build --target AZpdf 2>&1 | tail -1` → phải in `Build ... complete!`, 0 error.

## B2. Test toán học ghim đúng lỗi từng xảy ra (bắt buộc)

Tạo `Tests/AZpdfTests/SignaturePointTests.swift`:
```swift
import XCTest
import PDFKit
@testable import AZpdf

final class SignaturePointTests: XCTestCase {
    // Bug ẩn chữ ký: map sang page-space (bounds.minX + …) đẩy ink ra ngoài
    // /Rect, mọi renderer clip mất. Kết quả PHẢI là annotation-local: không
    // phụ thuộc annotation nằm đâu trên trang.
    func testMapsToLocalSpaceNotPageSpace() {
        let atOrigin = CGRect(x: 0, y: 0, width: 260, height: 96)
        let shifted  = CGRect(x: 300, y: 400, width: 260, height: 96)
        let canvasPt = CGPoint(x: 0, y: SignatureCanvas.size.height) // đáy-trái canvas
        let a = PDFReaderView.signaturePoint(canvasPt, in: atOrigin)
        let b = PDFReaderView.signaturePoint(canvasPt, in: shifted)
        XCTAssertEqual(a.x, b.x, accuracy: 0.01, "x phải là local-space")
        XCTAssertEqual(a.y, b.y, accuracy: 0.01, "y phải là local-space")
        XCTAssertEqual(a.x, 0, accuracy: 0.01)
        XCTAssertEqual(a.y, 0, accuracy: 0.01)
    }
    func testCanvasCornerMapsToBoundsCorner() {
        let bounds = CGRect(x: 10, y: 20, width: 260, height: 96)
        let topRight = PDFReaderView.signaturePoint(
            CGPoint(x: SignatureCanvas.size.width, y: 0), in: bounds)
        XCTAssertEqual(topRight.x, 260, accuracy: 0.01)
        XCTAssertEqual(topRight.y, 96, accuracy: 0.01)
    }
}
```
**verify:** `swift test --filter SignaturePointTests 2>&1 | grep "Executed"` → `Executed 2 tests ... 0 failures`.

## B3. Chứng minh test THẬT SỰ bắt lỗi (mutation check — bắt buộc)

Tạm sửa `signaturePoint` về dạng page-space cũ (thêm `bounds.minX +` vào x và đổi `bounds.height -` thành `bounds.maxY -`), chạy lại:
`swift test --filter SignaturePointTests` → **phải FAIL**.
Rồi **khôi phục** dạng đúng ở B1, chạy lại → **pass**.
**verify:** log cho thấy fail-khi-mutate, pass-khi-khôi-phục. (Test không fail được là test vô dụng.)

## B4. (Tùy chọn — nếu còn thời gian) Render test end-to-end

Mẫu bám sát `Tests/AZpdfMuPDFTests/MuPDFAnnotationKindTests.swift` (đã có sẵn cách dò mutool + `XCTSkip` khi thiếu). Tạo `Tests/AZpdfMuPDFTests/MuPDFSignatureRenderTests.swift`:
- Tạo `PDFDocument` + `PDFPage`, thêm 1 ink annotation với stroke bằng công thức local-space (như `signaturePoint` output), `write` ra file tạm.
- `engine.render(...)` ra PNG, decode bằng `NSBitmapImageRep`, đếm pixel không-trắng.
- `XCTAssert(darkPixels > 50)`. `XCTSkip` nếu không có mutool hoặc mutool < 1.24.

**verify:** `swift test --filter MuPDFSignatureRenderTests 2>&1 | grep -E "Executed|skipped"` → pass hoặc skipped (không được failure).

## B5. Cập nhật doc + commit Phase 1

Trong `qa-report/README-COVERAGE.md`, sửa lại mục chữ ký: nêu rõ **code đã đúng (local-space), NAY đã có test canh** (`SignaturePointTests` + mutation check). Bỏ khẳng định sai cũ nếu còn.
`git add` các file Phase 1 + doc, commit local (conventional: `test: pin signature ink coordinate mapping so it can't silently regress`). **KHÔNG push.**
**verify:** `swift test 2>&1 | grep "Executed 1[0-9][0-9] tests"` → full suite 0 failures.

---

# PHASE 2 — C2: một cách duy nhất, rồi CHẶN chờ người kiểm GUI

> C2 đã trượt 5 cách và **không verify được headless** (cần bấm Escape thật trên GUI).
> GLM: làm ĐÚNG B6, build-verify, rồi **DỪNG**. Tuyệt đối **không** tự nghĩ thêm cách khác.

## B6. Local key monitor bắt Escape trước responder chain

Tạo `Views/EscapeDismissInstaller.swift`:
```swift
import SwiftUI
import AppKit

/// Escape bị NSTextField đang focus nuốt trước khi SwiftUI .cancelAction thấy,
/// nên sheet có ô nhập không đóng được bằng bàn phím. Local key monitor chạy
/// trước responder chain, bắt Escape (keyCode 53) khi sheet đang hiện.
struct EscapeDismissInstaller: NSViewRepresentable {
    let onEscape: () -> Void
    func makeCoordinator() -> Coordinator { Coordinator(onEscape: onEscape) }
    func makeNSView(context: Context) -> NSView { context.coordinator.install(); return NSView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
    static func dismantleNSView(_ nsView: NSView, coordinator: Coordinator) { coordinator.remove() }
    final class Coordinator {
        private var monitor: Any?
        let onEscape: () -> Void
        init(onEscape: @escaping () -> Void) { self.onEscape = onEscape }
        func install() {
            monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
                if event.keyCode == 53 { self?.onEscape(); return nil }
                return event
            }
        }
        func remove() { if let m = monitor { NSEvent.removeMonitor(m); monitor = nil } }
    }
}
```
Gắn `.background(...)` vào root của **4 sheet**, đóng đúng flag tương ứng:
- `SignatureSheet.swift`: `.background(EscapeDismissInstaller { store.isSignatureSheetPresented = false })`
- `DocumentPropertiesSheet.swift`: `.background(EscapeDismissInstaller { store.isDocumentPropertiesSheetPresented = false })`
- `TextAnnotationSheet.swift`: `.background(EscapeDismissInstaller { dismiss() })`
- `PasswordProtectSheet.swift`: `.background(EscapeDismissInstaller { dismiss() })`

**verify (chỉ build được — hành vi cần GUI):** `swift build --target AZpdf 2>&1 | tail -1` → `Build ... complete!`.

## B7. CHẶN — chờ người kiểm GUI (KHÔNG tự quyết)

Sau B6, **dừng và báo người**. Người sẽ: mở app, mở lần lượt 4 sheet, nhấn Escape → phải đóng; và kiểm monitor **không** rò (Escape khi không có sheet không được gây tác dụng lạ).
- Nếu người xác nhận OK → commit local (`fix: dismiss sheets on Escape via a pre-responder key monitor`), KHÔNG push.
- Nếu Escape vẫn không đóng, HOẶC monitor rò: `git checkout -- Views/EscapeDismissInstaller.swift Views/SignatureSheet.swift Views/DocumentPropertiesSheet.swift Views/TextAnnotationSheet.swift Views/PasswordProtectSheet.swift`, đặt `status: NEEDS_HUMAN` ở đầu file này, ghi 1 dòng lý do. **Không thử cách thứ 6.**

---

# Không thuộc phạm vi (đừng làm)

- Đề xuất thiết kế: toolbar 17 icon không nhãn (đã có tooltip), mục lục không tự đánh dấu trang hiện tại. Đây là UX polish, không phải lỗi — bỏ qua.
- Windows: cần cài toolchain trong VM, việc của người. Không đụng.
- C1 (annotation kind map): đã sửa xong commit trước, có test. Đừng làm lại.

# Definition of done

- Phase 1: `SignaturePointTests` xanh + mutation check chứng minh nó bắt lỗi; full suite 0 failures; doc cập nhật; commit local.
- Phase 2: build xanh với installer, rồi DỪNG ở B7 chờ người. Không tự tuyên bố C2 xong khi chưa có người kiểm GUI.
