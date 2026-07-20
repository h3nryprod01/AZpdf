# MuPDF prototype benchmark — 2026-07-18

- Runtime: `mutool version 1.28.0`
- Platform: macOS Darwin arm64
- Render: PNG, 144 dpi
- Fixtures: generated deterministically by `script/generate_pdf_fixtures.sh`

| Fixture | Pages | Input bytes | Render seconds | Peak RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| basic | 1 | 866 | 0.08 | 24,723,456 |
| rotated | 1 | 841 | 0.11 | 24,723,456 |
| two-column | 1 | 833 | 0.10 | 24,559,616 |

`stext.json` giữ riêng từng text block, line, font, bounding box và thứ tự hai cột trong fixture. Đây mới là baseline kỹ thuật, chưa phải kết luận parity: cần thêm PDF thực tế, file malformed/encrypted, form, annotation, font phức tạp và pixel diff với PDFKit.
