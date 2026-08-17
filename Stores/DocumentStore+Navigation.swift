import Foundation
import AZpdfCore

// Page navigation, search-result navigation and zoom.
extension DocumentStore {
    func goToPreviousPage() {
        guard canGoToPreviousPage else { return }
        selectedPageIndex -= 1
    }

    func goToNextPage() {
        guard canGoToNextPage else { return }
        selectedPageIndex += 1
    }

    /// Nhảy thẳng tới trang (đánh số 1 cho người dùng — issue #2). Ngoài khoảng thì từ chối
    /// chứ không clamp: người gõ 500 vào tài liệu 300 trang cần biết mình gõ sai, không phải
    /// âm thầm bị đưa tới trang cuối.
    /// - Returns: `true` nếu nhảy được — UI dựa vào đây để báo số không hợp lệ.
    @discardableResult
    func goToPage(_ oneBasedPage: Int) -> Bool {
        guard let document else { return false }
        let index = oneBasedPage - 1
        guard (0..<document.pageCount).contains(index) else { return false }
        selectedPageIndex = index
        return true
    }

    func goToPreviousSearchResult() {
        guard searchResultCount > 0 else { return }
        searchDirection = -1
        searchNavigationID += 1
    }

    func goToNextSearchResult() {
        guard searchResultCount > 0 else { return }
        searchDirection = 1
        searchNavigationID += 1
    }

    func zoomOut() {
        switchToManualZoomIfNeeded()
        zoomScale = max(0.5, zoomScale - 0.1)
    }

    func zoomIn() {
        switchToManualZoomIfNeeded()
        zoomScale = min(4, zoomScale + 0.1)
    }

    func fitPage() {
        isAutoScale = true
    }

    /// Zoom tới đúng phần trăm (issue #8). Clamp về [50, 400] — cùng biên với zoomIn/zoomOut
    /// (0.5…4) để không tồn tại mức zoom chỉ vào được bằng cách gõ số. Gõ số nghĩa là người
    /// dùng rời chế độ Fit Page, nên isAutoScale tắt vô điều kiện.
    func setZoomPercent(_ percent: Int) {
        isAutoScale = false
        zoomScale = min(4, max(0.5, CGFloat(percent) / 100))
    }

    private func switchToManualZoomIfNeeded() {
        guard isAutoScale else { return }
        isAutoScale = false
        zoomScale = 1
    }
}
