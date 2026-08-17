import Foundation
import PDFKit

/// Chế độ hiển thị trang người dùng chọn được (issue #7). Enum riêng thay vì dùng thẳng
/// `PDFDisplayMode` của PDFKit vì hai lý do: (1) rawValue String tự đặt nên persist qua
/// UserDefaults không vỡ nếu Apple đổi giá trị enum của họ; (2) chỉ phơi các chế độ AZpdf
/// thật sự hỗ trợ — `singlePage` (không continuous) cố tình vắng mặt vì toàn bộ điều hướng
/// hiện tại (thumbnail, cuộn, tìm kiếm) đều giả định cuộn liên tục.
enum PDFDisplayModeChoice: String, CaseIterable {
    case singleContinuous
    case twoUpContinuous
    case twoUp

    private static let storageKey = "pdfDisplayModeChoice"
    /// "Trang đầu đứng riêng làm bìa" — chỉ có nghĩa ở chế độ hai trang.
    private static let bookKey = "pdfDisplaysAsBook"

    var pdfKitMode: PDFDisplayMode {
        switch self {
        case .singleContinuous: .singlePageContinuous
        case .twoUpContinuous: .twoUpContinuous
        case .twoUp: .twoUp
        }
    }

    var isTwoUp: Bool { self != .singleContinuous }

    static func load() -> PDFDisplayModeChoice {
        guard let raw = UserDefaults.standard.string(forKey: storageKey),
              let choice = PDFDisplayModeChoice(rawValue: raw) else { return .singleContinuous }
        return choice
    }

    func persist() {
        UserDefaults.standard.set(rawValue, forKey: Self.storageKey)
    }

    static func loadDisplaysAsBook() -> Bool {
        UserDefaults.standard.bool(forKey: bookKey)
    }

    static func persistDisplaysAsBook(_ value: Bool) {
        UserDefaults.standard.set(value, forKey: bookKey)
    }
}
