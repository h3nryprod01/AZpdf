# Security scan — Lát cắt 1e: Ma trận operation-conformance (test harness + fixture, Foundation-only)

## Verdict
CLEAN

## Scanners run
- SwiftPM deps (Package.swift / Package.resolved) → **0 new deps**; both unchanged vs HEAD (`git diff --stat` empty) — slice adds no dependency
- npm / pnpm / cargo audit        → N/A (no JS/Rust manifest in this Swift repo's diff; tools present but nothing to scan)
- pip-audit / govulncheck / osv-scanner → not run (tools unavailable AND no matching ecosystem in scope)
- gitleaks / trufflehog           → not run (tools unavailable; used grep fallback across all 6 files → 0 findings)
- semgrep (auto)                  → not run (tool unavailable; manually read all 4 Swift files + grep sink analysis → 1 subprocess reviewed, safe)
- Fixture binary analysis (mutool show/info/draw + zlib stream decompress + dangerous-keyword scan) → 0 malicious constructs
- audit_portable_core.sh (Foundation-only boundary gate) → **passed, exit 0** (re-ran independently)

## Blocking (CRITICAL / HIGH)
None.

## Non-blocking (MEDIUM / LOW)
- **LOW** — `Tests/AZpdfMuPDFTests/MuPDFOperationMatrixTests.swift:42-51` `installedMutoolVersion` reads the
  pipe *after* `waitUntilExit()`. Theoretical deadlock if child output exceeds the ~64KB pipe buffer, but
  `mutool -v` emits a single line, so it is inert. Robustness nit, not a security issue. Already flagged by the
  reviewer (review-findings.md Punts). No action required.

## Notes
### Point-by-point on the task's flagged risks
1. **Fixture `two-page.pdf` (supply-chain, the real concern) — CLEAN.** 1166 bytes, 10 objects, PDF 1.7.
   sha256 `c8bfd1d8755365c503b972430edb4f65074d333cbbf97feeba8a0299fc802a42`. Structure: Catalog → Pages →
   1 Type1 Helvetica font → 2 Page objects → 2 FlateDecode content streams (104 B each) + 2 resource dicts.
   Keyword scan for `/JavaScript /JS /Launch /OpenAction /AA /EmbeddedFile /URI /GoToR /SubmitForm /XFA
   /RichMedia /AcroForm` and `http(s)://`, `file://` → **all zero**. Both content streams decompress to plain
   text-drawing operators (`BT/Tf/Td/Tj/ET`) containing only the `AZPDF-P1`/`AZPDF-P2` markers + a caption —
   no hidden payload. No trailing bytes after `%%EOF`. Producer string is `MuPDF 1.28.0` (no username/path leak).
   Safe to commit and distribute to every contributor.
2. **mutool subprocess — CLEAN.** The only spawn in the diff is `mutool -v` with a fixed argv `["-v"]` via
   `Process` + `executableURL` (execve-style, **no shell**, no string interpolation). `MUTOOL_BIN` env var is
   read only as a candidate executable path, gated by `FileManager.isExecutableFile`, then passed as
   `executableURL` — it is the test-runner's own environment, not an attacker-controlled surface. The fixture is
   passed to the harness as `Data` (bytes), never as a command-line path. For completeness: the pre-existing
   `Adapters/MuPDF/MuPDFDocumentEngine.swift` (out of diff scope) feeds mutool by writing bytes to a temp file
   (`data.write(to:input, .atomic)`) and passing the path — also shell-free. No command-injection path exists.
3. **Foundation-only claim — CONFIRMED.** `Core/PDFEngineOperationConformance.swift` imports `Foundation` only
   (no AppKit/PDFKit/SwiftUI/UIKit, no URLSession/Socket/Network, no Process). `audit_portable_core.sh` re-ran
   → exit 0. The harness is a pure in-memory generic over an injected engine; no I/O of its own.
4. **Secrets / sensitive data — NONE.** grep for AWS keys, `-----BEGIN`, bearer/JWT, api_key/secret/token/
   password, `gh*_`/`xox*` across all text files → 0. No `/Users/<name>` or `/home/<name>` literals. Fixture URLs
   use `#filePath` (a compile-time macro — resolves at build time, not a committed literal, so no username leaks
   into source). The base64 PNG literal (`iVBORw0KGgo…`, in two test files) decodes to a genuine 69-byte 1×1 RGB
   PNG — pre-triaged so a future entropy-based scanner flag is known-benign, not a smuggled secret.
5. **Dependencies — NONE added.** `Package.swift` and `Package.resolved` show no diff vs HEAD; plan's "don't
   touch Package.swift" constraint held.

### Coverage gaps (honest)
- gitleaks / trufflehog / semgrep / osv-scanner are **not installed** on this machine — no `npm install -g` was
  done (per rules). Fallback was grep-based secret/sink scanning **plus a full manual read of all 4 Swift files**
  and a complete structural dump of the fixture. For a 6-file, test-only diff with no app endpoint / auth /
  user-input-parsing surface, this is adequate coverage — but the absence of the dedicated scanners is a
  documented gap, not a silent pass.
