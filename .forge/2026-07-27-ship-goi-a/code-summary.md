# Code summary — Gói A (bước 1, 2, 5, 6, 7 + 1 đính chính docs)

## Files changed

- `script/build_and_run.sh` — `CFBundleShortVersionString` 1.0.0 → 1.1.0 (dòng 71).
- `script/generate_sbom.sh` — `PackageVersion` 1.0.0 → 1.1.0 (dòng 32).
- `script/package_release.sh` — thêm `export SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-release}"`
  ngay sau block kiểm env, để `build_and_run.sh` (mặc định `debug`) không lọt bản debug vào release.
- `CONTRIBUTING.md` — viết lại tiếng Anh, thêm mục "Dev quickstart" (macOS 14+/Xcode 26,
  `brew install mupdf verapdf`, 4 lệnh gate, nhắc chuỗi UI mới cần cả en+vi `.lproj`), giữ 2 điều
  lệ cũ (không commit binary/cert/secret; AGPL-3.0-only). Có dòng cross-link đầu trang.
- `CONTRIBUTING.vi.md` (mới) — nội dung tiếng Việt cũ của `CONTRIBUTING.md` chuyển nguyên văn, thêm
  dòng cross-link.
- `SECURITY.md` — viết lại tiếng Anh, nêu rõ kênh báo lỗ hổng: GitHub Security Advisories (link
  trực tiếp `.../security/advisories/new`), không mở issue công khai.
- `SECURITY.vi.md` (mới) — nội dung tiếng Việt cũ chuyển nguyên văn, thêm dòng cross-link.
- `CODE_OF_CONDUCT.md` — viết lại tiếng Anh theo đúng nghĩa bản gốc.
- `CODE_OF_CONDUCT.vi.md` (mới) — nội dung tiếng Việt cũ chuyển nguyên văn, thêm dòng cross-link.
- `.github/ISSUE_TEMPLATE/bug_report.yml` (mới) — 5 field: mô tả, bước tái hiện, macOS version,
  AZpdf version, PDF gây lỗi (tùy chọn). Label mặc định `bug`.
- `.github/ISSUE_TEMPLATE/feature_request.yml` (mới) — 3 field: vấn đề, đề xuất, phương án khác.
  Label mặc định `enhancement`.
- `.github/ISSUE_TEMPLATE/config.yml` (mới) — `blank_issues_enabled: false`, contact link trỏ
  `https://github.com/h3nryprod01/AZpdf/discussions`.
- `.github/pull_request_template.md` (mới) — mô tả, issue liên quan, checklist 4 gate + i18n keys.
- `docs/MACOS_RELEASE.md` — sửa 2 chỗ (dòng ~78, ~103) `AZpdf-notary` → `azpdf-notary` cho khớp
  tên profile notarytool thật đã tạo trong Keychain (đính chính theo yêu cầu orchestrator, không
  thuộc 5 bước gốc nhưng đã được chỉ định rõ ràng).
- `.forge/2026-07-27-ship-goi-a/release-notes-v1.1.0.md` (mới, ngoài repo git) — release notes
  song ngữ v1.1.0, nguồn `cae36f1..HEAD`.
- `.forge/2026-07-27-ship-goi-a/plan.md` — tick `[x]` cho bước 1, 2, 5, 6, 7.

## Steps completed

- [x] 1. Chuẩn bị version + chặn bản debug lọt vào release ✓
- [x] 2. Build bundle không ký để chụp ảnh ✓
- [ ] 3. (không làm — thuộc orchestrator/computer-use, theo chỉ định)
- [ ] 4. (không làm — phụ thuộc ảnh bước 3, theo chỉ định)
- [x] 5. Governance docs sang English, giữ bản Việt ✓
- [x] 6. Issue templates + PR template ✓
- [x] 7. Soạn release notes v1.1.0 song ngữ ✓
- [ ] 8, 9, 10. (không làm — theo chỉ định, cần người/deploy)

## Output verify thật (đã chạy, dán nguyên)

### Bước 1
```
$ grep -rn "1\.1\.0" script/build_and_run.sh script/generate_sbom.sh
script/generate_sbom.sh:32:PackageVersion: 1.1.0
script/build_and_run.sh:71:<key>CFBundleShortVersionString</key><string>1.1.0</string>

$ bash -n script/package_release.sh script/build_and_run.sh script/generate_sbom.sh
(không lỗi)

$ swift test
Test Suite 'All tests' passed at 2026-07-29 00:18:23.738.
	 Executed 183 tests, with 7 tests skipped and 0 failures (0 unexpected) in 5.233 (5.256) seconds

$ ./script/audit_local_first.sh
Local-first audit passed: no network client API found.
$ ./script/audit_portable_core.sh
Portable-core audit passed: Core remains Foundation-only.
$ ./script/audit_i18n_strings.sh --self-test && ./script/audit_i18n_strings.sh
i18n audit self-test passed.
i18n audit passed: no literal Vietnamese strings or unresolved L(_:) keys in swept files.
```

