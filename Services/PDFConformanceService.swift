import Foundation

enum PDFConformanceProfile: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case pdfA4
    case pdfUA2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Tự nhận diện claim (fallback PDF/A-1b)"
        case .pdfA4: "PDF/A-4"
        case .pdfUA2: "PDF/UA-2"
        }
    }

    var veraPDFFlavour: String {
        switch self {
        case .automatic: "0"
        case .pdfA4: "4"
        case .pdfUA2: "ua2"
        }
    }
}

struct PDFConformanceReport: Sendable {
    enum Status: Sendable {
        case compliant
        case nonCompliant
        case unknown

        var displayName: String {
            switch self {
            case .compliant: "Đạt"
            case .nonCompliant: "Không đạt"
            case .unknown: "Không xác định"
            }
        }
    }

    struct Finding: Identifiable, Sendable {
        enum Severity: Sendable {
            case error
            case warning

            var displayName: String { self == .error ? "Cần sửa" : "Cần kiểm tra" }
        }

        let rule: String
        let message: String
        let guidance: String
        let severity: Severity
        var id: String { "\(rule)-\(message)" }
    }

    let profile: PDFConformanceProfile
    let status: Status
    let details: String
    let findings: [Finding]

    var summary: String {
        switch status {
        case .compliant: "Validator không phát hiện lỗi với profile đã chọn."
        case .nonCompliant: "Validator phát hiện \(findings.count) hạng mục cần xử lý hoặc kiểm tra."
        case .unknown: "Validator không trả về trạng thái kết luận; xem dữ liệu thô để đối chiếu."
        }
    }
}

enum PDFConformanceError: LocalizedError {
    case runtimeUnavailable
    case cannotWriteInput
    case validationFailed(String)

    var errorDescription: String? {
        switch self {
        case .runtimeUnavailable:
            "Chưa có veraPDF runtime. Cài veraPDF hoặc dùng bản AZpdf đã đóng gói validator để kiểm tra chuẩn PDF."
        case .cannotWriteInput:
            "Không thể tạo bản PDF tạm để kiểm tra chuẩn."
        case let .validationFailed(message):
            "veraPDF không thể kiểm tra tài liệu: \(message)"
        }
    }
}

