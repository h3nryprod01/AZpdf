# Thông báo phần mềm bên thứ ba

AZpdf được phát hành theo AGPL-3.0-only. Bản phát hành macOS có thể kèm các
runtime dưới đây để mọi thao tác PDF/OCR chạy cục bộ. Bản SBOM SPDX nằm trong
`AZpdf.app/Contents/Resources/SBOM.spdx` và cạnh file ZIP release, ghi phiên
bản và SHA-256 của artifact thực tế.

| Thành phần | Vai trò | License chính |
| --- | --- | --- |
| MuPDF | Chèn ảnh, xử lý PDF (`mutool`) | AGPL-3.0-or-later |
| veraPDF | Kiểm tra PDF/A và PDF/UA | GPL-3.0-or-later hoặc MPL-2.0 |
| OpenJDK/Temurin JRE | Chạy veraPDF | GPL-2.0-only với Classpath Exception |
| pyHanko | Ký và xác thực PAdES | MIT |
| PyInstaller | Freeze Python runtime | GPL-2.0-only, ngoại lệ phân phối executable |
| OCRmyPDF | Tạo searchable PDF | MPL-2.0 |
| Tesseract OCR + tessdata | Nhận dạng `eng`/`vie` | Apache-2.0 |
| Ghostscript | Raster/PDF processing cho OCR | AGPL-3.0-or-later |
| qpdf | Kiểm tra và xử lý PDF cho OCR | Apache-2.0 |

Các thư viện transitive được ghi bằng checksum file trong SBOM của đúng bản
release. Người phân phối bản đã sửa đổi phải giữ notices này, cung cấp source
tương ứng theo license và bổ sung notices/SBOM nếu thay runtime.

Nguồn chính thức: [MuPDF](https://mupdf.com/),
[veraPDF](https://verapdf.org/), [pyHanko](https://github.com/MatthiasValvekens/pyHanko),
[OCRmyPDF](https://ocrmypdf.readthedocs.io/), [Tesseract](https://github.com/tesseract-ocr/tesseract),
[Ghostscript](https://ghostscript.com/), [qpdf](https://qpdf.readthedocs.io/).
