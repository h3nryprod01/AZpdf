# Plan — Gói A: làm AZpdf nhìn thấy được và cài được (không đụng code app)

## Goal
Sau build này, một người lạ tìm thấy AZpdf trên GitHub sẽ: đọc được description + topics,
thấy ngay ảnh chụp app thật trong README, tải được `v1.1.0` notarized (có đủ 43 commit mới:
in ⌘P, i18n en/vi, chèn hình, edit trực tiếp, Settings), hoặc cài bằng
`brew install --cask h3nryprod01/azpdf/azpdf`, và có 8 issue `good first issue` để bắt tay vào.
Không một dòng code app nào thay đổi — chỉ build script (version bump), docs, metadata, packaging.

## Context discovered

### Trạng thái public (đo 2026-07-27)
- `gh api repos/h3nryprod01/AZpdf`: `description: null`, `topics: []`, `homepage: null`,
  `has_discussions: false`, `open_issues_count: 0`, `forks: 0`, stars 0. Issues đang bật.
- Label mặc định ĐÃ CÓ sẵn: `good first issue`, `help wanted`, `bug`, `enhancement`,
  `documentation` — không cần tạo label mới.
- `.github/` chỉ có `workflows/ci.yml`. Không có ISSUE_TEMPLATE, không có PR template.
- Tap `h3nryprod01/homebrew-azpdf` CHƯA tồn tại (`gh repo view` → not found).
- `gh` auth: account `h3nryprod01`, scopes `gist, read:org, repo, workflow` → đủ để
  edit repo, bật Discussions, tạo repo tap, tạo issues.

### BẪY LỚN NHẤT: "96 commit" là con số sai
- Tag `v1.0.0` KHÔNG phải ancestor của `main`. Nó nằm trên nhánh `codex/macos-v1-public`
  tại `f09b5ab "Clarify release and PAdES roadmap"`.
- Trên `main`, commit tương đương là `cae36f1` (cùng message, cùng ngày `2026-07-18 00:52:04`).
  **`git diff --stat v1.0.0 cae36f1` = RỖNG → hai cây file giống hệt nhau.** Nhánh public đã
  được rebase vào main nên 54 commit bị nhân đôi với SHA khác.
- Vì vậy: `git log v1.0.0..HEAD` = 97 commit (**đếm trùng 54**). Delta THẬT kể từ bản đã phát
  hành là **`git rev-list --count cae36f1..HEAD` = 43 commit**.
- Hệ quả bắt buộc: release notes lấy từ `cae36f1..HEAD`, và **không được dùng
  `gh release create --generate-notes`** (nó so với tag trước = v1.0.0 → ra rác chéo nhánh).
  Dùng `--notes-file`.

### Quy trình release thật (`script/package_release.sh` + `docs/MACOS_RELEASE.md`)
- Bắt buộc 5 biến env: `SIGNING_IDENTITY`, `MUTOOL_RUNTIME_DIR`, `VERAPDF_RUNTIME_DIR`,
  `PYHANKO_RUNTIME_DIR`, `OCRMY_PDF_RUNTIME_DIR`. `NOTARY_PROFILE` là tùy chọn nhưng
  không có nó thì KHÔNG notarize/staple.
- **Cert CÓ SẴN**: `security find-identity -v -p codesigning` →
  `"Developer ID Application: Phu Cuong Nguyen (49ZXQQ2SPX)"` (hash `C37116E2…`). Hợp lệ.
- **Keychain profile notarytool KHÔNG CÓ**: `xcrun notarytool history --keychain-profile AZpdf-notary`
  → `No Keychain password item found`. → **cần NGƯỜI** chạy `notarytool store-credentials`.
- **4 runtime dir không có trong worktree này** (`dist/runtime` không tồn tại) NHƯNG có sẵn,
  đã build, ở checkout anh em:
  `/Users/nguyenphucuong/Documents/Codex/2026-07-16/t-i/dist/runtime/{mutool,veraPDF,pyhanko,ocrmypdf}`
  (41M / 184M / 21M / 112M, mtime 2026-07-17 = chính bộ dùng cho v1.0.0). `mutool -v` → 1.28.0 chạy được.
  → **KHÔNG cần build lại runtime** (việc đó tốn hàng giờ, cần MuPDF source + JDK + PyInstaller).
