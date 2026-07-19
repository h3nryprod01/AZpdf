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
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let result = Result { try PDFConformanceService.validate(data, profile: profile) }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isConformanceChecking = false
                switch result {
                case let .success(report): self.conformanceReport = report
                case let .failure(error): self.conformanceError = error.localizedDescription
                }
            }
        }
    }
}
