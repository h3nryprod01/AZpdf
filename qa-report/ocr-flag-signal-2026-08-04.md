# B3.5.4 — Tín hiệu tỉ lệ chữ cái trên corpus scan mô phỏng

> ⚠️ **Đây là scan MÔ PHỎNG, không phải scan thật** (không nhiễu cảm biến, không bóng gáy
> sách, không mực lem). Đọc số ra to hơn nó đáng. Corpus chỉ 8 trang, một font, tiếng Việt
> + tiếng Anh — chưa đủ đại diện cho scan production.

**Ngày đo:** 2026-08-04 · **Công cụ:** `script/ocr_lines.swift` (Vision accurate, vi+en,
`usesLanguageCorrection`) · **Corpus:** `Tests/Fixtures/scanned/scanned-01..08.pdf` (B3.5.2)

## Tín hiệu

Mỗi dòng: `letterRatio = letters / ký-tự-không-trắng`, letters = ký tự Unicode category `L*`
(tiếng Việt có dấu tính là chữ cái). Dòng "rác" (công thức bị Vision bóp méo) có tỉ lệ thấp
(chủ yếu ký tự phụ/điện/số); dòng chữ thật có tỉ lệ cao.

## Bảng FP/FN theo DÒNG (nhãn theo trang)

Trang công thức (scanned-08) cũng chứa các dòng label đọc được (F1, F2…), nên nhãn "formula"
bị thô — những dòng đó tính là FN dòng. Bảng dòng chỉ cho thấy chất tín hiệu; quyết định bật
ở bảng trang dưới.

| ngưỡng | TP | FN | FP | TN |
|---|---|---|---|---|
| 0.5 | 5 | 11 | 3 | 121 |
| 0.6 | 6 | 10 | 4 | 120 |
| 0.7 | 6 | 10 | 10 | 114 |
| 0.8 | 9 | 7 | 29 | 95 |

3 FP-dòng ở 0.5 đều là URL-hex / SHA-256 / dấu chấm `..` rời rạc — **mỗi cái nằm trên một
trang prose khác nhau**, không trang nào có ≥ 2.

## Bảng FP/FN theo TRANG (flag trang khi ≥ 2 dòng dưới ngưỡng) — quyết định B3.5.5

| ngưỡng | TP (trang) | FN | FP (trang) | TN | trang FP |
|---|---|---|---|---|---|
| **0.5** | **1** | **0** | **0** | **7** | **—** |
| 0.6 | 1 | 0 | 1 | 6 | scanned-05 |
| 0.7 | 1 | 0 | 2 | 5 | scanned-01, scanned-05 |
| 0.8 | 1 | 0 | 5 | 2 | 01, 04, 05, 06, 07 |

## Kết luận

**Ngưỡng 0.5 cho FP = 0 ở mức trang trên cả 8 trang**, và bắt đúng trang công thức
(scanned-08, 5 dòng dưới 0.5: `2=0土✕8-40c`, `eiT +1=0`, `55°e do =47`, `6`, `n=1`). TP=1, FN=0.

⇒ **B3.5.5 ĐƯỢC BẬT ở ngưỡng 0.5** (trang có ≥ 2 dòng tỉ lệ-chữ < 0.5 → cảnh báo).

## Hạn chế / rủi ro

1. **n = 8 trang, scan mô phỏng, 1 font.** scanned-05 (README-VI đoạn hướng dẫn Linux) chứa
   nhiều dòng SHA-256 / lệnh shell → tỉ lệ chữ thấp. Ở 0.5 mỗi trang prose chỉ ≤ 1 dòng dưới
   ngưỡng nên không flag, nhưng biên rất hẹp: thêm một trang có 2 dòng hex/SHA là FP ngay.
   Đừng hạ ngưỡng hoặc nới "≥2" mà không đo lại trên scan thật.
2. Nhãn dòng theo trang là thô (trang công thức có dòng label đọc được) — bảng dòng đánh giá
   thấp chất tín hiệu; bảng trang mới là cơ sở quyết định.
3. Chỉ đo được trên macOS (Vision). Tesseract (Linux/Win) có thể cho tỉ lệ-chữ khác cho cùng
   dòng rác — chưa đo.