- Repo này là **git worktree**: `.git` là file trỏ tới `t-i/.git/worktrees/azpdf-fix`. Push bình thường.

### Bẫy build (do commit sau v1.0.0 gây ra)
- `script/build_and_run.sh:26` → `SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-debug}"`.
  `package_release.sh` gọi `build_and_run.sh --bundle` mà KHÔNG set biến này →
  **release hiện tại sẽ đóng gói bản DEBUG**. Biến này được thêm ở `7675d07`, tức sau v1.0.0.
- Version hardcode ở đúng 2 chỗ: `script/build_and_run.sh:71`
  (`<key>CFBundleShortVersionString</key><string>1.0.0</string>`) và `script/generate_sbom.sh:32`
  (`PackageVersion: 1.0.0`). `Views/AboutView.swift:4` chỉ đọc từ Info.plist (fallback "1.0.0") — **đừng đụng**.
- Binary là **arm64-only** (`lipo -info` trên app, mutool, pyhanko đều `Non-fat … arm64`).
  `LSMinimumSystemVersion = 14.0` (Sonoma).

### Release v1.0.0 hiện có — format asset để bám theo
- Assets: `AZpdf-macOS.zip`, `AZpdf-macOS.spdx`. Body có dòng ``SHA-256 (AZpdf-macOS.zip):`` + hash trong backtick.
- Tên file KHÔNG có version, nhưng URL tải vẫn ổn định theo tag:
  `https://github.com/h3nryprod01/AZpdf/releases/download/v1.1.0/AZpdf-macOS.zip` → dùng được cho cask.
- Body v1.0.0 viết tiếng Việt. v1.1.0 phải en làm chính.

### Screenshot
- `qa-report/screenshots/*.jpeg` (3 ảnh, 2026-07-20) **KHÔNG dùng lại được**: UI tiếng Việt,
  và là toolbar CŨ 17 icon chen chúc — trước refactor `8b220a5` (edit bar kiểu Preview) và
  trước `849efae`/`995be77` (chèn hình, edit trực tiếp). Ảnh đó bán sai sản phẩm.
- README hiện chỉ có icon 254px trỏ tới CDN `user-attachments`. `Assets/donate-vietqr.jpg`
  đã dùng **đường dẫn tương đối** → có tiền lệ trong repo cho việc commit ảnh.
- Tiền lệ rò rỉ dữ liệu: commit `a713df9 "docs: replace machine hostname, home path and tailnet IP
  with placeholders"` — repo này TỪNG lộ path/hostname. Ảnh chụp phải soi kỹ.

### Governance docs hiện tại (100% tiếng Việt, rất mỏng)
- `CONTRIBUTING.md` 688 B / 8 dòng; `SECURITY.md` 245 B / 1 đoạn; `CODE_OF_CONDUCT.md` 439 B.
- Lệnh gate thật để đưa vào quickstart: `swift test`, `./script/audit_local_first.sh`,
  `./script/audit_portable_core.sh`, `./script/audit_i18n_strings.sh --self-test && ./script/audit_i18n_strings.sh`,
  `./script/build_and_run.sh` (yêu cầu macOS 14+, Xcode 26; máy này Xcode 26.6 / Swift 6.3.3),
  `brew install mupdf verapdf` khi chạy từ source.

