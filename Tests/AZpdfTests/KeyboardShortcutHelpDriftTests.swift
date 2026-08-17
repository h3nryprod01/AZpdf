import XCTest

/// Issue #9, bản khó: Help từng lệch code vì bảng phím tắt viết tay (một dòng ghi sai phím,
/// nhiều lệnh vắng mặt). Test này đọc THẲNG hai file nguồn và so — Help lệch code là đỏ,
/// bảng không thể trôi lần nữa. Kèm luôn kiểm tra không phím nào gán hai lệnh, vì đúng lượt
/// làm issue #2 đã phát hiện chuỗi trùng: ⌥⌘G (Previous Result vs Go to Page) rồi ⇧⌘G
/// (Previous Result vs Insert Signature) — trùng phím là loại lỗi con người rà tay sẽ sót.
final class KeyboardShortcutHelpDriftTests: XCTestCase {

    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)         // .../Tests/AZpdfTests/<file>
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    /// Rút mọi phím tắt trong OpenPaperApp.swift thành ký hiệu chuẩn: "⇧⌘N", "⌥⌘G", "⇧⌘⌫"…
    private func declaredShortcuts() throws -> [String] {
        let source = try String(contentsOf: repoRoot.appendingPathComponent("App/OpenPaperApp.swift"), encoding: .utf8)
        // Hai dạng: .keyboardShortcut("g", modifiers: [.command, .option]) và .keyboardShortcut(.delete, ...)
        let pattern = #"\.keyboardShortcut\((?:"(.)"|\.(\w+))\s*,\s*modifiers:\s*(\[[^\]]*\]|\.\w+)\)"#
        let regex = try NSRegularExpression(pattern: pattern)
        let range = NSRange(source.startIndex..., in: source)
        return regex.matches(in: source, range: range).map { match in
            let group: (Int) -> String? = { i in
                guard let r = Range(match.range(at: i), in: source) else { return nil }
                return String(source[r])
            }
            let key: String
            if let char = group(1) {
                key = char.uppercased()
            } else {
                key = group(2) == "delete" ? "⌫" : "?\(group(2) ?? "")"
            }
            let mods = group(3) ?? ""
            var symbol = ""
            if mods.contains("control") { symbol += "⌃" }
            if mods.contains("option")  { symbol += "⌥" }
            if mods.contains("shift")   { symbol += "⇧" }
            if mods.contains("command") { symbol += "⌘" }
            return symbol + key
        }
    }

    func testEveryShortcutInTheAppAppearsInHelp() throws {
        let help = try String(contentsOf: repoRoot.appendingPathComponent("Views/HelpView.swift"), encoding: .utf8)
        let missing = try declaredShortcuts().filter { shortcut in
            // Khớp có biên trái: "⌘G" không được tính là xuất hiện chỉ vì Help có "⇧⌘G" —
            // ký tự đứng ngay trước không được là một modifier khác.
            var index = help.startIndex
            while let found = help.range(of: shortcut, range: index..<help.endIndex) {
                let before = found.lowerBound == help.startIndex ? " " : String(help[help.index(before: found.lowerBound)])
                if !"⌃⌥⇧⌘".contains(before) { return false }   // có mặt thật
                index = found.upperBound
            }
            return true                                          // không tìm thấy → thiếu
        }
        XCTAssertTrue(missing.isEmpty, "Phím tắt có trong app nhưng vắng trong Help: \(missing). Thêm GridRow vào Views/HelpView.swift.")
    }

    func testNoShortcutIsAssignedTwice() throws {
        let shortcuts = try declaredShortcuts()
        let duplicates = Dictionary(grouping: shortcuts, by: { $0 }).filter { $1.count > 1 }.keys.sorted()
        XCTAssertTrue(duplicates.isEmpty, "Một phím gán nhiều lệnh: \(duplicates). Người dùng bấm sẽ trúng lệnh nào là chuyện may rủi.")
    }

    func testParserActuallySeesTheShortcuts() throws {
        // Chứng dương cho chính parser: regex sai lặng lẽ trả [] là hai test trên xanh giả.
        let count = try declaredShortcuts().count
        XCTAssertGreaterThanOrEqual(count, 30, "Chỉ bắt được \(count) phím tắt — app có 34; parser hỏng hoặc app vừa mất menu.")
    }
}
