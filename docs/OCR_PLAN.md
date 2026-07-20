# OCR local-first cho AZpdf

## Baseline đã triển khai

AZpdf có contract OCR portable trong `AZpdfCore`, adapter `OCRmyPDFProcessor`, lệnh `ocr-health`/`ocr` và flow Flutter cho Linux. Người dùng chọn `vie`, `eng` hoặc `vie+eng`, deskew và tự phát hiện hướng trang. OCR chạy trên working copy, giữ nguyên hình thức trang, thêm text layer tìm kiếm và có Undo/Redo trước khi Save.

`DocumentIR` schema v1 đã được triển khai trong core Foundation-only. IR dùng PDF point với gốc top-left, lưu provenance provider/model, reading order, text line/word/quad, style, bảng có row/column span, công thức LaTeX/MathML, figure/alt text và quan hệ semantic. Validation từ chối geometry/confidence sai, ID hoặc reading-order trùng/mất và reference semantic không tồn tại; JSON round-trip được test độc lập với UI/engine.

Contract provider v1 cũng đã có: capability handshake khai báo model/version/SPDX license, CPU/GPU local execution, feature, BCP 47 language, VRAM và giới hạn số trang; request khai báo page index, language, feature bắt buộc, DPI và chính sách trang đã có text. Remote endpoint không tồn tại trong contract v1.

MuPDF `stext.json` hiện có thể đi qua `DocumentIRBuilder` để tạo IR baseline ngay từ PDF. Builder giữ thứ tự block, style dòng, image region và chuyển geometry PDF bottom-left sang top-left đúng cho rotation 0°/90°/180°/270°. CLI `ir-baseline`, `ir-validate`, `ir-export-text` đã smoke test với fixture PDF thường và xoay.

Flutter shell đã có màn hình review `DocumentIR` cho trang hiện tại: danh sách block theo reading order, overlay top-left trên bản render, loại block, geometry/confidence, provenance provider/model và copy plain text. MuPDF baseline được gắn nhãn rõ là chưa hiểu bảng/công thức; visual QA dùng engine Linux Release thật đã đạt.

QA Ubuntu 24.04 đã chạy PDF chỉ có ảnh bằng OCRmyPDF 15.2.0 + Tesseract 5.3.4: trước OCR không có text; profile `eng` trích xuất đúng ba dòng, còn profile mặc định `vie+eng` nhận sai token hiếm `AZpdf` thành `A2 pdf` nhưng tìm “Portable” trong UI vẫn trả về 1 kết quả. Undo đã xóa text layer và chạy lại truy vấn để không giữ kết quả cũ.

## Capability contract

| Provider | Searchable PDF | Giữ hình thức trang | Reading order/bounding box | Bảng | Công thức | Output cấu trúc |
|---|---:|---:|---:|---:|---:|---:|
| OCRmyPDF + Tesseract | Có | Có | Hạn chế | Không | Không | Không |
| PP-StructureV3 | Có thể ghép | Có thể dựng lại | Có | Có | Có | Markdown/JSON |
| PaddleOCR-VL 1.6 | Qua adapter | Có thể dựng lại | Có | Có | Có | JSON/Markdown qua DocumentIR |
| Docling | Qua adapter | Có thể dựng lại | Có | Có | Có stage riêng | Docling document/JSON/Markdown |
| MinerU | Qua adapter | Có thể dựng lại | Có | Có | Có | JSON/Markdown |

UI chỉ hiển thị khả năng provider thực sự khai báo; baseline OCRmyPDF không được gắn nhãn “hiểu” bảng, công thức hay reading order ngữ nghĩa.

## Hướng phát triển

1. **v2 baseline:** hoàn tất runtime OCR Linux; tiếp tục Windows, checksum/SBOM, CPU/memory/timeout và file tạm.
2. **DocumentIR:** schema và provider contract v1 đã có; tiếp theo thêm JSON Schema, migration/version negotiation và fixture đa provider.
3. **Advanced Layout:** plugin local PaddleOCR-VL/PP-StructureV3 cho workstation có GPU, ánh xạ block, reading order, bảng, ảnh và công thức vào `DocumentIR`; không ghi đè PDF trước màn hình review.
4. **Document Intelligence:** adapter Docling là lựa chọn CPU/GPU portable; MinerU là profile nghiên cứu cho tài liệu khoa học phức tạp.
5. **Review editor:** viewer overlay/confidence/reading order đã có; tiếp theo sửa text/bảng/công thức, reorder block và xuất PDF, Markdown, JSON.
6. **Bộ đo:** CER/WER tiếng Việt, TEDS cho bảng, exact/normalized match cho công thức, reading-order score, latency và peak VRAM/RAM.

## Ranh giới an toàn

- Không tự chạy OCR khi mở PDF; không gửi PDF, ảnh, text hay telemetry ra Internet.
- Model/provider nâng cao chạy trong worker có sandbox; model phải được người dùng cài hoặc AZpdf đóng gói và xác minh.
- Process adapter mặc định từ chối runner không có network-isolated OS sandbox. Linux Bubblewrap phân loại lỗi namespace/AppArmor thành `sandboxUnavailable` và không fallback unsandboxed. Runner Flatpak dùng subsandbox `flatpak-spawn --sandbox --no-network`, chỉ nhận provider đã đóng gói dưới `/app`, expose input/request read-only và output directory riêng; cấm `--host`. Probe subsandbox và GTK portal E2E đã đạt trên Ubuntu 24.04. Gói hệ thống vẫn cần AppArmor profile được review; không tự biến `bwrap` thành setuid. Portal KDE thật và manifest reproducible từ source còn là release gate.
- Luôn OCR working copy; kiểm tra PDF đầu ra, số trang và khả năng Undo trước Save.

Tham khảo: [OCRmyPDF](https://ocrmypdf.readthedocs.io/en/latest/introduction.html), [PaddleOCR-VL 1.6](https://www.paddleocr.ai/main/en/version3.x/algorithm/PaddleOCR-VL/PaddleOCR-VL-1.6.html), [PP-StructureV3](https://www.paddleocr.ai/main/en/version3.x/algorithm/PP-StructureV3/PP-StructureV3.html), [Docling model catalog](https://docling-project.github.io/docling/usage/model_catalog/), [MinerU](https://github.com/opendatalab/mineru).