### Entry point cho 8 good-first-issue (đã verify là chưa có)
| # | Issue | Entry point |
|---|---|---|
| 1 | Go to page N (ô nhập số trang) | `Stores/DocumentStore+Navigation.swift` chỉ có `goToPreviousPage/goToNextPage`; toolbar ở `Views/ContentView.swift` |
| 2 | Export trang hiện tại ra PNG/JPEG | mẫu: `Stores/DocumentStore+FileIO.swift:84 prepareCurrentPageExport()` (hiện chỉ ra PDF) |
| 3 | Nhớ vị trí đọc theo từng file | `Stores/DocumentStore.swift:119` + `:253` (đang lưu `recentDocumentPaths` qua UserDefaults, không lưu trang) |
| 4 | Extract khoảng trang → PDF mới | `Stores/DocumentStore+Pages.swift` + `DocumentStore+FileIO.swift:40 export(to:)` |
| 5 | Xoay ngược chiều kim đồng hồ | `Stores/DocumentStore+Pages.swift:9 rotateCurrentPage()` — hiện chỉ 1 chiều |
| 6 | Chế độ 2 trang (facing pages) | `Views/PDFReaderView.swift:13` — `displayMode` hardcode `.singlePageContinuous` |
| 7 | Ô nhập % zoom / preset zoom | `Stores/DocumentStore+Navigation.swift:28-42` (`zoomIn/zoomOut/fitPage`) |
| 8 | Bảng phím tắt trong Help | `Views/HelpView.swift` |
- Mọi issue phải kèm cảnh báo: chuỗi mới phải vào **cả** `Resources/en.lproj/Localizable.strings`
  và `Resources/vi.lproj/Localizable.strings`, nếu không gate `audit_i18n_strings.sh` sẽ chặn CI.

## Approach
Làm **tất cả phần local trước, gom mọi hành động public vào một lần bấm nút ở phase deploy**.
Thứ tự bị ép bởi dữ liệu thật: screenshot cần app đã build → README cần screenshot →
cask cần SHA-256 của ZIP đã notarize → ZIP cần notary profile do người tạo. Runtime tái dùng
từ `t-i/dist/runtime` thay vì build lại (tiết kiệm nhiều giờ, đúng bộ đã dùng cho v1.0.0).
Cask đặt ở tap riêng `h3nryprod01/homebrew-azpdf`, không nộp homebrew-cask chính thức.

## Alternatives considered
- **Nộp cask vào `Homebrew/homebrew-cask` luôn**: bị loại. Repo 0 star / 0 fork, notability sẽ
  không qua, và mỗi lần release phải chờ PR review. Tap riêng cho cùng trải nghiệm
  (`brew tap` + `brew install --cask`) và ta tự kiểm soát nhịp phát hành. Nộp chính thức để
  sau khi có traction.
- **Đặt cask ngay trong repo AZpdf (`Casks/azpdf.rb`)**: Homebrew tap PHẢI là repo tên
  `homebrew-<name>`; nhét vào repo app thì người dùng phải `brew tap h3nryprod01/AZpdf <url>`
  — dài dòng, sai quy ước, và trộn lẫn lịch sử app với lịch sử packaging. Loại.
- **Dùng lại 3 ảnh trong `qa-report/screenshots/`**: loại. UI tiếng Việt + toolbar đã bị refactor
  bỏ; đăng ảnh cũ tệ hơn không có ảnh vì nó bán sai sản phẩm.
- **Build lại 4 runtime từ source cho "sạch"**: loại. Vài giờ đến vài ngày, cần MuPDF source,
  JDK, pinned Python + PyInstaller, Tesseract/Ghostscript/qpdf. Bộ ở `t-i` là chính bộ đã
  ship v1.0.0 và `audit_runtime.sh` vẫn chạy lại trên chúng trong `package_release.sh`.

## Thứ tự & phụ thuộc

```
1. version bump + fix debug-build  ─┐
                                    ├─► 2. build bundle ──► 3. SCREENSHOT (orchestrator)
                                    │                            │
                                    │                            ▼
                                    │                       4. README en+vi
                                    │
                                    ├─► 5. governance docs EN + .vi (song song với 4)
                                    ├─► 6. issue/PR templates (song song)
                                    └─► 7. release notes draft (cae36f1..HEAD)
                                             │
   ┌── NGƯỜI: notarytool store-credentials ──┤   (chặn 8; làm sớm được ngay từ đầu)
   │                                          ▼
   └────────────────────────────────► 8. package_release.sh → ZIP notarized + SHA-256
                                             │
                                             ▼
                                        9. cask .rb (CẦN sha256 của bước 8)
                                             │
                                             ▼
                                    10. DEPLOY — mọi hành động public, một lần
```

