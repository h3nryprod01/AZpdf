# Luật cập nhật baseline pixel-diff

> Cổng này canh thứ mà 217 unit test không thấy: **render đổi**. Nó chỉ còn giá trị chừng nào
> không ai cập nhật baseline cho CI xanh. Luật dưới đây tồn tại để giữ điều đó.

## Cổng làm gì

`script/render_baselines.swift` render 4 trang fixture ở **đúng 144 DPI** (DPI nằm trong tên
file, không phải cờ, để nó không trôi ngầm). `script/pixel_diff.sh` so với baseline đã commit.

**Không có ngưỡng tỉ lệ.** Một pixel "lệch" nếu một kênh nào đó lệch quá `8/255` — dung sai
theo từng pixel, là nhiễu làm tròn thật của rasterizer. Gate FAIL nếu có **bất kỳ** pixel nào lệch.

## Vì sao không có ngưỡng phần trăm — đo được, không phải quan điểm

Bản đầu FAIL khi `>0,1%` pixel lệch. Hỏng theo hai cách độc lập, đo 2026-08-08:

| Phép thử | Kết quả | Gate nói |
|---|---|---|
| Dịch ảnh **2 pixel** | 204 / 1.938.816 px (0,011 %) | **XANH** |
| So **trang 1 với trang 2** cùng tài liệu, nội dung khác hẳn | 673 / 2.003.960 px (0,034 %) | **XANH** |

Nguyên nhân gốc: phần trăm trên **tổng** số pixel là thước đo vô nghĩa với tài liệu thưa. Trang
A4 chữ đen nền trắng có ~99,97 % pixel trắng, nên dù chữ sai hoàn toàn, tỉ lệ vẫn không chạm
0,1 %. Vặn con số nhỏ lại chỉ dời chỗ hỏng chứ không chữa — mọi ngưỡng tỉ lệ đều mắc bệnh này.

Làm được cách "0 pixel" vì render đã chứng minh **tất định byte-for-byte**: render lại vào thư
mục khác cho ra 4/4 file giống hệt từng byte. Không có tính đó thì cả cổng này vô nghĩa.

## Khi cổng đỏ — làm theo thứ tự này

1. **Xem đã, đừng cập nhật baseline.** Đọc số pixel lệch trong output. Đỏ với ~40 px là nhiễu
   hệ điều hành; đỏ với vài trăm px là render đổi thật. Hai loại xử khác nhau.
2. **Hỏi: mình có sửa gì liên quan tới render không?** Chú thích, layout, phông, tỉ lệ, PDFKit.
   Có ⇒ nhiều khả năng đây là regression thật, và cổng vừa làm đúng việc của nó.
3. **Nếu là thay đổi có chủ đích** ⇒ cập nhật baseline **trong cùng commit với thay đổi gây ra
   nó**, và commit message phải nói vì sao render đổi. Reviewer cần thấy nguyên nhân và hệ quả
   cạnh nhau.
4. **Nếu là runner macOS đổi phiên bản** ⇒ cập nhật baseline **trong một commit riêng, không
   kèm thay đổi code nào khác**, message ghi rõ phiên bản cũ → mới. Commit đó phải dễ soi.

## Ba điều cấm

- **Không bao giờ** cập nhật baseline chỉ để CI xanh. Nếu không giải thích được vì sao render
  đổi thì chưa được cập nhật.
- **Không** đặt lại ngưỡng tỉ lệ. Nó đã được đo là hỏng; xem bảng trên.
- **Không** thêm fixture nặng vào baseline. Hai trang scan từng nằm trong danh sách: chúng
  chiếm 7,9 MB trong tổng 8,0 MB, trong khi bốn fixture còn lại cộng lại 208 KB — mà chúng chỉ
  là ảnh chụp, render chúng không kiểm bố cục chữ hay vẽ chú thích. Đã bỏ.

## Cách chạy tay

```bash
./script/pixel_diff.sh --self-test                      # cổng còn bắt được không
swift script/render_baselines.swift --out /tmp/render   # render lại
./script/pixel_diff.sh Tests/Fixtures/render/baseline /tmp/render
swift script/render_baselines.swift                     # CẬP NHẬT baseline (đọc luật trên trước)
```
