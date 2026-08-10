# Sinh Shell/azpdf_desktop/windows/runner/resources/app_icon.ico từ Assets/AZpdf-icon.png.
#
# Vì sao cần script chứ không phải "kéo file vào": app_icon.ico trong repo là icon MẶC ĐỊNH
# của template Flutter (10 entry, đúng SHA c098d3fc…) — chưa ai thay từ lúc `flutter create`.
# Nên cửa sổ, taskbar và Alt-Tab trên Windows đều hiện logo Flutter chứ không hiện logo AZpdf.
#
# Hai điểm khó, cả hai đều đo trên chính file nguồn chứ không phỏng đoán:
#
#   1. Assets/AZpdf-icon.png là Format24bppRgb — KHÔNG có alpha. Nền là trắng đặc (253,253,253).
#      Đóng thẳng vào .ico thì icon thành một ô vuông trắng trên taskbar tối của Windows 11.
#      Nên phải tự dựng alpha: flood fill từ biên để đánh dấu nền, phần còn lại giữ đục.
#      Flood fill (không phải "mọi pixel sáng") là bắt buộc — tờ giấy TRẮNG bên trong icon
#      cũng sáng như nền; chỉ có tính liên thông mới phân biệt được hai vùng đó.
#
#   2. Hình là squircle macOS chạm mép canvas ở giữa bốn cạnh, không phải rounded-rect cung
#      tròn: đo bán kính từ hàng trên cùng ra ~446, đo từ đường chéo ra ~393. Hai số vênh nhau
#      nên MỌI mặt nạ hình học dựng sẵn đều sai viền. Vì vậy mặt nạ lấy từ chính ảnh.
#
#   3. Sau khi đặt alpha=0, RGB của vùng nền VẪN là trắng. Thu nhỏ 1254→16 bằng bicubic sẽ trộn
#      cái trắng đó vào viền và để lại quầng sáng. Nên trước khi thu nhỏ phải "loang" màu của
#      hình ra ngoài vùng trong suốt (BleedIterations) — alpha vẫn 0, chỉ RGB đổi.
#
# Chạy (Windows, cần System.Drawing của .NET Framework):
#   powershell -ExecutionPolicy Bypass -File script\make_windows_icon.ps1
[CmdletBinding()]
param(
    [string]$Source,
    [string]$Output,
    # Pixel nền: sáng hơn ngưỡng này VÀ liên thông tới biên canvas. 242 nằm giữa nền (253)
    # và pixel viền khử răng cưa sẫm nhất — nới rộng hơn sẽ ăn vào viền.
    [int]$BackgroundThreshold = 242,
    [int]$BleedIterations = 12,
    # ≤64 px ghi dạng BMP/DIB cho tương thích rộng nhất; 128 và 256 ghi dạng PNG để .ico
    # không phồng lên (128 BMP một mình đã 65 KB).
    [int[]]$Sizes = @(16, 24, 32, 48, 64, 128, 256)
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
if (-not $Source) { $Source = Join-Path $repo 'Assets\AZpdf-icon.png' }
if (-not $Output) { $Output = Join-Path $repo 'Shell\azpdf_desktop\windows\runner\resources\app_icon.ico' }
if (-not (Test-Path $Source)) { throw "Khong tim thay anh nguon: $Source" }

Add-Type -AssemblyName System.Drawing
Add-Type -ReferencedAssemblies System.Drawing -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Drawing.Imaging;
using System.IO;
using System.Runtime.InteropServices;

public static class AZpdfIcon {
    // Tách nền bằng flood fill từ biên, rồi loang màu hình ra ngoài để lúc thu nhỏ
    // không sinh quầng trắng ở viền.
    public static Bitmap CutBackground(string path, int threshold, int bleed) {
        Bitmap src = new Bitmap(path);
        int w = src.Width, h = src.Height;
        Bitmap argb = new Bitmap(w, h, PixelFormat.Format32bppArgb);
        using (Graphics g = Graphics.FromImage(argb)) {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.DrawImage(src, new Rectangle(0, 0, w, h), 0, 0, w, h, GraphicsUnit.Pixel);
        }
        src.Dispose();

        BitmapData d = argb.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadWrite, PixelFormat.Format32bppArgb);
        int stride = d.Stride;
        byte[] buf = new byte[stride * h];
        Marshal.Copy(d.Scan0, buf, 0, buf.Length);

        bool[] bg = new bool[w * h];
        Stack<int> stack = new Stack<int>();
        for (int x = 0; x < w; x++) { Seed(buf, stride, bg, stack, w, h, x, 0, threshold); Seed(buf, stride, bg, stack, w, h, x, h - 1, threshold); }
        for (int y = 0; y < h; y++) { Seed(buf, stride, bg, stack, w, h, 0, y, threshold); Seed(buf, stride, bg, stack, w, h, w - 1, y, threshold); }
        while (stack.Count > 0) {
            int p = stack.Pop(); int x = p % w, y = p / w;
            if (x > 0)     Seed(buf, stride, bg, stack, w, h, x - 1, y, threshold);
            if (x < w - 1) Seed(buf, stride, bg, stack, w, h, x + 1, y, threshold);
            if (y > 0)     Seed(buf, stride, bg, stack, w, h, x, y - 1, threshold);
            if (y < h - 1) Seed(buf, stride, bg, stack, w, h, x, y + 1, threshold);
        }

        for (int y = 0; y < h; y++)
            for (int x = 0; x < w; x++)
                buf[y * stride + x * 4 + 3] = bg[y * w + x] ? (byte)0 : (byte)255;

        // Loang màu: pixel trong suốt mượn màu của hàng xóm đã có màu. Alpha giữ nguyên 0.
        bool[] hasColor = new bool[w * h];
        for (int i = 0; i < bg.Length; i++) hasColor[i] = !bg[i];
        for (int pass = 0; pass < bleed; pass++) {
            bool[] next = (bool[])hasColor.Clone();
            for (int y = 0; y < h; y++)
                for (int x = 0; x < w; x++) {
                    int i = y * w + x;
                    if (hasColor[i]) continue;
                    int sx = -1, sy = -1;
                    if (x > 0 && hasColor[i - 1])         { sx = x - 1; sy = y; }
                    else if (x < w - 1 && hasColor[i + 1]) { sx = x + 1; sy = y; }
                    else if (y > 0 && hasColor[i - w])     { sx = x; sy = y - 1; }
                    else if (y < h - 1 && hasColor[i + w]) { sx = x; sy = y + 1; }
                    if (sx < 0) continue;
                    int dst = y * stride + x * 4, s = sy * stride + sx * 4;
                    buf[dst] = buf[s]; buf[dst + 1] = buf[s + 1]; buf[dst + 2] = buf[s + 2];
                    next[i] = true;
                }
            hasColor = next;
        }

        Marshal.Copy(buf, 0, d.Scan0, buf.Length);
        argb.UnlockBits(d);
        return argb;
    }

    static void Seed(byte[] buf, int stride, bool[] bg, Stack<int> stack, int w, int h, int x, int y, int threshold) {
        int i = y * w + x;
        if (bg[i]) return;
        int o = y * stride + x * 4;
        if (buf[o] < threshold || buf[o + 1] < threshold || buf[o + 2] < threshold) return;
        bg[i] = true;
        stack.Push(i);
    }

    public static Bitmap Resize(Bitmap src, int size) {
        Bitmap dst = new Bitmap(size, size, PixelFormat.Format32bppArgb);
        dst.SetResolution(96, 96);
        using (Graphics g = Graphics.FromImage(dst)) {
            g.CompositingMode = CompositingMode.SourceCopy;
            g.CompositingQuality = CompositingQuality.HighQuality;
            g.InterpolationMode = InterpolationMode.HighQualityBicubic;
            g.SmoothingMode = SmoothingMode.HighQuality;
            g.PixelOffsetMode = PixelOffsetMode.HighQuality;
            using (ImageAttributes ia = new ImageAttributes()) {
                ia.SetWrapMode(WrapMode.TileFlipXY); // chặn viền bị tối do lấy mẫu ngoài mép
                g.DrawImage(src, new Rectangle(0, 0, size, size), 0, 0, src.Width, src.Height, GraphicsUnit.Pixel, ia);
            }
        }
        return dst;
    }

    static byte[] ToPng(Bitmap bm) {
        using (MemoryStream ms = new MemoryStream()) { bm.Save(ms, ImageFormat.Png); return ms.ToArray(); }
    }

    // BITMAPINFOHEADER + XOR bitmap (BGRA, bottom-up) + AND mask 1bpp. biHeight gấp đôi là
    // đúng đặc tả ICO, không phải nhầm: nó tính cả mask.
    static byte[] ToDib(Bitmap bm) {
        int w = bm.Width, h = bm.Height;
        int maskStride = ((w + 31) / 32) * 4;
        byte[] xor = new byte[w * h * 4];
        byte[] and = new byte[maskStride * h];
        BitmapData d = bm.LockBits(new Rectangle(0, 0, w, h), ImageLockMode.ReadOnly, PixelFormat.Format32bppArgb);
        byte[] px = new byte[d.Stride * h];
        Marshal.Copy(d.Scan0, px, 0, px.Length);
        bm.UnlockBits(d);
        for (int y = 0; y < h; y++) {
            int srcRow = y * d.Stride;
            int dstRow = (h - 1 - y) * w * 4;
            int maskRow = (h - 1 - y) * maskStride;
            for (int x = 0; x < w; x++) {
                int s = srcRow + x * 4, t = dstRow + x * 4;
                xor[t] = px[s]; xor[t + 1] = px[s + 1]; xor[t + 2] = px[s + 2]; xor[t + 3] = px[s + 3];
                if (px[s + 3] < 128) and[maskRow + (x >> 3)] |= (byte)(0x80 >> (x & 7));
            }
        }
        using (MemoryStream ms = new MemoryStream())
        using (BinaryWriter bw = new BinaryWriter(ms)) {
            bw.Write(40); bw.Write(w); bw.Write(h * 2);
            bw.Write((short)1); bw.Write((short)32);
            bw.Write(0); bw.Write(xor.Length + and.Length);
            bw.Write(0); bw.Write(0); bw.Write(0); bw.Write(0);
            bw.Write(xor); bw.Write(and);
            return ms.ToArray();
        }
    }

    public static string Write(string sourcePath, string outPath, int threshold, int bleed, int[] sizes, int pngFrom) {
        string report = "";
        List<byte[]> blobs = new List<byte[]>();
        using (Bitmap master = CutBackground(sourcePath, threshold, bleed)) {
            foreach (int size in sizes)
                using (Bitmap frame = Resize(master, size)) {
                    byte[] blob = size >= pngFrom ? ToPng(frame) : ToDib(frame);
                    blobs.Add(blob);
                    report += string.Format("  {0,3}x{1,-3} {2,-4} {3,7} bytes\n", size, size, size >= pngFrom ? "PNG" : "BMP", blob.Length);
                }
        }
        using (FileStream fs = new FileStream(outPath, FileMode.Create, FileAccess.Write))
        using (BinaryWriter bw = new BinaryWriter(fs)) {
            bw.Write((short)0); bw.Write((short)1); bw.Write((short)sizes.Length);
            int offset = 6 + 16 * sizes.Length;
            for (int i = 0; i < sizes.Length; i++) {
                int size = sizes[i];
                bw.Write(size >= 256 ? (byte)0 : (byte)size);
                bw.Write(size >= 256 ? (byte)0 : (byte)size);
                bw.Write((byte)0); bw.Write((byte)0);
                bw.Write((short)1); bw.Write((short)32);
                bw.Write(blobs[i].Length); bw.Write(offset);
                offset += blobs[i].Length;
            }
            foreach (byte[] b in blobs) bw.Write(b);
        }
        return report;
    }
}
'@

$outDir = Split-Path -Parent $Output
if (-not (Test-Path $outDir)) { New-Item -ItemType Directory -Force -Path $outDir | Out-Null }

Write-Host "nguon : $Source"
Write-Host "dich  : $Output"
$report = [AZpdfIcon]::Write($Source, $Output, $BackgroundThreshold, $BleedIterations, $Sizes, 128)
Write-Host $report -NoNewline
$len = (Get-Item $Output).Length
Write-Host ("tong  : {0:N0} bytes, {1} entry" -f $len, $Sizes.Length)