Ràng buộc cứng:
- Screenshot **trước** khi sửa README (bước 3 → 4).
- Tag `v1.1.0` đặt ở HEAD **sau** khi mọi commit local (1,4,5,6) đã xong, nhưng bản build ở
  bước 8 phải sinh ra từ cùng cây đó → chạy bước 8 SAU khi commit xong, TRƯỚC khi tag.
- Cask **sau** release (bước 8/10) vì cần URL + SHA-256 của asset thật.
- Bật Discussions **trước** khi verify link trong `.github/ISSUE_TEMPLATE/config.yml`
  (link `/discussions` chỉ sống sau khi bật) — nhưng cả hai đều nằm trong bước 10 nên chỉ
  cần đúng thứ tự trong bước đó.

## Các bước

- [x] **1. Chuẩn bị version + chặn bản debug lọt vào release** (local)
      Sửa `script/build_and_run.sh:71` `1.0.0` → `1.1.0`; `script/generate_sbom.sh:32`
      `PackageVersion: 1.0.0` → `1.1.0`. Thêm 1 dòng vào `script/package_release.sh` ngay sau
      block kiểm env: `export SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-release}"` — vì
      `build_and_run.sh` mặc định `debug` và release tuyệt đối không được là debug.
      **KHÔNG đụng** `Views/AboutView.swift` (chỉ là fallback), không đụng `Tests/`.
      → verify: `grep -rn "1\.1\.0" script/build_and_run.sh script/generate_sbom.sh` ra 2 dòng;
      `bash -n script/package_release.sh script/build_and_run.sh script/generate_sbom.sh`;
      `swift test` xanh + 3 gate (`audit_local_first.sh`, `audit_portable_core.sh`,
      `audit_i18n_strings.sh --self-test && audit_i18n_strings.sh`) xanh.

- [x] **2. Build bundle không ký để chụp ảnh** (local, coder)
      `cd <repo> && SWIFT_CONFIGURATION=release OCRMY_PDF_RUNTIME_DIR=/Users/nguyenphucuong/Documents/Codex/2026-07-16/t-i/dist/runtime/ocrmypdf MUTOOL_RUNTIME_DIR=/Users/nguyenphucuong/Documents/Codex/2026-07-16/t-i/dist/runtime/mutool ./script/build_and_run.sh --bundle`
      → verify: `/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/AZpdf.app/Contents/Info.plist`
      in ra `1.1.0`; `dist/AZpdf.app/Contents/Resources/Helpers/mutool` tồn tại và executable.

- [ ] **3. Chụp screenshot app thật — ORCHESTRATOR (computer-use), không phải coder**
      Mở `dist/AZpdf.app`, đặt ngôn ngữ **English** trong Settings, mở một PDF trung tính
      (KHÔNG dùng file cá nhân — tạo fixture bằng `./script/generate_pdf_fixtures.sh` hoặc dùng
      PDF công khai), thêm sẵn 1 highlight + 1 text box + 1 hình để edit bar và popover cùng lộ ra,
      mở sidebar thumbnails + Inspector. Cửa sổ ~1440×900, chụp cả cửa sổ có bo góc.
      Lưu 1 ảnh hero (bắt buộc) `Assets/screenshots/azpdf-macos-hero.png`, tối đa 1 ảnh phụ.
      **Soi trước khi lưu**: không có `/Users/nguyenphucuong`, không tên máy, không tài liệu
      riêng tư, không menu bar cá nhân (repo này từng phải vá rò rỉ ở `a713df9`).
      → verify: file ≤ 600 KB mỗi ảnh (`du -k`), `sips -g pixelWidth -g pixelHeight` ≥ 1400px ngang,
      và mở ảnh đọc lại xác nhận toolbar là bản edit-bar mới + chữ tiếng Anh.

- [ ] **4. Nhúng screenshot vào README.md và README.vi.md** (local, coder)
      Chèn ngay dưới đoạn mô tả mở đầu, TRÊN mục feature list, thay chỗ hiện icon 254px đang
      đứng một mình. Dùng đường dẫn tương đối như `Assets/donate-vietqr.jpg` đang làm:
      `<img src="Assets/screenshots/azpdf-macos-hero.png" alt="AZpdf editing a PDF on macOS" width="900" />`.
      Alt text tiếng Anh ở `README.md`, tiếng Việt ở `README.vi.md`. Giữ icon (thu nhỏ hoặc để nguyên) — tùy, đừng bịa thêm section.
      → verify: `grep -c "Assets/screenshots" README.md README.vi.md` = 1 mỗi file; ảnh tồn tại đúng path.

