import SwiftUI

/// Kích thước canvas vẽ chữ ký — dùng chung cho view (`SignatureSheet`)
/// và cho ánh xạ toạ độ (`PDFReaderView.signaturePoint`) để hai nơi không
/// lệch tỉ lệ nếu canvas đổi kích thước. (Tên tránh đụng `SignatureCanvas`
/// view struct ở cuối file.)
enum SignatureCanvasMetrics {
    static let size = CGSize(width: 520, height: 190)
}

struct SignatureSheet: View {
    @Bindable var store: DocumentStore

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(L("Handwritten Signature"))
                .font(.title2.weight(.semibold))
            Text(L("Draw your signature with a mouse or trackpad. After confirming, click directly on the PDF to place it; all data is processed on this Mac."))
                .foregroundStyle(.secondary)
            SignatureCanvas(strokes: $store.draftSignatureStrokes)
                .frame(width: SignatureCanvasMetrics.size.width, height: SignatureCanvasMetrics.size.height)
            HStack {
                Button(L("Clear Strokes")) { store.draftSignatureStrokes = [] }
                    .disabled(store.draftSignatureStrokes.isEmpty)
                Spacer()
                Button(L("Cancel"), role: .cancel) { store.isSignatureSheetPresented = false }
                Button(L("Insert Signature")) { store.addSignature() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(store.draftSignatureStrokes.allSatisfy { $0.points.count < 2 })
            }
        }
        .padding(24)
        .frame(width: 570)
        .background(EscapeDismissInstaller { store.isSignatureSheetPresented = false })
    }
}

private struct SignatureCanvas: View {
    @Binding var strokes: [SignatureStroke]
    @State private var activeStroke: [CGPoint] = []

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, _ in
                for stroke in strokes + (activeStroke.count > 1 ? [SignatureStroke(points: activeStroke)] : []) {
                    guard let first = stroke.points.first else { continue }
                    var path = Path()
                    path.move(to: first)
                    for point in stroke.points.dropFirst() { path.addLine(to: point) }
                    context.stroke(path, with: .color(.primary), lineWidth: 2.8)
                }
            }
            .background(.background, in: RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(.quaternary))
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let location = CGPoint(
                            x: min(max(0, value.location.x), proxy.size.width),
                            y: min(max(0, value.location.y), proxy.size.height)
                        )
                        activeStroke.append(location)
                    }
                    .onEnded { _ in
                        if activeStroke.count > 1 { strokes.append(SignatureStroke(points: activeStroke)) }
                        activeStroke = []
                    }
            )
        }
    }
}
