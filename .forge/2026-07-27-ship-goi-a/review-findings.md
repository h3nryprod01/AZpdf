# Review — Gói A: ship AZpdf v1.1.0 public (final gate)

## Verdict

**BLOCK** — 3 HIGH findings, all cheap (~10 min total). None is a code defect; all three
are in what goes public. Nothing in the build, the ZIP, or the cask is broken.

Verified sound and needing no further work: SHA-256 matches the real ZIP byte-for-byte,
notarization/stapling valid, cask syntax + zap paths correct against disk, screenshots
carry no leaks, `swift test` still 183/7/0 and all 3 gates exit 0 after my edits.

## Needs decision (HIGH)

| Sev | File:Line | Issue | Suggested fix |
|---|---|---|---|
| HIGH | `release-notes-v1.1.0.md:74-75` (EN) + `:156-157` (VI) | **False claim, checkable against a file in the same repo.** "The MuPDF adapter was validated against PDFKit with a 17-case x 2-engine operation-conformance matrix" reads as "MuPDF was checked for parity with PDFKit". `qa-report/engine-operation-matrix-2026-07.md` states the opposite: *"Không tồn tại một `DocumentOperation` case nào cả hai engine cùng `supported`"* — PDFKit 6/17 supported, MuPDF 3/17, **zero overlap**, so no behaviour was ever compared. 4 of the 17 rows also have deliberately weak postconditions ("chỉ tin được ở mức unsupported hôm nay"). Left untouched — HIGH is yours to word. | Replace both bullets with: EN — "A 17-case x 2-engine conformance harness now measures which `DocumentOperation` cases each engine really implements, by reading back document state instead of trusting that `apply` did not throw. Today PDFKit covers 6 of 17 and MuPDF 3 of 17, with no overlap — closing that gap is the Linux roadmap." VI — "Bộ đo conformance 17 case × 2 engine đo thật xem mỗi engine implement được case `DocumentOperation` nào, bằng cách đọc lại state tài liệu chứ không tin `apply` không ném lỗi. Hiện PDFKit đạt 6/17, MuPDF 3/17, không case nào trùng — thu hẹp khoảng cách đó là lộ trình Linux." |
| HIGH | `dist/release/AZpdf-macOS.zip` → `AZpdf.app/Contents/MacOS/AZpdf` @ offset 1148128 | **Irreversible privacy leak in the artifact.** The shipping binary contains `/Users/nguyenphucuong/Documents/Codex/2026-07-16/azpdf-fix/.build/arm64-apple-macosx/release/AZpdf_AZpdf.bundle` — SwiftPM's `Bundle.module` accessor embeds the build dir as a fallback path. Exactly one occurrence; the 4 bundled runtimes (mutool/veraPDF/pyhanko/ocrmypdf) are clean. Publishing makes it permanent: the cask pins the sha256, so replacing the asset later invalidates it and early downloaders keep the old copy. This repo already had to patch a leak of this class (`a713df9`). | Your call, both defensible: **(a) Accept.** Discloses your macOS username + a folder-naming habit. Your legal name is already public in every copy via the Developer ID signature (`Phu Cuong Nguyen (49ZXQQ2SPX)`), so the marginal loss is the folder path. **(b) Rebuild.** Costs a full rebuild + re-sign + re-notarize (hours) and a new SHA in notes + cask. Either way, fix it permanently for v1.1.1 by building under a neutral scratch path (`swift build --scratch-path /private/tmp/azpdf-build`) in `script/build_and_run.sh`. |
| HIGH | `SECURITY.md:7`, `CODE_OF_CONDUCT.md:10` (+ the `.vi.md` mirrors I just aligned) | **The security channel is dead on arrival.** Both docs send everyone to `https://github.com/h3nryprod01/AZpdf/security/advisories/new`, but `gh api repos/h3nryprod01/AZpdf/private-vulnerability-reporting` → `{"enabled":false}`. With it disabled, that URL only works for users with write access; an outside researcher gets a 404. Predictable result: they file a **public** issue with a live vulnerability — the precise outcome SECURITY.md exists to prevent. Missing from plan step 10. | Add to step 10, before the push: `gh api -X PUT repos/h3nryprod01/AZpdf/private-vulnerability-reporting` (or Settings → Security → Private vulnerability reporting → Enable). Then load the URL logged out to confirm. |

