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

    private func switchToManualZoomIfNeeded() {
        guard isAutoScale else { return }
        isAutoScale = false
        zoomScale = 1
    }
}