- [x] **5. Governance docs sang English, giữ bản Việt** (local, coder)
      Theo đúng mô hình README vừa làm: `CONTRIBUTING.md` (EN) + `CONTRIBUTING.vi.md`,
      `SECURITY.md` (EN) + `SECURITY.vi.md`, `CODE_OF_CONDUCT.md` (EN) + `CODE_OF_CONDUCT.vi.md`.
      Mỗi file có dòng chuyển ngữ đầu trang `**English** | [Tiếng Việt](X.vi.md)`.
      Nội dung Việt hiện tại chuyển nguyên vào bản `.vi.md` (không viết lại).
      `CONTRIBUTING.md` thêm **Dev quickstart thật**: yêu cầu macOS 14+ / Xcode 26;
      `brew install mupdf verapdf`; `./script/build_and_run.sh`; và 4 lệnh gate phải xanh
      trước khi gửi PR (`swift test`, `audit_local_first.sh`, `audit_portable_core.sh`,
      `audit_i18n_strings.sh`); nhắc chuỗi UI mới phải có cả en + vi `.lproj`;
      giữ nguyên 2 điều lệ cũ (không commit binary/cert/secret; đóng góp theo AGPL-3.0-only).
      `SECURITY.md` nêu rõ kênh: GitHub Security Advisories (private report) — không mở issue công khai.
      → verify: 6 file tồn tại; `grep -l "Tiếng Việt" CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md` ra đủ 3;
      mọi lệnh trích trong CONTRIBUTING đều tồn tại trong `script/`.

- [x] **6. Issue templates + PR template** (local, coder)
      `.github/ISSUE_TEMPLATE/bug_report.yml` (macOS version, AZpdf version, các bước tái hiện,
      file PDF gây lỗi nếu chia sẻ được), `.github/ISSUE_TEMPLATE/feature_request.yml`,
      `.github/ISSUE_TEMPLATE/config.yml` với `blank_issues_enabled: false` và contact link trỏ
      `https://github.com/h3nryprod01/AZpdf/discussions`. `.github/pull_request_template.md` ngắn:
      mô tả, issue liên quan, checklist 4 gate + i18n keys.
      Tiếng Anh. Ngắn — mỗi form ≤ 5 field.
      → verify: `python3 -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/ISSUE_TEMPLATE/*.yml` không lỗi.

- [x] **7. Soạn release notes v1.1.0 song ngữ** (local, coder) → `<state-dir>/release-notes-v1.1.0.md`
      Nguồn **`git log --oneline cae36f1..HEAD`** (43 commit) — **KHÔNG dùng `v1.0.0..HEAD`**.
      Nhóm theo chủ đề, EN trước, VI sau trong cùng file:
      Printing (⌘P) · Bilingual UI en/vi + language picker in Settings · Insert shapes (6 loại) ·
      Direct-manipulation annotation editing (frame/handles/popover) · Text formatting for text boxes ·
      Preview-style edit bar + toolbar cleanup · Settings redesign · Accessibility fixes ·
      Fixes (Escape đóng sheet, drag reorder thumbnail, native pickers, signature ink mapping,
      search/zoom/Finder-opened files) · Cross-platform groundwork (Linux alpha, DocumentIR, MuPDF adapter).
      Cuối file chừa placeholder `SHA-256 (AZpdf-macOS.zip): <điền ở bước 8>` và ghi rõ
      **Apple silicon (arm64), macOS 14+**. Thêm 1 dòng chú: v1.0.0 được tag trên nhánh public
      cũ nên link compare tự động của GitHub không dùng được.
      → verify: mọi mục trong notes truy ngược được về ít nhất 1 commit trong `cae36f1..HEAD`;
      không mục nào nói về tính năng đã có ở v1.0.0.

