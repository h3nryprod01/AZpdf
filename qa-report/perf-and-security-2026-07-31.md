# Đo hiệu năng file lớn + quét security — 2026-07-31

> Mọi số dưới đây là **đo trên máy dev (Apple Silicon, macOS 15)**, không phải ước lượng.
> Fixture sinh bằng `mutool convert` từ HTML, seed cố định nên tái lập được; chúng **không**
> được commit vào repo (91 MB). Script sinh + harness đo nằm ở cuối file.

## 1. Hiệu năng file lớn

Khoảng trống này tồn đọng từ kế hoạch nâng cấp: fixture lớn nhất trong repo là **8.7 KB**, nên
mọi phát biểu về hiệu năng trước đây đều là phỏng đoán. Giờ có số.

| Tài liệu | Mở tài liệu | Thumbnail 50 trang | Tìm 1 chuỗi toàn văn | RSS đỉnh |
|---|---|---|---|---|
| 6.6 MB · 400 trang | 71 ms¹ | 48 ms (1.0 ms/trang) | **495 ms** | 119 MB |
| 31 MB · 2 000 trang | 2 ms | 29 ms (0.6 ms/trang) | **2 822 ms** | 500 MB |
| 91 MB · 6 000 trang | 4 ms | 33 ms (0.7 ms/trang) | **10 671 ms** | **1 277 MB** |

¹ Lần đầu gồm cả chi phí khởi động lạnh của PDFKit; các lần sau là 2–4 ms.

**Mở file KHÔNG phải vấn đề.** PDFKit parse lazy, nên 91 MB mở trong 4 ms. Giả định ngầm lâu
nay rằng "file lớn thì mở lâu" là sai.

**Thumbnail cũng không phải vấn đề như lo ngại.** `SidebarView.swift:121` gọi
`page.thumbnail(...)` đồng bộ ngay trong `body` và không có cache riêng, nhưng đo cho thấy
PDFKit có cache nội bộ: lượt render thứ hai của cùng 50 trang rẻ hơn ~30–40% (19–22 ms so với
29–48 ms). Cộng với việc `List` của SwiftUI chỉ dựng hàng đang hiển thị, chi phí thực tế bị
chặn trên bởi số thumbnail nhìn thấy được, không phải tổng số trang.

### CRITICAL — tìm kiếm đóng băng UI, tỉ lệ thuận với số trang

`Views/PDFReaderView.swift:76` gọi `findString` **đồng bộ bên trong `updateNSView`**, tức trên
main thread. Và `Views/ContentView.swift:153` bind thẳng:

```swift
TextField(L("Find in PDF"), text: $store.searchText)
```

Không debounce. Mỗi ký tự gõ vào ô tìm kiếm đổi `store.searchText`, kéo theo một lần quét
**toàn bộ tài liệu** trên main thread trước khi UI vẽ lại được.

| Tài liệu | 1 lần tìm | Gõ truy vấn 11 ký tự |
|---|---|---|
| 400 trang | 0,5 s | ~5 s đơ |
| 2 000 trang | 2,8 s | **~31 s đơ** |
| 6 000 trang | 10,7 s | **~117 s đơ** |

Với tài liệu 6 000 trang, gõ một từ khoá ngắn khoá giao diện gần hai phút. Người dùng sẽ coi
đây là treo máy, không phải chậm.

### ĐÃ SỬA — đo lại trên đúng fixture đó

`Stores/DocumentStore+Search.swift` bọc `PDFDocument.beginFindString(_:withOptions:)` (API bất
đồng bộ sẵn có của PDFKit, báo kết quả qua notification) kèm debounce 250 ms và huỷ lượt cũ.

| Gõ truy vấn 11 ký tự · 6 000 trang · 91 MB | Main thread bị giữ | Số lượt quét |
|---|---|---|
| Trước | **12 362 ms** | 11 |
| Sau | **0,0 ms** (dưới ngưỡng đo) | **1** |

Con số "sau" không phải là tìm kiếm chạy nhanh hơn — bản thân lượt quét vẫn mất chừng ấy thời
gian, nhưng nó chạy ngoài main thread và 11 keystroke gộp còn một lượt, nên giao diện không
còn bị giữ. Đó mới là thứ người dùng cảm nhận.

Hai lỗi lộ ra khi review bản sửa đầu, cả hai đều đo được:

1. Huỷ một lượt **đang bay** vẫn giao kết quả, vì `cancelFindString()` chạy trước khi gỡ
   observer. Tệ hơn: `handleEnd` set `onResults = nil`, nên kết quả **đúng** của lượt kế tiếp
   không bao giờ tới — chính là tình huống gõ thêm một ký tự trên tài liệu lớn.
2. Vòng giữ `Coordinator → PDFSearchRunner → onResults → Coordinator`: đóng tab giữa lúc đang
   tìm rò cả `PDFView` lẫn tài liệu.

Cả hai được ghim bằng test, và mutation (trả lại nguyên code cũ) làm đúng hai test đó đỏ.

### Bộ nhớ

RSS đỉnh ~1,3 GB cho file 91 MB (≈14× kích thước file) sau khi mở + dựng 100 thumbnail + một
lượt tìm toàn văn. Đo trong tiến trình riêng cho từng file; lần đo đầu chạy chung một tiến
trình cho cả ba file và cho thấy bộ nhớ **không** được trả lại giữa các tài liệu (nền tăng dần
9 → 114 → 483 MB) — đáng theo dõi khi mở nhiều tab, nhưng chưa đo riêng nên chưa kết luận.

