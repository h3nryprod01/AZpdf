import Foundation
import XCTest
@testable import AZpdfCore

/// Ghim rằng fixture nhúng trong `ConformanceFixture` thực sự là bytes hợp lệ — không rỗng,
/// đúng magic. Nếu base64 hỏng (dán sai, cắt bớt) thì `selftest` chạy trên nền tảng không có
/// bash sẽ dùng fixture rác và báo cáo conform rỗng, mà vẫn exit 0 — tức là gate vô dụng.
/// Test này chặn đúng chỗ đó.
final class ConformanceFixtureTests: XCTestCase {
    func testFixtureIsValidPDFAndPNG() {
        let pdf = ConformanceFixture.pdf
        XCTAssertFalse(pdf.isEmpty, "PDF fixture rỗng — base64 hỏng.")
        XCTAssertEqual(Data(pdf.prefix(5)), Data("%PDF-".utf8),
                       "PDF phải bắt đầu bằng %PDF-, nhận: \(pdf.prefix(8).map(String.init(describing:)))")

        let png = ConformanceFixture.imagePNG
        XCTAssertFalse(png.isEmpty, "PNG fixture rỗng.")
        XCTAssertEqual(Data(png.prefix(4)), Data([0x89, 0x50, 0x4E, 0x47]),
                       "PNG phải bắt đầu bằng magic \\x89PNG.")
    }
}
