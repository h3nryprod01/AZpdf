import Foundation

enum PDFConformanceProfile: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case pdfA4
    case pdfUA2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: "Tự nhận diện claim trong PDF"
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

    let profile: PDFConformanceProfile
    let status: Status
    let details: String
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
    static func validate(_ documentData: Data, profile: PDFConformanceProfile) throws -> PDFConformanceReport {
        guard let executable = runtimeURL() else { throw PDFConformanceError.runtimeUnavailable }
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
        guard process.terminationStatus == 0 else {
            let message = String(data: errors.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? "unknown error"
            throw PDFConformanceError.validationFailed(message)
        }
        return parse(reportData, profile: profile)
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
        return PDFConformanceReport(profile: profile, status: status, details: details)
    }

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
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools"),
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools/veraPDF"),
            URL(fileURLWithPath: "/opt/homebrew/bin/verapdf"),
            URL(fileURLWithPath: "/usr/local/bin/verapdf")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