## 2. Quét security

Phạm vi: gọi tiến trình ngoài, xử lý bí mật, dependency, bề mặt IPC, xử lý URL.

### Đạt

- **Không có shell injection.** Cả 4 chỗ gọi tiến trình ngoài (`MuPDFImageOverlayService`,
  `OCRMyPDFService`, `PDFConformanceService`, `PAdESSigningService`) dùng `Process` với
  `executableURL` + mảng `arguments`. Không nơi nào dựng chuỗi lệnh hay gọi `/bin/sh`.
- **Mật khẩu PKCS#12 không đi qua argv.** `PAdESSigningService` ghi mật khẩu ra file rồi truyền
  `--passfile`; argv thì mọi tiến trình trên máy đọc được qua `ps`. Thư mục tạm được `chmod 0700`
  **trước khi** ghi bất kỳ file nào, file bí mật `chmod 0600`, và `defer` xoá cả thư mục. Cửa sổ
  file tồn tại với quyền mặc định nằm trong thư mục không ai đi vào được, nên vô hại.
- **TSA URL được kiểm scheme** phải là http(s) trước khi dùng.
- **Không có secret hardcode** trong `.swift`/`.dart`/`.sh`/`.yml`.
- **Dependency Swift ghim theo revision** (commit bất biến), không phải range.
- **Chỉ một chỗ mở URL**, và là hằng số cứng (link Ko-fi). Không có URL nào lấy từ nội dung PDF.
- **Không log mật khẩu** ở bất kỳ đâu.

### Đã sửa trong lượt này

- **Gate local-first phủ thiếu chính lời nó hứa.** `script/audit_local_first.sh` quét
  `App Core Models Services Stores Support Views` — bỏ sót **`Adapters/` và `Tools/`**, nơi chứa
  `AZpdfMuPDF`, `AZpdfPAdES`, `AZpdfStructuredOCR` và CLI `azpdf-engine`. README nói gate bảo vệ
  "the app and core targets"; đó đúng là core target. Hai thư mục này hiện **sạch**, nên không có
  vi phạm nào lọt lưới — nhưng khoảng trống chỉ lộ ra vào đúng ngày ai đó thêm lệnh gọi mạng vào
  engine, và lúc đó thì không lộ ra nữa, vì không có gì đang canh. Đã thêm vào danh sách quét và
  kiểm lại: vi phạm cắm vào cả `Tools/` lẫn `Adapters/` đều bị bắt.

### Ghi nhận, không sửa

- **Engine CLI tin tưởng hoàn toàn phía gọi.** `azpdf-engine` nhận `--document`/`--output` và
  dùng thẳng, không giới hạn thư mục. Trong mô hình hiện tại nó là CLI chạy **cùng máy, cùng
  user** với vỏ Flutter, nên không phải leo thang đặc quyền: người dùng vốn đã đọc/ghi được các
  file đó. **Ràng buộc cần giữ:** đừng bao giờ đem engine ra sau socket/mạng hay chạy với quyền
  cao hơn mà không thêm kiểm tra đường dẫn trước.
- **Link trong PDF mở theo mặc định hệ thống.** App không đặt `PDFViewDelegate`, nên `PDFView`
  tự xử lý link annotation. Cần người dùng bấm, và giống hệt Preview/Acrobat. Nhưng với sản
  phẩm quảng cáo "never uploads your PDFs", một link độc nhất theo từng tài liệu vẫn là pixel
  theo dõi ngay khi bị bấm. Đổi hành vi này là quyết định UX, không tự làm.
- **`/opt/homebrew/bin/<tool>` là fallback khi chạy từ source.** Trên máy một người dùng, thư
  mục đó ghi được, nên một binary bị thay có thể nhận được đường dẫn file mật khẩu. Bản release
  bắt buộc dùng runtime đóng gói (script release từ chối build nếu thiếu), nên chỉ ảnh hưởng
  chế độ dev.

## Tái lập

```bash
# Sinh fixture (mutool 1.28.0, seed cố định)
python3 - <<'PY'
import subprocess, random, pathlib
random.seed(42)
words = ("hợp đồng điều khoản thanh toán bên giao nhận trách nhiệm bảo mật dữ liệu "
         "invoice payment terms liability warranty confidential schedule appendix").split()
def page(n):
    body = "\n".join(" ".join(random.choice(words) for _ in range(12)) for _ in range(38))
    return f"<h2>Trang {n}</h2><p>{body}</p>"
for pages, name in ((200,'medium-200p.pdf'), (1000,'large-1000p.pdf'), (3000,'huge-3000p.pdf')):
    html = "<html><body>" + "".join(page(i) + '<div style="page-break-after:always"></div>'
                                    for i in range(1, pages+1)) + "</body></html>"
    pathlib.Path('t.html').write_text(html, encoding='utf-8')
    subprocess.run(['mutool','convert','-o',name,'t.html'], check=True, capture_output=True)
PY
```

Harness đo dùng đúng các lời gọi mà app dùng: `PDFDocument(url:)`,
`page.thumbnail(of: CGSize(width: 34, height: 44), for: .mediaBox)` (khớp `SidebarView.swift:121`),
và `document.findString(_:withOptions:)` (khớp `PDFReaderView.swift:76`).
