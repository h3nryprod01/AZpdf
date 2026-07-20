#!/usr/bin/env bash
set -euo pipefail

BUNDLE="${1:?Usage: generate_linux_sbom.sh /path/to/linux/bundle /path/to/SBOM.spdx}"
OUTPUT="${2:?Usage: generate_linux_sbom.sh /path/to/linux/bundle /path/to/SBOM.spdx}"

if [[ "$(uname -s)" != "Linux" ]]; then
  echo "generate_linux_sbom.sh chỉ chạy trên Linux." >&2
  exit 2
fi

BUNDLE="$(cd "$BUNDLE" && pwd -P)"
ENGINE="$BUNDLE/azpdf-engine"
MUTOOL="$BUNDLE/mutool"
OCR_RUNTIME="$BUNDLE/runtime/ocrmypdf"
PADES_RUNTIME="$BUNDLE/runtime/pyhanko"

for executable in \
  "$ENGINE" \
  "$MUTOOL" \
  "$OCR_RUNTIME/ocrmypdf" \
  "$PADES_RUNTIME/pyhanko"; do
  [[ -x "$executable" ]] || {
    echo "Thiếu executable release: $executable" >&2
    exit 2
  }
done
for manifest in "$OCR_RUNTIME/components.tsv" "$PADES_RUNTIME/components.tsv"; do
  [[ -f "$manifest" ]] || {
    echo "Thiếu component manifest: $manifest" >&2
    exit 2
  }
done

component_version() {
  local manifest="$1" name="$2"
  awk -F '\t' -v name="$name" '$1 == name { print $2; exit }' "$manifest"
}

required_component_version() {
  local manifest="$1" name="$2" version
  version="$(component_version "$manifest" "$name")"
  [[ -n "$version" ]] || {
    echo "Thiếu version component $name trong $manifest" >&2
    exit 2
  }
  printf '%s' "$version"
}

safe_version() {
  "$@" 2>&1 | head -n 1 | tr '\r\n' ' ' | sed 's/[[:space:]]\+$//; s/[^[:print:]]//g'
}

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
app_version="${AZPDF_VERSION:-$(awk '/^version:/ {print $2; exit}' "$root_dir/Shell/azpdf_desktop/pubspec.yaml")}"
mutool_version="$(safe_version "$MUTOOL" --version | rg -o '[0-9]+(\.[0-9]+){2}' | head -n 1 || true)"
[[ -n "$app_version" && -n "$mutool_version" ]] || {
  echo "Không xác định được version AZpdf hoặc MuPDF." >&2
  exit 2
}
ocrmypdf_version="$(required_component_version "$OCR_RUNTIME/components.tsv" OCRmyPDF)"
tesseract_version="$(required_component_version "$OCR_RUNTIME/components.tsv" Tesseract)"
ghostscript_version="$(required_component_version "$OCR_RUNTIME/components.tsv" Ghostscript)"
qpdf_version="$(required_component_version "$OCR_RUNTIME/components.tsv" qpdf)"
pikepdf_version="$(required_component_version "$OCR_RUNTIME/components.tsv" pikepdf)"
pyhanko_version="$(required_component_version "$PADES_RUNTIME/components.tsv" pyHanko)"
pyhanko_cli_version="$(required_component_version "$PADES_RUNTIME/components.tsv" pyhanko-cli)"
pyinstaller_version="$(required_component_version "$PADES_RUNTIME/components.tsv" PyInstaller)"
certifi_version="$(required_component_version "$PADES_RUNTIME/components.tsv" certifi)"
tzdata_version="$(required_component_version "$PADES_RUNTIME/components.tsv" tzdata)"
created="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
namespace_stamp="$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$(dirname "$OUTPUT")"
OUTPUT="$(cd "$(dirname "$OUTPUT")" && pwd -P)/$(basename "$OUTPUT")"
package_verification_code="$({
  find "$BUNDLE" -type f ! -path "$OUTPUT" ! -path "$OUTPUT.sha256" -print0 \
    | xargs -0 -r sha1sum \
    | awk '{print $1}' \
    | sort \
    | tr -d '\n'
} | sha1sum | awk '{print $1}')"

cat >"$OUTPUT" <<EOF
SPDXVersion: SPDX-2.3
DataLicense: CC0-1.0
SPDXID: SPDXRef-DOCUMENT
DocumentName: AZpdf-Linux
DocumentNamespace: https://github.com/h3nryprod01/AZpdf/releases/sbom/linux-$namespace_stamp
Creator: Tool: AZpdf script/generate_linux_sbom.sh
Created: $created

PackageName: AZpdf
SPDXID: SPDXRef-AZpdf
PackageVersion: $app_version
FilesAnalyzed: true
PackageVerificationCode: $package_verification_code
PackageLicenseConcluded: AGPL-3.0-only
PackageLicenseDeclared: AGPL-3.0-only
PackageDownloadLocation: NOASSERTION
PackageCopyrightText: NOASSERTION

PackageName: MuPDF mutool
SPDXID: SPDXRef-MuPDF
PackageVersion: $mutool_version
FilesAnalyzed: false
PackageLicenseConcluded: AGPL-3.0-or-later
PackageLicenseDeclared: AGPL-3.0-or-later
PackageDownloadLocation: https://mupdf.com/
PackageCopyrightText: NOASSERTION

