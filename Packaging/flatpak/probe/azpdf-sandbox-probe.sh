#!/usr/bin/env bash
set -euo pipefail

if [[ -z "${FLATPAK_ID:-}" ]]; then
  echo "FLATPAK_ID is unavailable" >&2
  exit 10
fi

sandbox_dir="${HOME}/.var/app/${FLATPAK_ID}/sandbox"
token="$$-$(date +%s)"
input_name="azpdf-input-${token}.pdf"
request_name="azpdf-request-${token}.json"
work_name="azpdf-work-${token}"
input_path="${sandbox_dir}/${input_name}"
request_path="${sandbox_dir}/${request_name}"
work_path="${sandbox_dir}/${work_name}"
output_path="${work_path}/document-ir.json"
forbidden_path="${sandbox_dir}/azpdf-forbidden-${token}.txt"
host_marker="${HOME}/azpdf-flatpak-host-secret.txt"

mkdir -p "${sandbox_dir}" "${work_path}"
printf '%%PDF-AZpdf-probe\n' > "${input_path}"
printf '{"probe":true}\n' > "${request_path}"
chmod 400 "${input_path}" "${request_path}"
chmod 700 "${work_path}"

cleanup() {
  rm -f "${input_path}" "${request_path}" "${forbidden_path}"
  rm -rf "${work_path}"
}
trap cleanup EXIT

flatpak-spawn \
  --sandbox \
  --no-network \
  --clear-env \
  --watch-bus \
  "--sandbox-expose-ro=${input_name}" \
  "--sandbox-expose-ro=${request_name}" \
  "--sandbox-expose=${work_name}" \
  -- \
  /app/libexec/azpdf-structured-ocr-probe \
  recognize \
  --input "${input_path}" \
  --request "${request_path}" \
  --output "${output_path}" \
  --forbidden "${forbidden_path}" \
  --host-marker "${host_marker}"

test -s "${output_path}"
grep -q '"inputReadOnly":true' "${output_path}"
grep -q '"requestReadOnly":true' "${output_path}"
grep -q '"networkDenied":true' "${output_path}"
grep -q '"hostFileDenied":true' "${output_path}"
test ! -e "${forbidden_path}"
grep -q '^%PDF-AZpdf-probe$' "${input_path}"

printf 'FLATPAK_PROBE_PASS\n'
printf 'FLATPAK_PARENT_OUTSIDE_WRITE_DENIED\n'
cat "${output_path}"