/// Delegates standards conformance to veraPDF rather than inferring it from metadata.
/// The temporary PDF is only written locally and is removed immediately after validation.
enum PDFConformanceService {
    static func validate(
        _ documentData: Data,
        profile: PDFConformanceProfile,
        executable explicitExecutable: URL? = nil
    ) throws -> PDFConformanceReport {
        guard let executable = explicitExecutable ?? runtimeURL() else { throw PDFConformanceError.runtimeUnavailable }
        let directory = FileManager.default.temporaryDirectory.appending(path: "AZpdf-Conformance-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let input = directory.appending(path: "input.pdf")
        do { try documentData.write(to: input, options: .atomic) }
        catch { throw PDFConformanceError.cannotWriteInput }

        let process = Process()
        let output = Pipe()
        let errors = Pipe()
        process.executableURL = executable
        process.arguments = ["--format", "json", "--flavour", profile.veraPDFFlavour, input.path]
        process.standardOutput = output
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        let reportData = output.fileHandleForReading.readDataToEndOfFile()
        // veraPDF can return a non-zero status for a valid completed validation
        // whose result is non-compliant. Its JSON report remains authoritative.
        if !reportData.isEmpty,
           (try? JSONSerialization.jsonObject(with: reportData)) != nil {
            return parse(reportData, profile: profile)
        }
        let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
        throw PDFConformanceError.validationFailed(message)
    }

    static func parse(_ data: Data, profile: PDFConformanceProfile) -> PDFConformanceReport {
        let details = (try? JSONSerialization.jsonObject(with: data))
            .flatMap { try? JSONSerialization.data(withJSONObject: $0, options: [.prettyPrinted, .sortedKeys]) }
            .flatMap { String(data: $0, encoding: .utf8) }
            ?? String(data: data, encoding: .utf8)
            ?? "veraPDF không trả về báo cáo JSON."
        let object = try? JSONSerialization.jsonObject(with: data)
        let status: PDFConformanceReport.Status
        if let compliant = findCompliance(in: object) {
            status = compliant ? .compliant : .nonCompliant
        } else {
            status = .unknown
        }
        return PDFConformanceReport(profile: profile, status: status, details: details, findings: findings(in: object, status: status))
    }

    private static func findings(in object: Any?, status: PDFConformanceReport.Status) -> [PDFConformanceReport.Finding] {
        var candidates: [(rule: String, message: String)] = []
        collectFindingCandidates(in: object, inheritedRule: nil, candidates: &candidates)
        var seen = Set<String>()
        let findings = candidates.compactMap { candidate -> PDFConformanceReport.Finding? in
            let message = candidate.message.trimmingCharacters(in: .whitespacesAndNewlines)
            guard message.count >= 4, seen.insert("\(candidate.rule)|\(message)").inserted else { return nil }
            return PDFConformanceReport.Finding(
                rule: candidate.rule.isEmpty ? "veraPDF" : candidate.rule,
                message: message,
                guidance: guidance(for: "\(candidate.rule) \(message)"),
                severity: status == .nonCompliant ? .error : .warning
            )
        }
        if findings.isEmpty, status == .nonCompliant {
            return [PDFConformanceReport.Finding(
                rule: "veraPDF",
                message: "Tài liệu không đạt profile đã chọn.",
                guidance: "Mở dữ liệu thô để xác định assertion lỗi, sau đó kiểm tra font, metadata, tag và cấu trúc trang.",
                severity: .error
            )]
        }
        return Array(findings.prefix(24))
    }

    private static func collectFindingCandidates(in value: Any?, inheritedRule: String?, candidates: inout [(rule: String, message: String)]) {
        if let dictionary = value as? [String: Any] {
            let rule = ["ruleId", "ruleID", "test", "specification", "id"]
                .compactMap { dictionary[$0] as? String }
                .first ?? inheritedRule ?? "veraPDF"
            for key in ["message", "description", "errorMessage", "testAssertion"] {
                if let message = dictionary[key] as? String { candidates.append((rule, message)) }
            }
            for nested in dictionary.values { collectFindingCandidates(in: nested, inheritedRule: rule, candidates: &candidates) }
        } else if let values = value as? [Any] {
            for nested in values { collectFindingCandidates(in: nested, inheritedRule: inheritedRule, candidates: &candidates) }
        }
    }

    private static func guidance(for value: String) -> String {
        let text = value.lowercased()
        if text.contains("font") { return "Nhúng toàn bộ font được render và kiểm tra ánh xạ Unicode." }
        if text.contains("tag") || text.contains("structure") { return "Bổ sung semantic tag và kiểm tra reading order; đây là trọng tâm PDF/UA-2." }
        if text.contains("alternate") || text.contains("alt") { return "Thêm alternate text có ý nghĩa cho hình, biểu đồ và nội dung không phải text." }
        if text.contains("metadata") || text.contains("xmp") { return "Bổ sung metadata XMP, tiêu đề và profile/claim phù hợp với chuẩn đích." }
        if text.contains("language") || text.contains("lang") { return "Khai báo ngôn ngữ tài liệu và ngôn ngữ của từng đoạn khi cần." }
        if text.contains("encrypt") || text.contains("security") { return "PDF/A không cho phép mã hóa; xuất một bản archival không mật khẩu nếu cần lưu trữ." }
        return "Đọc assertion từ veraPDF, sửa ở tài liệu nguồn rồi chạy kiểm tra lại profile này." }

    private static func findCompliance(in value: Any?) -> Bool? {
        if let dictionary = value as? [String: Any] {
            for key in ["isCompliant", "compliant"] {
                if let bool = dictionary[key] as? Bool { return bool }
                if let string = dictionary[key] as? String, let bool = Bool(string) { return bool }
            }
            for nested in dictionary.values {
                if let result = findCompliance(in: nested) { return result }
            }
        } else if let values = value as? [Any] {
            for nested in values {
                if let result = findCompliance(in: nested) { return result }
            }
        }
        return nil
    }

    private static func runtimeURL() -> URL? {
        let candidates = [
            Bundle.main.bundleURL.appending(path: "Contents/Helpers/veraPDF/verapdf"),
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools"),
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools/veraPDF"),
            URL(fileURLWithPath: "/opt/homebrew/bin/verapdf"),
            URL(fileURLWithPath: "/usr/local/bin/verapdf")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