### Bước 2
Lệnh chạy đúng như plan ghi (`SWIFT_CONFIGURATION=release OCRMY_PDF_RUNTIME_DIR=.../ocrmypdf
MUTOOL_RUNTIME_DIR=.../mutool ./script/build_and_run.sh --bundle`) — build thành công
("Build complete! (28.96s)").
```
$ /usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" dist/AZpdf.app/Contents/Info.plist
1.1.0

$ ls -la dist/AZpdf.app/Contents/Resources/Helpers/mutool
-rwxr-xr-x@ 1 nguyenphucuong staff 42754312 Jul 17 14:53 dist/AZpdf.app/Contents/Resources/Helpers/mutool
(executable, test -x OK)
```
Ghi chú: `dist/` bị gitignore, không có gì để commit ở bước này. Bundle này **chưa ký, chưa
notarize** — chỉ dùng để chụp ảnh (bước 3, không thuộc gói này).

### Bước 5
```
$ ls CONTRIBUTING.md CONTRIBUTING.vi.md SECURITY.md SECURITY.vi.md CODE_OF_CONDUCT.md CODE_OF_CONDUCT.vi.md
(6 file, đều tồn tại)

$ grep -l "Tiếng Việt" CONTRIBUTING.md SECURITY.md CODE_OF_CONDUCT.md
CONTRIBUTING.md
SECURITY.md
CODE_OF_CONDUCT.md

$ for f in build_and_run.sh audit_local_first.sh audit_portable_core.sh audit_i18n_strings.sh audit_runtime.sh; do test -f "script/$f" && echo OK; done
OK (x5 — mọi lệnh trích trong CONTRIBUTING.md đều tồn tại trong script/)
```

### Bước 6
```
$ python3 -c "import yaml,sys;[yaml.safe_load(open(f)) for f in sys.argv[1:]]" .github/ISSUE_TEMPLATE/*.yml
YAML OK — all parsed without error
```

