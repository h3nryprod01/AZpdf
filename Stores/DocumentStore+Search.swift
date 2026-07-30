import Foundation
import PDFKit

/// Chạy tìm kiếm PDF mà không chặn main thread.
///
/// `findString` quét đồng bộ: 6 000 trang mất ~10,7 giây, và ô tìm kiếm bind trực tiếp
/// (`TextField(text: $store.searchText)`) nên mỗi keystroke chạy một lượt — gõ một từ khoá
/// ngắn có thể khoá giao diện gần hai phút. `beginFindString` là API bất đồng bộ PDFKit làm
/// sẵn cho đúng việc này: nó tự chạy nền và báo kết quả qua NotificationCenter. Runner này
/// bọc nó thêm debounce (~250 ms) và huỷ lượt cũ khi có lượt mới, để gõ nhanh chỉ chạy một tìm.
///
/// Dùng observer dạng selector (`addObserver(_:selector:...)`) chứ không phải closure: closure
/// observer là `@Sendable` nên không thể chạm state main-actor (PDFSelection/Notification đều
/// non-Sendable) dưới Swift 6. Selector chạy trên main thread (PDFKit post find notification
/// ở đó), và `@MainActor @objc` handler truy cập state an toàn.
@MainActor
final class PDFSearchRunner: NSObject {
    /// Cho test thay giấc ngủ debounce bằng hàm trả về ngay.
    typealias Sleeper = @Sendable (Duration) async -> Void

    private let debounce: Duration
    private let sleeper: Sleeper
    private weak var document: PDFDocument?
    private var onResults: (([PDFSelection]) -> Void)?
    private var collected: [PDFSelection] = []
    private var task: Task<Void, Never>?

    init(debounce: Duration = .milliseconds(250),
         sleeper: @escaping Sleeper = { try? await Task.sleep(for: $0) }) {
        self.debounce = debounce
        self.sleeper = sleeper
        super.init()
    }

    /// Gọi mỗi lần truy vấn đổi. Huỷ lượt đang chạy rồi lên lịch lượt mới.
    /// Chuỗi rỗng: gọi `onResults([])` ngay, không chạy tìm kiếm nào.
    func search(_ text: String,
                in document: PDFDocument?,
                onResults: @escaping ([PDFSelection]) -> Void) {
        cancel()
        guard let document else { onResults([]); return }
        if text.isEmpty {
            // Trống: xoá kết quả ngay, không khởi động find nào (quan trọng cho test
            // document.isFinding == false và cho UX — không quét khi ô rỗng).
            onResults([])
            return
        }
        self.document = document
        self.onResults = onResults
        collected = []
        let snapshot = text
        task = Task { [weak self] in
            guard let self else { return }
            await self.sleeper(self.debounce)
            // Huỷ có thể đã được yêu cầu trong lúc chờ debounce — bỏ lượt này.
            guard !Task.isCancelled else { return }
            self.startFind(snapshot)
        }
    }

    /// Huỷ lượt đang chạy, bỏ mọi kết quả chưa giao.
    func cancel() {
        task?.cancel()
        task = nil
        if let document, document.isFinding { document.cancelFindString() }
        removeObservers()
        // Không null onResults ở đây: guard `!Task.isCancelled` trong search mới là điểm
        // chặn delivery cho lượt vừa huỷ (nếu null ở đây, guard trở thành dư thừa và test
        // mutation bỏ-guard sẽ không cắn được). onResults được ghi đè ở lượt search kế tiếp
        // và được dọn sau khi giao trong handleEnd.
    }

    private func startFind(_ text: String) {
        guard let document else { return }
        // Không removeObservers ở đây: cancel() đã gỡ trước khi Task này chạy startFind
        // (search luôn cancel trước). Gỡ lại sẽ là dư thừa — và che mất vai trò của cancel().
        let center = NotificationCenter.default
        // PDFKit báo mỗi match qua didFindMatch, kết thúc qua didEndFind. Cả hai post trên
        // main thread, nên handler @MainActor chạy đúng actor. Observer dạng selector
        // (trả Void) được NotificationCenter tự gỡ khi `self` dealloc.
        center.addObserver(self, selector: #selector(handleMatch(_:)),
                           name: .PDFDocumentDidFindMatch, object: document)
        center.addObserver(self, selector: #selector(handleEnd(_:)),
                           name: .PDFDocumentDidEndFind, object: document)
        document.beginFindString(text, withOptions: .caseInsensitive)
    }

    @MainActor @objc private func handleMatch(_ note: Notification) {
        guard let selection = note.userInfo?["PDFDocumentFoundSelection"] as? PDFSelection else { return }
        collected.append(selection)
    }

    @MainActor @objc private func handleEnd(_ note: Notification) {
        removeObservers()
        let results = collected
        collected = []
        let callback = onResults
        onResults = nil
        callback?(results)
    }

    private func removeObservers() {
        guard let document else { return }
        let center = NotificationCenter.default
        center.removeObserver(self, name: .PDFDocumentDidFindMatch, object: document)
        center.removeObserver(self, name: .PDFDocumentDidEndFind, object: document)
    }

    // Không cần deinit: selector-observer tự bị NotificationCenter gỡ khi `self` (observer)
    // dealloc; cancel()/handleEnd gỡ trong vòng đời bình thường.
}
