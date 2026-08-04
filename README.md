# AZpdf

**English** | [Tiếng Việt](README-VI.md)

An open-source, local-first PDF reader and editor. macOS is the first release platform. The Linux port (v2) is in alpha and is the only downloadable build so far — an AppImage on the [releases page](https://github.com/h3nryprod01/AZpdf/releases). Windows builds and runs the core test suite in CI on every push, but has no installer yet.

<img width="254" height="254" alt="AZpdf icon" src="https://github.com/user-attachments/assets/53716e43-aa4a-4f71-ae2f-37f782328eb2" />

<img src="Assets/screenshots/azpdf-macos-hero.png" alt="AZpdf on macOS: a five-page PDF with a highlight, a text box, and an arrow annotation, page thumbnails in the sidebar and the document inspector open on the right" width="900" />

<img src="Assets/screenshots/azpdf-macos-editing.png" alt="Editing an annotation in place: a popover anchored to the selected text box offers font, size, bold and italic, alignment, colour, border and background controls" width="900" />


## In the first release
- Open, read, search, and navigate PDFs
- Open multiple PDFs in independent tabs without clobbering the document you are reading
- Navigate pages from the toolbar, the sidebar, or the `⌘[` / `⌘]` shortcuts
- Table of contents / PDF bookmarks in the sidebar whenever the document has an outline
- Fit-to-page zoom by default, with manual zoom controls and a Fit Page control to get back
- Search with a result count and previous/next result navigation
- Page thumbnails, zoom, text selection
- Add notes and highlights to the selected text; rotate, delete, duplicate, and reorder pages
- Add text boxes (free-text annotations) through a native sheet, with font, size, bold/italic, alignment, border, and background controls
- Draw a handwritten signature and insert it as a real PDF ink annotation
- Insert shapes: rectangle, oval, line, arrow, star, triangle — each is written as a standard PDF annotation subtype (Square, Circle, Line, Ink), so other readers render it correctly instead of showing an empty box
- Edit annotations directly on the object: click to select (a dashed frame for text boxes), drag handles to resize, a popover anchored to the object for its properties; arrow keys to nudge, Delete to remove
- Manage and delete the page's annotations from the Inspector, with undo
- Insert all pages from another PDF to merge documents (with undo)
- Insert images directly onto the page; drag to move, drag a corner handle to resize (aspect ratio preserved), saved as a durable stamp annotation
- Print (`⌘P`) through the system print dialog; annotations are included, and rotated pages come out the right way up
- Export the current page as a separate PDF
- Open password-protected PDFs with a native, on-device prompt
- OCR a drag-selected region, the current page, or the whole document through a hybrid local-first pipeline: the PDF text layer is preferred, with Apple's Vision framework at 3× render scale for scanned pages; review, edit, copy, or export the result as `.txt`. Pages carrying a region OCR could not read — a formula, a chart — are flagged in the review list rather than passed off silently: measured, all three engines we tested destroy mathematical notation, and Vision reports full confidence while doing it
- Export a password-protected copy through the native Save panel
- Redact the selection destructively: the page is rasterized and the original content is removed from the page's content stream
- Detect PDF forms; type directly into native widget fields in the document
- Validate PDF/A and PDF/UA with a local veraPDF runtime when available; the target profile is read from the document's XMP metadata, falling back to PDF/A-1b. The veraPDF report is shown verbatim — AZpdf never declares a document compliant on its own
- Undo/redo for up to 50 editing operations per session
- Unsaved-changes state clearly shown in the title bar and the Inspector
- Up to 8 recent documents for quick reopening
- Drag and drop a PDF onto the window to open it
- Save in place or export a new PDF
- English and Vietnamese interface; pick the language in Settings and it applies immediately, no relaunch

## Privacy and plugins

- **Local-first:** AZpdf never uploads your PDFs, their contents, passwords, or your document history to any server.
- CI scans the source to block networking APIs in the app and core targets. On every run it also plants a real `URLSession` violation and fails the build unless the scanner catches it — a gate that quietly stopped scanning cannot pass as green.
- **Plugin-ready:** OCR, translation, and summarization will ship as optional installable plugins; AZpdf itself depends on no cloud service.
- Plugins are only discovered locally at `~/Library/Application Support/AZpdf/Plugins/`; see [Plugins/README.md](Plugins/README.md) and the [sandbox model](docs/PLUGIN_PROTOCOL.md). v1 does not run third-party binaries.
- **OCR to searchable PDF:** after reviewing the preview, you can export a new PDF through OCRmyPDF in a mode that preserves the original text layer. The Linux alpha bundle ships a portable OCR runtime with Tesseract, Ghostscript, qpdf, and `vie`/`eng`/`osd` language data; on macOS, OCR itself uses Vision; searchable-PDF export additionally uses OCRmyPDF when its runtime is bundled or installed. Before writing that file AZpdf warns you if any page was flagged as unreadable, because a searchable PDF bakes the current text in permanently.

## Support the project

AZpdf is free under AGPL-3.0. If it is useful to you, you can [support the author on Ko-fi](https://ko-fi.com/h3nryng).

Or scan the VietQR code to donate directly in Vietnam:

<img src="Assets/donate-vietqr.jpg" alt="VietQR — support AZpdf" width="280" />

## Development

### macOS

Requires macOS 14+ and Xcode 26. Run `./script/build_and_run.sh`; CI uses `./script/build_and_run.sh --bundle` to build the `.app` without opening the GUI. When running from source, install MuPDF (`brew install mupdf`) for image insertion and veraPDF (`brew install verapdf`) for conformance validation. Release builds must pass `MUTOOL_RUNTIME_DIR` and `VERAPDF_RUNTIME_DIR` pointing at self-contained runtimes with vetted licenses and Hardened Runtime compatibility; the release script refuses to bundle without them.

Release packaging uses a Developer ID Application identity, Hardened Runtime, and notarization; see the [macOS release guide](docs/MACOS_RELEASE.md). AZpdf supports detached CMS/PKCS#7 signatures (`.p7s`) using certificates from the user's keychain, and embedded PAdES signing from a local PKCS#12 (`.p12`/`.pfx`). Baseline B, LT, and LTA profiles are available; LT/LTA require a TSA URL and still need testing against production trust stores/OCSP/CRL before use on long-term legal documents.

macOS releases ship with [third-party license notices](THIRD_PARTY_NOTICES.md) and an SPDX SBOM matching the bundled runtimes.

### Linux (v2 alpha)

**Download — Linux x86_64 (AppImage):** `AZpdf-x86_64.AppImage`, a single ~170 MB file.
SHA-256 `6be2dd1726f99d0a2de4edbb3f769bd62d794069c02a6afd148a18f6756cc848`
(verify with `sha256sum AZpdf-x86_64.AppImage`). x86_64 only — there is no arm64 build
yet. Make it executable and run: `chmod +x AZpdf-x86_64.AppImage && ./AZpdf-x86_64.AppImage`.
The engine (MuPDF 1.28.0, OCRmyPDF, pyHanko) is self-contained and runs in a clean Ubuntu
24.04 container; the Flutter shell, like every Flutter Linux app, dynamically links GTK3 and
OpenGL, so it needs four system libraries: `libgtk-3-0t64` (or `libgtk-3-0` on older
distributions), `libegl1`, `libgl1`, `libgles2` — e.g.
`sudo apt-get install -y libgtk-3-0t64 libegl1 libgl1 libgles2`. Any GTK desktop (GNOME,
XFCE, Cinnamon, MATE) already has them; only a minimal system or bare container needs to
install them, plus a display server. An SPDX SBOM ships beside the download.

Linux uses a Flutter shell that talks to the same Swift core over JSON Lines IPC. The engine and runtimes (MuPDF 1.28.0, OCRmyPDF/Tesseract, pyHanko) are self-contained; health checks, OCR to searchable PDF, and PAdES Baseline B signing/verification all ran in an Ubuntu 24.04 container — the GUI shell needs the four GTK/GL libraries listed above. A development Flatpak on the Freedesktop 25.08 runtime has passed the sandbox probe, runtime health checks, and a GTK document-portal end-to-end test with real PDF fixtures; a reproducible public manifest for Flathub and real KDE portals are the next steps. The shell can display the document's reading order (`DocumentIR`) as an overlay on the page for review. See the [cross-platform shell guide](Shell/azpdf_desktop/README.md), the [UI/UX report](qa-report/azpdf-linux-shell-report-2026-07-18.html), and the [Ubuntu workstation QA](qa-report/azpdf-linux-workstation-report-2026-07-19.md).

Technical roadmap and Windows/Linux groundwork: [ROADMAP.md](ROADMAP.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md). Local plugin conventions: [docs/PLUGIN_PROTOCOL.md](docs/PLUGIN_PROTOCOL.md).

Local-first OCR direction: [docs/OCR_PLAN.md](docs/OCR_PLAN.md).

## License

AGPL-3.0-only. AZpdf is free to use, share, and improve — forever; modified distributions must publish their source under the same license. See the [official AGPL-3.0 text](https://www.gnu.org/licenses/agpl-3.0.html).
