import Foundation
import AZpdfCore

// PDF/A and PDF/UA conformance checking via the local validator.
extension DocumentStore {
    func beginConformanceCheck() {
        guard document != nil else { return }
        conformanceReport = nil
        conformanceError = nil
        isConformanceSheetPresented = true
    }

    func checkConformance(_ profile: PDFConformanceProfile) {
        guard let data = document?.dataRepresentation(), !isConformanceChecking else { return }
        isConformanceChecking = true
        conformanceError = nil
        Task {
            let result = await Task.detached(priority: .userInitiated) { Result { try PDFConformanceService.validate(data, profile: profile) } }.value
            isConformanceChecking = false
            switch result {
            case let .success(report): conformanceReport = report
            case let .failure(error): conformanceError = error.localizedDescription
            }
        }
    }
}