- [ ] **8. Build + ký + notarize v1.1.0** (local nhưng chạy lâu; CẦN NGƯỜI trước khi bắt đầu)
      Điều kiện tiên quyết do **NGƯỜI** làm một lần:
      `xcrun notarytool store-credentials AZpdf-notary --apple-id <apple-id> --team-id 49ZXQQ2SPX --password <app-specific-password>`
      (hoặc `--key/--key-id/--issuer` nếu dùng App Store Connect API key).
      Sau đó, từ repo:
      ```
      export SIGNING_IDENTITY='Developer ID Application: Phu Cuong Nguyen (49ZXQQ2SPX)'
      export NOTARY_PROFILE='AZpdf-notary'
      R=/Users/nguyenphucuong/Documents/Codex/2026-07-16/t-i/dist/runtime
      export MUTOOL_RUNTIME_DIR="$R/mutool" VERAPDF_RUNTIME_DIR="$R/veraPDF" \
             PYHANKO_RUNTIME_DIR="$R/pyhanko" OCRMY_PDF_RUNTIME_DIR="$R/ocrmypdf"
      ./script/package_release.sh
      ```
      Nếu notarize `Accepted` mà phiên bị đứt trước staple: `./script/staple_release_zip.sh dist/release/AZpdf-macOS.zip`
      (đừng `unzip` thủ công — sinh `._*` phá resource seal).
      → verify: `./script/verify_release.sh dist/release/../AZpdf.app` hoặc trên bản staged —
      bắt buộc thấy `Authority=Developer ID Application`, `spctl -a -vv` → `accepted / Notarized Developer ID`,
      `xcrun stapler validate` OK; `shasum -a 256 dist/release/AZpdf-macOS.zip` → điền vào notes bước 7;
      `dist/release/AZpdf-macOS.spdx` có `PackageVersion: 1.1.0`;
      `lipo -info` binary trong ZIP = arm64.

- [ ] **9. Soạn cask (local)** → `<state-dir>/tap/Casks/azpdf.rb`
      Token `azpdf`, tap sẽ là repo `h3nryprod01/homebrew-azpdf`. Nội dung tối thiểu đúng chuẩn:
      ```ruby
      cask "azpdf" do
        version "1.1.0"
        sha256 "<sha256 từ bước 8>"

        url "https://github.com/h3nryprod01/AZpdf/releases/download/v#{version}/AZpdf-macOS.zip"
        name "AZpdf"
        desc "Local-first PDF reader and editor"
        homepage "https://github.com/h3nryprod01/AZpdf"

        depends_on arch: :arm64
        depends_on macos: ">= :sonoma"

        app "AZpdf.app"

        zap trash: [
          "~/Library/Preferences/org.azpdf.mac.plist",
          "~/Library/Application Support/AZpdf",
          "~/Library/Saved Application State/org.azpdf.mac.savedState",
        ]
      end
      ```
      `depends_on arch: :arm64` là bắt buộc — binary arm64-only, cài trên Intel sẽ hỏng câm.
      Kèm `README.md` 5 dòng cho tap (2 lệnh: `brew tap`, `brew install --cask`).
      → verify: `ruby -c` cú pháp OK; `sha256` khớp `shasum -a 256` của ZIP; các path trong `zap`
      khớp bundle id `org.azpdf.mac`.

