import SwiftUI
import AppKit

struct HelpView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text("Trợ giúp AZpdf").font(.title.weight(.bold))
                GroupBox("Bắt đầu") {
                    Text("Dùng ⌘O để mở PDF, hoặc kéo tệp PDF vào cửa sổ. Mỗi tài liệu mở trong một tab riêng.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Phím tắt") {
                    Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                        GridRow { Text("Mở PDF"); Text("⌘O") }
                        GridRow { Text("Lưu"); Text("⌘S") }
                        GridRow { Text("Trang trước / sau"); Text("⌘[ / ⌘]") }
                        GridRow { Text("Ghi chú / tô sáng"); Text("⇧⌘N / ⇧⌘H") }
                        GridRow { Text("Chữ ký tay"); Text("⇧⌘S") }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("An toàn dữ liệu") {
                    Text("AZpdf xử lý PDF, mật khẩu và lịch sử tài liệu trên máy. Redact là thao tác phá hủy: trang bị raster hóa để loại bỏ nội dung gốc.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Chữ ký số và plugin") {
                    Text("Ký bằng certificate xuất tệp CMS/PKCS#7 .p7s tách rời. Plugin chỉ chạy cục bộ sau khi được cấp quyền rõ ràng; bản v1 chưa bật thực thi plugin tùy ý.")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                GroupBox("Ủng hộ AZpdf") {
                    VStack(spacing: 10) {
                        if let qrURL = Bundle.main.url(forResource: "donate-vietqr", withExtension: "jpg"),
                           let qrImage = NSImage(contentsOf: qrURL) {
                            Image(nsImage: qrImage)
                                .resizable()
                                .scaledToFit()
                                .frame(maxWidth: 260)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        Link("Ủng hộ online qua Ko-fi", destination: AZpdfLinks.koFi)
                    }
                    .frame(maxWidth: .infinity)
                }
                Link("Mã nguồn và hướng dẫn phát triển", destination: AZpdfLinks.repository)
            }
            .padding(24)
        }
        .frame(width: 620, height: 500)
    }
}
