# Đóng góp cho AZpdf

Cảm ơn bạn đã giúp AZpdf tốt hơn.

- Báo lỗi kèm phiên bản macOS, bản AZpdf và các bước tái hiện tối thiểu.
- Tạo issue trước với tính năng lớn để thống nhất hướng thiết kế.
- Giữ giao diện native macOS, hỗ trợ bàn phím và VoiceOver.
- Chạy `swift test`, `./script/audit_local_first.sh` và `./script/audit_portable_core.sh` trước khi gửi pull request.
- Không đưa binary Homebrew, Python virtualenv, certificate/private key hay notarization secret vào repository. Runtime phát hành phải qua `script/audit_runtime.sh`.
- Mọi đóng góp được phát hành theo AGPL-3.0-only.