PackageName: OCRmyPDF
SPDXID: SPDXRef-OCRmyPDF
PackageVersion: $ocrmypdf_version
FilesAnalyzed: false
PackageLicenseConcluded: MPL-2.0
PackageLicenseDeclared: MPL-2.0
PackageDownloadLocation: https://ocrmypdf.readthedocs.io/
PackageCopyrightText: NOASSERTION

PackageName: Tesseract OCR
SPDXID: SPDXRef-Tesseract
PackageVersion: $tesseract_version
FilesAnalyzed: false
PackageLicenseConcluded: Apache-2.0
PackageLicenseDeclared: Apache-2.0
PackageDownloadLocation: https://github.com/tesseract-ocr/tesseract
PackageCopyrightText: NOASSERTION

PackageName: Ghostscript
SPDXID: SPDXRef-Ghostscript
PackageVersion: $ghostscript_version
FilesAnalyzed: false
PackageLicenseConcluded: AGPL-3.0-or-later
PackageLicenseDeclared: AGPL-3.0-or-later
PackageDownloadLocation: https://ghostscript.com/
PackageCopyrightText: NOASSERTION

PackageName: qpdf
SPDXID: SPDXRef-qpdf
PackageVersion: $qpdf_version
FilesAnalyzed: false
PackageLicenseConcluded: Apache-2.0
PackageLicenseDeclared: Apache-2.0
PackageDownloadLocation: https://qpdf.readthedocs.io/
PackageCopyrightText: NOASSERTION

PackageName: pikepdf
SPDXID: SPDXRef-pikepdf
PackageVersion: $pikepdf_version
FilesAnalyzed: false
PackageLicenseConcluded: MPL-2.0
PackageLicenseDeclared: MPL-2.0
PackageDownloadLocation: https://pikepdf.readthedocs.io/
PackageCopyrightText: NOASSERTION

PackageName: pyHanko
SPDXID: SPDXRef-pyHanko
PackageVersion: $pyhanko_version
FilesAnalyzed: false
PackageLicenseConcluded: MIT
PackageLicenseDeclared: MIT
PackageDownloadLocation: https://github.com/MatthiasValvekens/pyHanko
PackageCopyrightText: NOASSERTION

PackageName: pyhanko-cli
SPDXID: SPDXRef-pyhanko-cli
PackageVersion: $pyhanko_cli_version
FilesAnalyzed: false
PackageLicenseConcluded: MIT
PackageLicenseDeclared: MIT
PackageDownloadLocation: https://pypi.org/project/pyhanko-cli/
PackageCopyrightText: NOASSERTION

PackageName: PyInstaller
SPDXID: SPDXRef-PyInstaller
PackageVersion: $pyinstaller_version
FilesAnalyzed: false
PackageLicenseConcluded: GPL-2.0-only WITH Bootloader-exception
PackageLicenseDeclared: GPL-2.0-only WITH Bootloader-exception
PackageDownloadLocation: https://pyinstaller.org/
PackageCopyrightText: NOASSERTION

PackageName: certifi
SPDXID: SPDXRef-certifi
PackageVersion: $certifi_version
FilesAnalyzed: false
PackageLicenseConcluded: MPL-2.0
PackageLicenseDeclared: MPL-2.0
PackageDownloadLocation: https://pypi.org/project/certifi/
PackageCopyrightText: NOASSERTION

PackageName: tzdata
SPDXID: SPDXRef-tzdata
PackageVersion: $tzdata_version
FilesAnalyzed: false
PackageLicenseConcluded: Apache-2.0
PackageLicenseDeclared: Apache-2.0
PackageDownloadLocation: https://pypi.org/project/tzdata/
PackageCopyrightText: NOASSERTION

Relationship: SPDXRef-DOCUMENT DESCRIBES SPDXRef-AZpdf
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-MuPDF
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-OCRmyPDF
Relationship: SPDXRef-AZpdf CONTAINS SPDXRef-pyHanko
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Tesseract
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-Ghostscript
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-qpdf
Relationship: SPDXRef-OCRmyPDF DEPENDS_ON SPDXRef-pikepdf
Relationship: SPDXRef-PyInstaller BUILD_TOOL_OF SPDXRef-OCRmyPDF
Relationship: SPDXRef-pyHanko DEPENDS_ON SPDXRef-pyhanko-cli
Relationship: SPDXRef-pyHanko DEPENDS_ON SPDXRef-PyInstaller
Relationship: SPDXRef-pyHanko DEPENDS_ON SPDXRef-certifi
Relationship: SPDXRef-pyHanko DEPENDS_ON SPDXRef-tzdata
Relationship: SPDXRef-PyInstaller BUILD_TOOL_OF SPDXRef-pyHanko
EOF

while IFS= read -r file; do
  relative="${file#"$BUNDLE/"}"
  file_id="$(printf '%s' "$relative" | sha256sum | cut -c1-16)"
  checksum="$(sha256sum "$file" | awk '{print $1}')"
  printf '\nFileName: ./%s\nSPDXID: SPDXRef-File-%s\nFileChecksum: SHA256: %s\nLicenseConcluded: NOASSERTION\nLicenseInfoInFile: NOASSERTION\nFileCopyrightText: NOASSERTION\nRelationship: SPDXRef-AZpdf CONTAINS SPDXRef-File-%s\n' \
    "$relative" "$file_id" "$checksum" "$file_id" >>"$OUTPUT"
done < <(find "$BUNDLE" -type f ! -path "$OUTPUT" ! -path "$OUTPUT.sha256" | sort)

sha256sum "$OUTPUT" >"$OUTPUT.sha256"
echo "Linux SBOM: $OUTPUT"
