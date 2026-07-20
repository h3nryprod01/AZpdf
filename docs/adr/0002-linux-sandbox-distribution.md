# ADR 0002: Flatpak là hướng sandbox phân phối Linux ưu tiên

- **Trạng thái:** Accepted cho development packaging — public reproducible build còn chờ
- **Ngày:** 2026-07-19

## Bối cảnh

AZpdf là ứng dụng local-first nhưng OCR/layout provider vẫn xử lý dữ liệu PDF không tin cậy. Ubuntu 24.04 trên workstation bật `kernel.apparmor_restrict_unprivileged_userns=1`; Bubblewrap 0.9.0 tồn tại nhưng không tạo được namespace nếu executable chưa có AppArmor policy phù hợp. Không được xử lý bằng cách tắt hạn chế toàn hệ thống, chạy provider không sandbox hoặc dùng setuid.

## Quyết định

Dùng Flatpak làm kênh phân phối Linux sandbox ưu tiên, với các bất biến:

1. Shell chỉ nhận file người dùng qua portal, không cấp `home` hoặc `host` filesystem mặc định.
2. Không cấp network cho app/OCR provider.
3. Provider và model được đóng gói, kiểm kê license/SBOM và nằm dưới `/app`.
4. Provider nâng cao chạy qua `flatpak-spawn --sandbox --no-network --clear-env --watch-bus`; cấm `--host`.
5. Input và request được stage bằng tên ngẫu nhiên trong instance `sandbox`, expose read-only; chỉ một output directory riêng được expose read-write.
6. Portal/subsandbox không sẵn sàng phải trả `sandboxUnavailable`; không fallback unsandboxed.

Gói `.deb` hoặc tarball có thể phát hành sau, nhưng Bubblewrap worker chỉ được bật khi gói cài AppArmor profile theo fixed executable path và profile đó qua review/test trên từng Ubuntu target.

## Cổng chấp nhận

- Build manifest reproducible từ source và dependency đã khóa phiên bản.
- Chạy `flatpak-spawn` E2E trên Ubuntu thật: capability, input read-only, output-only write, network denied, host file denied, cleanup sau success/failure.
- Portal Open/Save As hoạt động trên KDE và GNOME.
- Bundle, SBOM, license notice, checksum/signature và update flow được kiểm thử.
- Không có `--filesystem=host`, `--filesystem=home`, `--share=network` hoặc `flatpak-spawn --host` trong manifest/source.

## Trạng thái xác minh

- Runner Flatpak qua 5/5 unit tests trên x86_64 Linux.
- Probe `flatpak-spawn` E2E trên Ubuntu 24.04 đạt: input/request read-only, network và host file bị chặn, chỉ output tồn tại bền vững sau khi child kết thúc.
- Development manifest Freedesktop 25.08 đã build/install ở user scope; permissions không có network, host/home filesystem hoặc `org.freedesktop.Flatpak` talk.
- MuPDF, OCRmyPDF và pyHanko health checks đạt bên trong app sandbox.
- GTK file portal trong Xvfb biệt lập đã mở và render PDF fixture thật; screenshot OCR xác nhận nội dung, không chỉ kiểm tra process còn sống.
- Portal KDE/Save As trên desktop thật và manifest build reproducible hoàn toàn từ source vẫn là release gate. Development manifest hiện stage prebuilt bundle, vì vậy chưa đủ điều kiện gửi Flathub.

## Nguồn

- [Flatpak sandbox permissions](https://docs.flatpak.org/en/latest/sandbox-permissions.html)
- [Flatpak command reference: flatpak-spawn](https://docs.flatpak.org/en/latest/flatpak-command-reference.html)
- [Ubuntu AppArmor privilege restriction](https://documentation.ubuntu.com/security/security-features/privilege-restriction/apparmor/)
- [Ubuntu 24.04 release notes](https://documentation.ubuntu.com/release-notes/24.04/)
