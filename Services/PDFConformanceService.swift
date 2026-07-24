import Foundation

enum PDFConformanceProfile: String, CaseIterable, Identifiable, Sendable {
    case automatic
    case pdfA4
    case pdfUA2

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .automatic: L("Auto-detect claim (fallback PDF/A-1b)")
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
            case .compliant: L("Compliant")
            case .nonCompliant: L("Non-compliant")
            case .unknown: L("Unknown")
            }
        }
    }

    struct Finding: Identifiable, Sendable {
        enum Severity: Sendable {
            case error
            case warning

            var displayName: String { self == .error ? L("Fix needed") : L("Review needed") }
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
        case .compliant: L("The validator found no issues with the selected profile.")
        case .nonCompliant: L("The validator found \(findings.count) items to fix or review.")
        case .unknown: L("The validator returned no conclusive status; check the raw data to compare.")
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
            L("No veraPDF runtime found. Install veraPDF, or use an AZpdf build that bundles the validator, to validate PDF conformance.")
        case .cannotWriteInput:
            L("Could not create the temporary PDF for conformance validation.")
        case let .validationFailed(message):
            L("veraPDF could not validate the document: \(message)")
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
            ?? L("veraPDF returned no JSON report.")
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
                message: L("The document does not conform to the selected profile."),
                guidance: L("Open the raw data to identify the failed assertion, then check fonts, metadata, tags, and page structure."),
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
        if text.contains("font") { return L("Embed every font used for rendering and check the Unicode mapping.") }
        if text.contains("tag") || text.contains("structure") { return L("Add semantic tags and check the reading order; this is the focus of PDF/UA-2.") }
        if text.contains("alternate") || text.contains("alt") { return L("Add meaningful alternate text for images, charts, and non-text content.") }
        if text.contains("metadata") || text.contains("xmp") { return L("Add XMP metadata, a title, and a profile/claim matching the target standard.") }
        if text.contains("language") || text.contains("lang") { return L("Declare the document language, and the language of individual passages where needed.") }
        if text.contains("encrypt") || text.contains("security") { return L("PDF/A does not allow encryption; export an unencrypted archival copy if needed.") }
        return L("Read the assertion from veraPDF, fix it in the source document, then re-run this profile check.") }

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
            Bundle.main.bundleURL.appending(path: "Contents/Resources/Helpers/veraPDF/verapdf"),
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools"),
            Bundle.main.url(forResource: "verapdf", withExtension: nil, subdirectory: "Tools/veraPDF"),
            URL(fileURLWithPath: "/opt/homebrew/bin/verapdf"),
            URL(fileURLWithPath: "/usr/local/bin/verapdf")
        ].compactMap { $0 }
        return candidates.first { FileManager.default.isExecutableFile(atPath: $0.path) }
    }
}
