# MuPDF prototype benchmark — Ubuntu — 2026-07-18

## Môi trường

- Workstation: Ubuntu 24.04, Linux x86_64, 32 CPU, 61 GiB RAM
- Toolchain: Swift 6.3.3 container chính thức
- Runtime: `mutool version 1.28.0`, biên dịch từ source chính thức với 32 jobs
- Render: PNG, 144 dpi
- Fixtures: sinh xác định bởi `script/generate_pdf_fixtures.sh`

## Tính toàn vẹn runtime

- Source archive SHA-256: `21c7f064903154f1c3a7458bee81f130fc36f9b5147ea13328f9980e02d2dea2`
- `mutool` SHA-256: `66318ee40af84702a3dc0d8c86dfb519563c417f5024ce711fde18537fc68a42`
- ELF audit: đạt; chỉ phụ thuộc `libm`, `libc` và dynamic loader của Ubuntu.

## Kết quả

| Fixture | Pages | Input bytes | Render seconds | Peak RSS bytes |
| --- | ---: | ---: | ---: | ---: |
| basic | 1 | 866 | 0.020 | 19,357,696 |
| rotated | 1 | 841 | 0.030 | 19,279,872 |
| two-column | 1 | 833 | 0.020 | 19,374,080 |

- Full Linux suite: **14/14 test đạt**, gồm integration test với MuPDF thật và timeout/termination của subprocess.
- Production build: **đạt** bằng `swift build -c release`.
- Structured text và PNG của cả ba fixture được tạo thành công.

## Phạm vi còn thiếu

Đây là kiểm thử `AZpdfCore` và `AZpdfMuPDF`; Linux shell GUI chưa được triển khai. Trước khi phát hành cần thêm PDF thực tế/malformed/encrypted, form/annotation/font phức tạp, pixel diff, round-trip fidelity, accessibility với Orca và kiểm thử installer.
