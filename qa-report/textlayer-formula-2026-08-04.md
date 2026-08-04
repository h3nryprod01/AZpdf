# B3.5.1 — Lớp text của PDF born-digital có công thức: dùng được không?

**Ngày đo:** 2026-08-04 · **Đường đo:** `PDFPage.string` (đúng đường AZpdf dùng, KHÔNG qua OCR)

## Nguồn fixture

`Tests/Fixtures/source/formula-born-digital.pdf` — **sinh tại máy bằng `pdflatex`**, KHÔNG phải
file matplotlib `~/ocr-bench/formula_test.pdf` trên Ubuntu box.

Lý do đổi nguồn (phải ghi rõ): bước `scp cuongdn@100.111.47.82:...formula_test.pdf` bị classifier
auto-mode của harness **từ chối** (host 100.111.47.82 chưa được cấp quyền trong session này). Quét
`mdfind` 300 PDF có trên máy → **0** file có `/Producer` TeX. Nhưng máy CÓ `pdflatex`
(`/Library/TeX/texbin/pdflatex`). Bước 2 của plan bảo "tìm PDF do LaTeX sinh, có thì đo luôn" — sinh
một file như vậy là cách tự chứa thoả ý bước đó, và còn đại diện hơn file matplotlib (xem hạn chế).

LaTeX nguồn: 6 công thức F1–F6 (bậc hai, Euler, Pythagore, tích phân Gauss, Basel, Einstein) xen
prose, gói `amsmath`.

- `/Producer`: **pdfTeX-1.40.27**
- `/Creator`: **TeX**

## Text layer trích được (verbatim, theo `PDFPage.string`, 1 trang)

```
Formula text-layer test
This born-digital page mixes prose and six formulas (F1–F6) so we can see
exactly what the embedded text layer stores for each.
F1 (quadratic formula):
x=−b±√b2
2a
−4ac
F2 (Euler identity):
eiπ + 1 = 0
F3 (Pythagorean theorem):
a2 + b2
= c2
F4 (Gaussian integral):
∞
0
F5 (Basel problem):
e−x2 dx=
√π
2
∞
n=1
1
π2
=
n2
6
F6 (mass-energy equivalence):
E= mc2
1
```

## Đánh giá từng công thức

| # | Công thức thật | Text layer | Dùng được? |
|---|---|---|---|
| F1 | x = (−b ± √(b²−4ac)) / 2a | `x=−b±√b2` / `2a` / `−4ac` — ký hiệu đúng (−, ±, √), nhưng tử/mẫu **đứt dòng, sai thứ tự** | Một phần — nhận ra được |
| F2 | e^(iπ) + 1 = 0 | `eiπ + 1 = 0` — đủ, lũy thừa ghép inline | **Được** |
| F3 | a² + b² = c² | `a2 + b2` / `= c2` — lũy thừa thành số thường, đứt dòng | Một phần — nhận ra được |
| F4 | ∫₀^∞ e^(−x²) dx = √π/2 | `∞` / `0` / `e−x2 dx=` / `√π` / `2` — **dấu ∫ MẤT**, giới hạn rời rạc | Kém — mất toán tử chính |
| F5 | Σ_{n=1}^∞ 1/n² = π²/6 | `∞` / `n=1` / `1` / `π2` / `=n2` / `6` — **dấu Σ MẤT**, xáo thứ tự | Kém — mất toán tử chính |
| F6 | E = mc² | `E= mc2` — đủ | **Được** |

## Kết luận

Born-digital LaTeX trích **ký hiệu toán học thật** (−, ±, √, π, ∞, lũy thừa dạng chữ số), **KHÔNG
phải rác fabricated** như nhánh scan (`Söe-*dx=#` với confidence 1,00). Hai dấu toán tử lớn (**∫ ở
F4, Σ ở F5**) bị mất, và phân thức/thành phần xếp chồng bị **đứt dòng sai thứ tự** — nhưng nội dung
nhận ra được, không bịa.

⇒ **DÙNG ĐƯỢC (một phần). Không kích điều kiện STOP.** Vấn đề rác-im-lặng mà pha nhắm là **đặc
trưng nhánh scan** (đường OCR/Vision), không lây sang born-digital (đường text layer).

## Hạn chế (bắt buộc)

1. **Đây là nhánh LaTeX (math text thật).** Kết quả **không** suy ra cho matplotlib/mathtext: plan
   đã đo mathtext được vẽ thành **đường vector**, nên `PDFPage.string` của file matplotlib sẽ khác
   hẳn (khu vực công thức có khi rỗng). Nhánh đó **chưa đo được** ở máy này (scp bị chặn). Nếu cần
   phải đo riêng bằng file matplotlib thật khi có quyền ssh.
2. Mất ∫/Σ phụ thuộc font/gói TeX cụ thể (pdfTeX + font Type1 ở đây); bản unicode-math/LuaTeX có
   thể giữ tốt hơn. Không suy rộng cho mọi PDF LaTeX.
3. Fixture này sẽ dùng tiếp làm **trang 8 của B3.5.2** (corpus scan mô phỏng).

## Quyết định

**TIẾP TỤC B3.5.2.** Born-digital không "cũng hỏng" theo nghĩa rác-fabricated; ưu tiên pha giữ
nguyên (nhắm scan OCR).
