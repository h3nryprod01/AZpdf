#!/usr/bin/env bash
set -euo pipefail

# Write a release-specific SPDX 2.3 tag/value SBOM. It deliberately records
# checksums of every shipped helper file so a release can be audited even when
# a runtime has many native transitive libraries.
APP_BUNDLE="${1:?Usage: generate_sbom.sh /path/to/AZpdf.app /path/to/SBOM.spdx}"
OUTPUT="${2:?Usage: generate_sbom.sh /path/to/AZpdf.app /path/to/SBOM.spdx}"
HELPERS="$APP_BUNDLE/Contents/Resources/Helpers"
# mutool and pyHanko are in every build. veraPDF and OCRmyPDF are droppable
# (AZPDF_OMIT_RUNTIMES in package_release.sh) — so this SBOM describes what is ACTUALLY in
# the bundle rather than a fixed list of four. An SBOM is a supply-chain declaration:
# listing veraPDF in a bundle that has no veraPDF is a false statement, not a harmless
# leftover. The "did you forget a runtime?" gate lives upstream in package_release.sh,
# which is the only caller; duplicating it here would just be a second place to keep in sync.
[[ -x "$HELPERS/mutool" && -x "$HELPERS/pyhanko/pyhanko" ]] || {
  echo "mutool and pyHanko must be bundled before generating the SBOM" >&2; exit 2;
}
has_vera=0; [[ -x "$HELPERS/veraPDF/verapdf" ]] && has_vera=1
has_ocr=0;  [[ -x "$HELPERS/ocrmypdf/ocrmypdf" ]] && has_ocr=1

# Cùng nguồn với Info.plist (script/build_and_run.sh). Trước đây số này nằm cứng ở đây là
# 1.1.0 trong khi tag mới nhất đã là v1.2.0 — SBOM của mọi bản tải về đều khai sai phiên bản.
azpdf_version="$(tr -d '[:space:]' < "$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/VERSION")"
[[ -n "$azpdf_version" ]] || { echo "VERSION file is empty" >&2; exit 2; }

safe_version() { "$@" 2>&1 | head -n 1 | tr '\r\n' ' ' | sed 's/[[:space:]]\+$//; s/[^[:print:]]//g'; }
mutool_version="$(safe_version "$HELPERS/mutool" --version || true)"
pyhanko_version="$(safe_version "$HELPERS/pyhanko/pyhanko" --version || true)"
vera_version=""; ((has_vera)) && vera_version="$(safe_version "$HELPERS/veraPDF/verapdf" --version || true)"
ocr_version="";  ((has_ocr))  && ocr_version="$(safe_version "$HELPERS/ocrmypdf/ocrmypdf" --version || true)"
mkdir -p "$(dirname "$OUTPUT")"

cat >"$OUTPUT" <<EOF
SPDXVersion: SPDX-2.3
DataLicense: CC0-1.0
SPDXID: SPDXRef-DOCUMENT
DocumentName: AZpdf-macOS
DocumentNamespace: https://github.com/h3nryprod01/AZpdf/releases/sbom/$(date -u +%Y%m%dT%H%M%SZ)
Creator: Tool: AZpdf script/generate_sbom.sh
Created: $(date -u +%Y-%m-%dT%H:%M:%SZ)

PackageName: AZpdf
SPDXID: SPDXRef-AZpdf
PackageVersion: ${azpdf_version:-NOASSERTION}
PackageLicenseDeclared: AGPL-3.0-only
PackageDownloadLocation: NOASSERTION

PackageName: MuPDF mutool
SPDXID: SPDXRef-MuPDF
PackageVersion: ${mutool_version:-NOASSERTION}
PackageLicenseDeclared: AGPL-3.0-or-later
PackageDownloadLocation: https://mupdf.com/

PackageName: pyHanko
SPDXID: SPDXRef-pyHanko
PackageVersion: ${pyhanko_version:-NOASSERTION}
PackageLicenseDeclared: MIT
PackageDownloadLocation: https://github.com/MatthiasValvekens/pyHanko
EOF

if ((has_vera)); then
  cat >>"$OUTPUT" <<EOF

PackageName: veraPDF
SPDXID: SPDXRef-veraPDF
PackageVersion: ${vera_version:-NOASSERTION}
PackageLicenseDeclared: GPL-3.0-or-later OR MPL-2.0
PackageDownloadLocation: https://verapdf.org/
EOF
fi

# Tesseract/Ghostscript/qpdf are OCRmyPDF's native dependencies — they ship only inside that
# runtime, so they leave the SBOM with it.
if ((has_ocr)); then
  cat >>"$OUTPUT" <<EOF

PackageName: OCRmyPDF
SPDXID: SPDXRef-OCRmyPDF
PackageVersion: ${ocr_version:-NOASSERTION}
PackageLicenseDeclared: MPL-2.0
PackageDownloadLocation: https://ocrmypdf.readthedocs.io/

PackageName: Tesseract OCR
SPDXID: SPDXRef-Tesseract
PackageLicenseDeclared: Apache-2.0
PackageDownloadLocation: https://github.com/tesseract-ocr/tesseract

PackageName: Ghostscript
SPDXID: SPDXRef-Ghostscript
PackageLicenseDeclared: AGPL-3.0-or-later
PackageDownloadLocation: https://ghostscript.com/

PackageName: qpdf
SPDXID: SPDXRef-qpdf
PackageLicenseDeclared: Apache-2.0
PackageDownloadLocation: https://qpdf.readthedocs.io/
EOF
fi

{
  printf '\nRelationship: SPDXRef-AZpdf CONTAINS SPDXRef-MuPDF\n'
  printf 'Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-pyHanko\n'
  ((has_vera)) && printf 'Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-veraPDF\n'
  ((has_ocr)) && printf 'Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-OCRmyPDF\nRelationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Tesseract\nRelationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Ghostscript\nRelationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-qpdf\n'
  true
} >>"$OUTPUT"

while IFS= read -r file; do
  relative="${file#"$APP_BUNDLE/"}"
  printf '\nFileName: ./%s\nSPDXID: SPDXRef-File-%s\nFileChecksum: SHA256: %s\nLicenseConcluded: NOASSERTION\nLicenseInfoInFile: NOASSERTION\nFileCopyrightText: NOASSERTION\n' \
    "$relative" "$(printf '%s' "$relative" | shasum -a 256 | cut -c1-16)" "$(shasum -a 256 "$file" | awk '{print $1}')" >>"$OUTPUT"
done < <(find "$HELPERS" -type f | sort)

echo "SBOM: $OUTPUT"