- [ ] **10. DEPLOY — mọi HÀNH ĐỘNG PUBLIC, gom một lần** (phase deploy, người bấm nút)
      Thứ tự trong bước này:
      1. `git push origin main` (các commit của bước 1,4,5,6).
      2. `gh repo edit h3nryprod01/AZpdf --description "Open-source, local-first PDF reader and editor for macOS. Annotate, sign, OCR and validate PDF/A — nothing leaves your Mac."`
      3. `gh repo edit h3nryprod01/AZpdf --add-topic pdf --add-topic pdf-editor --add-topic macos --add-topic swift --add-topic swiftui --add-topic local-first --add-topic privacy --add-topic ocr --add-topic pdf-viewer --add-topic annotations`
      4. `gh repo edit h3nryprod01/AZpdf --enable-discussions`
         (homepage: **để trống** — chưa có site thật nào đáng trỏ; đừng trỏ vòng về chính repo.)
      5. `git tag -a v1.1.0 -m "AZpdf 1.1.0" && git push origin v1.1.0`
      6. `gh release create v1.1.0 dist/release/AZpdf-macOS.zip dist/release/AZpdf-macOS.spdx --title "AZpdf 1.1.0" --notes-file <state-dir>/release-notes-v1.1.0.md`
         (**không** `--generate-notes`).
      7. `gh repo create h3nryprod01/homebrew-azpdf --public --description "Homebrew tap for AZpdf"`
         rồi push `Casks/azpdf.rb` + README.
      8. Tạo 8 issue bằng `gh issue create --label "good first issue" --label enhancement`,
         **tuần tự, cách nhau vài giây** (repo mới dễ dính secondary rate limit).
      → verify: `gh repo view h3nryprod01/AZpdf --json description,repositoryTopics,hasDiscussionsEnabled`
      đủ 3 trường; `gh release view v1.1.0` liệt kê 2 asset; `gh issue list --label "good first issue"` = 8;
      **smoke test thật**: `brew tap h3nryprod01/azpdf && brew install --cask azpdf && open -a AZpdf`
      (Gatekeeper không cảnh báo), rồi `brew uninstall --cask azpdf` để dọn.

## Ai làm gì

| Bước | Ai | Ghi chú |
|---|---|---|
| 1, 2 | **coder** (headless) | Sửa build script, build bundle |
| 3 | **ORCHESTRATOR** (computer-use) | Coder không có computer-use. Mở app, đặt English, dựng cảnh, chụp, soi lộ dữ liệu, lưu file. Không ai khác làm được bước này. |
| 4, 5, 6, 7 | **coder** (headless) | Thuần sửa/thêm file, commit local, KHÔNG push |
| 8 (tiên quyết) | **NGƯỜI** | `notarytool store-credentials` — cần Apple ID + app-specific password. Không tự động hóa được, không được ghi vào repo/log. Nên làm ngay từ đầu build để không chặn cuối. |
| 8 (chạy) | **coder** | Build + ký + notarize, chờ Apple. Cert đã có sẵn trong Keychain nên codesign chạy không cần hỏi (nếu Keychain hỏi cho phép ký → **cần NGƯỜI** bấm Allow). |
| 9 | **coder** | Cần SHA từ bước 8 |
| 10 | **deployer + NGƯỜI duyệt** | Toàn bộ là public, một lần bấm |

Ranh giới: coder **không** `git push`, **không** `gh repo edit`, **không** `gh release create`,
**không** `gh issue create`, **không** tạo repo tap trong lúc code. Tất cả dồn vào bước 10.

## Rủi ro

- **Không có notary profile** → đây là điểm chặn cứng duy nhất. Nếu người không cấp được
  app-specific password kịp, `package_release.sh` vẫn tạo ZIP đã ký nhưng **không notarize/staple**
  → Gatekeeper chặn người tải về → cask vô dụng. Không được release ZIP chưa notarize.
  Phương án lùi: ship mọi thứ trừ bước 8/9, giữ release + cask cho lần bấm sau.
- **Notarize chờ lâu**: thường 5–15 phút, có thể tới hàng giờ khi Apple nghẽn. `--wait` sẽ treo
  terminal. Nếu đứt: dùng `staple_release_zip.sh`, đừng build lại từ đầu.
- **Runtime nằm NGOÀI repo** (`t-i/dist/runtime`, 358 MB tổng). Nếu checkout `t-i` bị xóa/di chuyển
  thì bước 8 chết và dựng lại rất đắt. Kiểm tra 4 đường dẫn tồn tại **trước** khi bắt đầu bước 8.
- **`codesign` báo `resource fork, Finder information, or similar detritus`** — bẫy đã ghi ở
  `docs/MACOS_RELEASE.md:96`. `package_release.sh` đã ditto sang `/private/tmp` để né;
  nếu vẫn dính, chuyển source sang workspace sạch, **không bỏ qua lỗi**.
- **Release notes sót/thừa**: `git log v1.0.0..HEAD` là bẫy (97 commit, trùng 54). Dùng
  `cae36f1..HEAD` = 43. Rủi ro ngược lại: nhét cả việc Linux/DocumentIR vào notes macOS làm
  người đọc tưởng Linux đã stable — phải ghi rõ "alpha".