## Auto-applied

Release notes — `.forge/2026-07-27-ship-goi-a/release-notes-v1.1.0.md` (both languages kept in sync):

- MEDIUM: softened the i18n claim. Was "every user-facing string resolves through the
  localization system" — `qa-report/azpdf-macos-a11y-i18n-2026-07-27.md` §C names two live
  gate blind spots and says *"không có gì đảm bảo đã hết"*. Now describes the sweep + the
  CI check, which is what actually holds.
- MEDIUM: added 3 real user-facing fixes the notes dropped — certificate signing reporting
  errors instead of looking successful (`f4af1fc`), empty starting tab reused (`eab935c`),
  and the menu items/keyboard shortcuts added for search/zoom/inspector/page nav (`a269e20`),
  which the old one-liner undersold as things being "reachable again". They were never
  reachable in v1.0.0 — "again" was wrong.
- MEDIUM: added an **Install** section warning that `unzip` corrupts the bundle. See "Test
  gaps" below — this is a real trap I reproduced, not a theoretical one.
- MEDIUM: rewrote 4 bullets that were engineer-speak rather than English: "annotation-local
  space" → "stays where you drew it"; "the ones SwiftUI was silently dropping" (reads as if
  SwiftUI drops pickers) → "the SwiftUI ones were sometimes dropped without ever appearing";
  "a VoiceOver label with duplicate meaning" → names the actual bug (two buttons both read
  "Delete", one deletes a page); "reorganized and polished alongside adding the language
  picker" → "reorganized and tidied up around the new language picker".
- LOW: merged the duplicated direct-manipulation bullet (bullet 2 restated "Delete"/"edit"
  from bullet 1).
- LOW: cut the top-of-page branch-history note from 4 lines of SHAs and branch names to 2
  plain lines. It was the first thing an English reader hit.
- LOW: the SHA line was inside a fenced code block *with* backticks around the hash, so
  GitHub would render the backticks literally. Unfenced, and added `shasum -a 256` so
  "Verify" tells you how.
- LOW: `[English](#english)` pointed at a manual `<a id="english">`; GitHub rewrites user
  `id` attributes to `user-content-*`. Repointed both nav links at real heading anchors.
- LOW: "macOS 14+" → "macOS 14 Sonoma or later" (matches the cask's `>= :sonoma` and the
  tap README).

Governance docs (tracked files — **these are uncommitted, see Punts**):

- MEDIUM: `CONTRIBUTING.vi.md` had no dev quickstart and listed only 3 gates, omitting
  `audit_i18n_strings.sh` and the en+vi `.lproj` rule. A Vietnamese contributor following
  their own doc would have had CI reject the PR for a rule their doc never mentioned.
  Brought to parity with `CONTRIBUTING.md`.
- MEDIUM: `SECURITY.vi.md` still said *"Khi repository đã public… chi tiết kênh liên hệ sẽ
  được bổ sung"* — stale, and it withheld the advisory URL the English file gives. Mirrored EN.
- MEDIUM: `CODE_OF_CONDUCT.vi.md` had the same "khi repository public" staleness and no
  reporting link. Mirrored EN.

## Test gaps