### Bước 7
Không có lệnh shell verify trong plan cho bước này (chỉ có tiêu chí "truy ngược được về commit
thật"). Đã tự kiểm bằng cách liệt kê mọi commit trích dẫn trong từng mục và xác nhận từng cái nằm
trong `cae36f1..HEAD` bằng `git merge-base --is-ancestor`:
```
OK  db4d525 feat: in tài liệu (⌘P) qua PDFDocument.printOperation
OK  3ac98de feat: chọn ngôn ngữ trong Settings + polish lại trang Settings
OK  1efb410 feat(i18n): sweep 29 file Views/Stores/Services/Models qua L()
OK  2ea6846 fix: sửa theo review i18n — bản dịch, literal sót, và lỗi số dòng của gate
OK  849efae feat: chèn hình, định dạng chữ, và khung chọn nét đứt cho hộp chữ
OK  995be77 feat: chỉnh sửa chú thích trực tiếp trên đối tượng
OK  6e17843 fix: delete and edit a selected annotation in place, not just move it
OK  b6909c5 docs: design for direct-manipulation annotation editing (frame + handles + popover)
OK  8b220a5 refactor: move edit tools into a Preview-style reveal bar; compact the toolbar
OK  098351b polish: đồng bộ icon và bố cục edit bar
OK  b5ba1aa fix: nhãn a11y trùng nghĩa và nút Inspector bị cắt cụt dưới tiếng Anh
OK  6615b48 fix: dismiss sheets on Escape via a pre-responder key monitor
OK  04bc1ef fix: let page thumbnails reorder by drag
OK  c1e0954 fix: use native panels for pickers SwiftUI was silently dropping
OK  2a96329 fix: draw signature ink in annotation-local space so it renders
OK  ef5205c test: pin signature ink coordinate mapping so it can't silently regress
OK  a269e20 fix: make search, zoom and Finder-opened files reachable on macOS
OK  ed26afb feat: cross-platform core, MuPDF/PAdES/OCR adapters and Linux shell
OK  f3f1b0a docs: verify the Linux Flutter shell GUI end-to-end; record the evidence
OK  c45ba0b test: ma trận operation-conformance 17 case × 2 engine (PDFKit vs MuPDF)
```
Tất cả 20 commit trích dẫn đều `OK`. Không mục nào mô tả tính năng đã có sẵn ở v1.0.0 (mọi mục
chỉ mô tả nội dung của các commit này, mà theo định nghĩa nằm sau `cae36f1`).
`git log --oneline cae36f1..HEAD` lúc soạn = 46 dòng (43 commit tính năng gốc + 3 commit của
chính coder này ở bước 1/5/6 — 3 commit đó là build/docs/chore packaging, **không** đưa vào
release notes vì không phải tính năng người dùng, và không khớp topic nào trong danh sách plan
đưa ra).

### Baseline cuối cùng (chạy lại sau khi xong cả 5 bước)
```
$ swift test
Test Suite 'All tests' passed ... Executed 183 tests, with 7 tests skipped and 0 failures

$ ./script/audit_local_first.sh && ./script/audit_portable_core.sh && \
  ./script/audit_i18n_strings.sh --self-test && ./script/audit_i18n_strings.sh
Local-first audit passed: no network client API found.
Portable-core audit passed: Core remains Foundation-only.
i18n audit self-test passed.
i18n audit passed: no literal Vietnamese strings or unresolved L(_:) keys in swept files.
```

### Kiểm tra không đụng code app (cho riêng 4 commit của coder này)
```
$ git diff --stat 09ddec3..HEAD -- Views/ Stores/ Services/ Models/ Core/ Adapters/ Shell/ \
  Package.swift Tests/ Resources/
(rỗng)
```

## Danh sách commit local đã tạo (không push)

1. `423691a` — `build: nâng version lên 1.1.0 và chặn build debug lọt vào release` (bước 1)
2. `c6b0551` — `docs: chuyển governance docs sang tiếng Anh mặc định, giữ bản Việt` (bước 5)
3. `abc881d` — `chore: thêm issue templates và PR template` (bước 6)
4. `ec00c1a` — `docs: sửa tên notary keychain profile khớp profile thật đã tạo`
   (đính chính `docs/MACOS_RELEASE.md`, theo yêu cầu riêng của orchestrator, không phải 1 trong
   5 bước nhưng cùng phạm vi "sửa tài liệu sai").

Bước 2 (build bundle) và bước 7 (release notes) không tạo commit: bước 2 chỉ ghi vào `dist/`
(gitignored), bước 7 ghi ra ngoài repo (`<state-dir>/release-notes-v1.1.0.md`).

## Khác thực tế so với plan

- Plan bước 8 ghi `NOTARY_PROFILE='AZpdf-notary'`; đã sửa `docs/MACOS_RELEASE.md` thành
  `azpdf-notary` theo đính chính của orchestrator (xem trên). `plan.md` chính nó (3 chỗ tham chiếu
  `AZpdf-notary`) **không bị sửa** — coder chỉ tick checkbox trong plan.md, không sửa nội dung kế
  hoạch; orchestrator/deployer cần dùng `azpdf-notary` (chữ thường) khi thật sự chạy bước 8.
- Không có khác biệt nào khác so với plan cho bước 1, 2, 5, 6, 7.

## Notes for tester

- `dist/AZpdf.app` hiện có ở máy này (bản release, version 1.1.0, **chưa ký/chưa notarize**,
  chỉ có mutool + ocrmypdf runtime bundled — không có veraPDF/pyHanko vì bước 2 chỉ cần đủ để
  chụp ảnh, không phải build release đầy đủ của bước 8). Đừng verify `spctl`/notarization trên
  bundle này — nó sẽ fail vì chưa ký, đó là kỳ vọng đúng ở giai đoạn này.
- Baseline giữ nguyên: `swift test` = 183 pass / 7 skip / 0 fail; 3 gate xanh. Đã chạy lại lần
  cuối sau khi xong cả 5 bước để xác nhận không bước nào làm hỏng bước trước.
- `release-notes-v1.1.0.md` còn placeholder `SHA-256 (AZpdf-macOS.zip): <điền ở bước 8>` ở cả 2
  ngôn ngữ — bắt buộc phải điền số thật sau khi bước 8 chạy xong, trước khi dùng cho
  `gh release create --notes-file`.
- 6 file governance docs KHÔNG đối xứng nội dung Anh/Việt một cách cố ý: bản EN của
  `CONTRIBUTING.md` có thêm mục "Dev quickstart" mà bản `.vi.md` không có (giữ nguyên văn bản cũ
  theo đúng chỉ định của plan — "giữ bản Việt... không viết lại"). Đây không phải thiếu sót.

## Notes for reviewer

- Không phát hiện dead code liên quan đến phạm vi 5 bước này (toàn bộ thay đổi là docs/YAML/2
  dòng script).
- `script/package_release.sh` dòng mới `export SWIFT_CONFIGURATION="${SWIFT_CONFIGURATION:-release}"`
  đặt ngay sau block `: "${VAR:?...}"` kiểm tra 5 biến bắt buộc — đúng vị trí plan yêu cầu
  ("ngay sau block kiểm env").
- `.forge/` và `.claude/` vẫn untracked trong git (đúng trạng thái từ trước khi coder bắt đầu,
  không đụng vào) — plan.md và state.json trong `.forge/` không nằm trong bất kỳ commit nào ở
  trên, kể cả các lần tick checkbox.