- **Ảnh chụp lộ dữ liệu cá nhân** — repo đã từng phải vá (`a713df9`). Ảnh vào git là vĩnh viễn.
- **UI trong ảnh lệch bản phát hành**: build ở bước 2 phải là HEAD hiện tại (đã gồm `b5ba1aa`
  sửa nút Inspector bị cắt dưới tiếng Anh); `dist/AZpdf.app` cũ (16:20) là trước commit đó — phải build lại.
- **Cask trên máy Intel**: nếu quên `depends_on arch: :arm64`, người dùng Intel cài xong app không chạy.
- **Tap sai tên**: repo bắt buộc là `homebrew-azpdf`; đặt `azpdf-tap` hay `homebrew-cask-azpdf`
  thì `brew tap h3nryprod01/azpdf` không tìm thấy.
- **Bản release là DEBUG** nếu quên `SWIFT_CONFIGURATION=release` → chậm, to, không nên phát hành.
  Bước 1 đã đóng lỗ này ở `package_release.sh`.
- **Rate limit khi tạo 8 issue liên tiếp** trên repo mới → tạo tuần tự, có nghỉ.
- **`gh repo edit --enable-discussions`** cần quyền admin trên repo (chủ repo → ổn), nhưng token
  chỉ có scope `repo`; nếu API trả 403 thì bật tay trên web Settings → Features → Discussions.

## Đo bằng gì (Definition of Done)

| Mục | Xong khi |
|---|---|
| Metadata | `gh repo view --json description,repositoryTopics,hasDiscussionsEnabled` → description ≠ "", ≥ 8 topic, `hasDiscussionsEnabled: true` |
| Screenshot | `Assets/screenshots/azpdf-macos-hero.png` trong git, hiện đúng trên trang github.com của cả `README.md` và `README.vi.md`, UI tiếng Anh, edit bar mới, không lộ path/tên máy |
| Release | `gh release view v1.1.0` là Latest, có `AZpdf-macOS.zip` + `AZpdf-macOS.spdx`; tải ZIP về máy sạch → `spctl -a -vv` = `accepted, Notarized Developer ID`; SHA trong notes khớp `shasum -a 256` |
| Cask | `brew tap h3nryprod01/azpdf && brew install --cask azpdf` thành công trên máy sạch, `open -a AZpdf` không hiện cảnh báo Gatekeeper, `brew uninstall --cask azpdf` dọn sạch |
| Governance | 6 file (3 EN + 3 `.vi.md`) có cross-link 2 chiều; mọi lệnh trong CONTRIBUTING quickstart chạy thật được trên repo sạch |
| Templates | Mở "New issue" trên web → hiện 2 form + link Discussions, không có blank issue |
| Issues | `gh issue list --label "good first issue"` = 8; mỗi issue nêu ít nhất 1 file path có thật và nhắc cặp `.lproj` en/vi |
| Không đụng code app | `git diff cae36f1..HEAD --stat -- Views/ Stores/ Services/ Models/ Core/ App/ Adapters/` trong diff của **build này** = rỗng |

## UI surfaces
None — no UI in this task.

## Out of scope
- Bất kỳ thay đổi nào trong `Views/`, `Stores/`, `Services/`, `Models/`, `Core/`, `App/`,
  `Adapters/`, `Tests/`. Version bump chỉ ở `script/`.
- Không implement 8 good-first-issue — chỉ tạo issue.
- Không auto-update (Sparkle), không website/landing page, không GitHub Pages.
- Không nộp cask lên `Homebrew/homebrew-cask` chính thức (0 star → sẽ bị loại).
- Không tự động hóa release trong CI, không đụng `.github/workflows/ci.yml`.
- Không build universal binary (x86_64) — arm64-only, khai báo rõ trong cask + release notes.
- Không release Linux/Flatpak/Windows, không đụng `Shell/`, `Packaging/`.
- Không đo hiệu năng file lớn, không làm việc i18n/a11y (đã xong hoặc thuộc gói khác).
- Không đặt `homepage` cho repo cho tới khi có site thật.
