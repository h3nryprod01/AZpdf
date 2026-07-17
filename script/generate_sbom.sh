#!/usr/bin/env bash
set -euo pipefail

# Write a release-specific SPDX 2.3 tag/value SBOM. It deliberately records
# checksums of every shipped helper file so a release can be audited even when
# a runtime has many native transitive libraries.
APP_BUNDLE="${1:?Usage: generate_sbom.sh /path/to/AZpdf.app /path/to/SBOM.spdx}"
OUTPUT="${2:?Usage: generate_sbom.sh /path/to/AZpdf.app /path/to/SBOM.spdx}"
HELPERS="$APP_BUNDLE/Contents/Helpers"
[[ -x "$HELPERS/mutool" && -x "$HELPERS/veraPDF/verapdf" && -x "$HELPERS/pyhanko/pyhanko" && -x "$HELPERS/ocrmypdf/ocrmypdf" ]] || {
  echo "All four release helpers must be bundled before generating the SBOM" >&2; exit 2;
}

safe_version() { "$@" 2>&1 | head -n 1 | tr '\r\n' ' ' | sed 's/[[:space:]]\+$//; s/[^[:print:]]//g'; }
mutool_version="$(safe_version "$HELPERS/mutool" --version || true)"
vera_version="$(safe_version "$HELPERS/veraPDF/verapdf" --version || true)"
pyhanko_version="$(safe_version "$HELPERS/pyhanko/pyhanko" --version || true)"
ocr_version="$(safe_version "$HELPERS/ocrmypdf/ocrmypdf" --version || true)"
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
PackageVersion: 1.0.0
PackageLicenseDeclared: AGPL-3.0-only
PackageDownloadLocation: NOASSERTION

PackageName: MuPDF mutool
SPDXID: SPDXRef-MuPDF
PackageVersion: ${mutool_version:-NOASSERTION}
PackageLicenseDeclared: AGPL-3.0-or-later
PackageDownloadLocation: https://mupdf.com/

PackageName: veraPDF
SPDXID: SPDXRef-veraPDF
PackageVersion: ${vera_version:-NOASSERTION}
PackageLicenseDeclared: GPL-3.0-or-later OR MPL-2.0
PackageDownloadLocation: https://verapdf.org/

PackageName: pyHanko
SPDXID: SPDXRef-pyHanko
PackageVersion: ${pyhanko_version:-NOASSERTION}
PackageLicenseDeclared: MIT
PackageDownloadLocation: https://github.com/MatthiasValvekens/pyHanko

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

Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-MuPDF
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-veraPDF
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-pyHanko
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-OCRmyPDF
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Tesseract
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Ghostscript
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-qpdf
EOF

while IFS= read -r file; do
  relative="${file#"$APP_BUNDLE/"}"
  printf '\nFileName: ./%s\nSPDXID: SPDXRef-File-%s\nFileChecksum: SHA256: %s\nLicenseConcluded: NOASSERTION\nLicenseInfoInFile: NOASSERTION\nFileCopyrightText: NOASSERTION\n' \
    "$relative" "$(printf '%s' "$relative" | shasum -a 256 | cut -c1-16)" "$(shasum -a 256 "$file" | awk '{print $1}')" >>"$OUTPUT"
done < <(find "$HELPERS" -type f | sort)

echo "SBOM: $OUTPUT"