- **`unzip` breaks the bundle — reproduced, and nothing tests it.** The ZIP carries 737
  AppleDouble `._*` entries inside `AZpdf.app/` (correct output of `ditto -c -k --keepParent`
  on a signed+stapled app — Apple's documented command, `package_release.sh:53`). Extracted
  with `ditto -x -k`: `codesign --verify --deep --strict` → *valid on disk*, `spctl` →
  *accepted / Notarized Developer ID*, `stapler validate` → OK. Extracted with plain
  `/usr/bin/unzip`: `codesign` → *file added: …/._CodeResources*, `spctl` → **"a sealed
  resource is missing or invalid"** → macOS calls the app damaged.
  **The cask is safe**: `Library/Homebrew/extend/os/mac/unpack_strategy/zip.rb` routes to
  `ditto -x -k` when `merge_xattrs` is set and the zip contains `._` entries, and
  `cask/download.rb:195` passes `merge_xattrs: true`. Finder/Safari are safe too. Only a
  developer typing `unzip` in Terminal — this project's exact audience — gets bitten, which
  is why I documented it rather than changing the packaging. Not fixable at the ZIP level:
  `--norsrc --noextattr` would strip the code signatures of nested scripts.
- The 3 gates and `swift test` never touch the release artifact. `script/verify_release.sh`
  exists but nothing runs it against the *extracted* ZIP, which is what users actually get.
  Worth a step-8 addition later: extract the ZIP both ways and assert `spctl`.
- No test pins the cask's `zap` paths to the app's real write locations. Verified by hand
  this time: `defaults domains` → `org.azpdf.mac`; `~/Library/Preferences/org.azpdf.mac.plist`
  exists; `Services/PluginRegistry.swift:14` writes `~/Library/Application Support/AZpdf/Plugins`.
  All 3 zap paths are correct and none is broad enough to catch another app's data.
- Release notes accuracy is unverifiable by CI. I checked each claim against code or QA
  evidence: printing (`DocumentStore+Printing.swift` + GUI QA `azpdf-macos-print-2026-07-24.md`),
  6 shapes → Square/Circle/Line/Ink (`Models/ShapeAnnotation.swift:50-57`), live language
  switch (`App/OpenPaperApp.swift:12,18` — `@AppStorage` + `.id()` rebuild), arrow-key nudge
  and Delete (`Views/PDFReaderView.swift:503-512`), Escape (`Views/EscapeDismissInstaller.swift:30`).
  All hold. No feature is claimed as new that already shipped in v1.0.0 — confirmed by
  `git cat-file -e cae36f1:<path>`: `ShapeAnnotation.swift`, `DocumentStore+Printing.swift`,
  `Support/Localization.swift`, `EscapeDismissInstaller.swift` and every `.lproj` are absent
  from the v1.0.0 tree.

## Punts

- **Commit the 3 governance files before pushing.** `CODE_OF_CONDUCT.vi.md`,
  `CONTRIBUTING.vi.md`, `SECURITY.vi.md` are modified and unstaged. `git push origin main`
  as step 10.1 currently ships the old versions. `.forge/` is untracked, so the release
  notes are safe to leave uncommitted.
- The commit count in `plan.md` and the task brief says 43; `git rev-list --count cae36f1..HEAD`
  is now **48**. The 5 extra are this build's own docs/build commits. 43 was the correct
  pre-build number — no missing feature, just don't quote 43 anywhere public.
- `README.md:14` still says **"## In the first release"** above a list that now includes
  printing, shapes, i18n and direct-manipulation editing — features the release notes
  simultaneously announce as new in 1.1.0. A reader comparing the two pages sees a
  contradiction, and anyone who downloads v1.0.0 finds no printing. Suggest "## Features"
  / "## Tính năng" (`README.vi.md:14`). Left alone: it is a framing choice, not a defect.
- Plan step 10 creates the release (10.6) **before** the tap repo (10.7). I deliberately
  kept `brew` out of the release notes' Install section for that reason. If you want brew
  install instructions on the release page, create the tap first or edit the body afterwards
  — release bodies are editable, the ZIP is not.
- Cask has no `uninstall quit: "org.azpdf.mac"`. Without it, `brew uninstall --cask azpdf`
  on a running app deletes the bundle out from under a live process. One line, standard for
  GUI casks. Not applied — outside what was asked.
- `ROADMAP.md` is 100% Vietnamese and is linked from the English README (`README.md:75`).
  Not blocking, but it is the one English-reader dead end left in the public docs.
- The edit bar in `Assets/screenshots/azpdf-macos-editing.png` is itself a 17-icon row,
  while the notes sell "compact now instead of the previous crowded row of icons". Literally
  true (the *toolbar* is compact; the icons moved into a reveal bar) but the screenshot is
  the counter-argument. Fine to ship; know that someone will point it out.
