#!/usr/bin/env bash
set -euo pipefail

if [[ "${1:-}" != "recognize" ]]; then
  echo "unsupported probe command" >&2
  exit 20
fi
shift

input=''
request=''
output=''
forbidden=''
host_marker=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --input) input="$2"; shift 2 ;;
    --request) request="$2"; shift 2 ;;
    --output) output="$2"; shift 2 ;;
    --forbidden) forbidden="$2"; shift 2 ;;
    --host-marker) host_marker="$2"; shift 2 ;;
    *) echo "unknown probe argument: $1" >&2; exit 21 ;;
  esac
done

test -r "${input}"
test -r "${request}"
test ! -e "${host_marker}"

input_read_only=true
if printf 'tamper\n' >> "${input}" 2>/dev/null; then
  input_read_only=false
fi

request_read_only=true
if printf 'tamper\n' >> "${request}" 2>/dev/null; then
  request_read_only=false
fi

network_denied=true
if getent ahosts example.com >/dev/null 2>&1; then
  network_denied=false
fi

outside_write_attempted=false
if printf 'escape\n' > "${forbidden}" 2>/dev/null; then
  outside_write_attempted=true
fi

printf 'probe-flags inputReadOnly=%s requestReadOnly=%s networkDenied=%s outsideWriteAttempted=%s\n' \
  "${input_read_only}" "${request_read_only}" "${network_denied}" "${outside_write_attempted}" >&2

if [[ "${input_read_only}" != true || "${request_read_only}" != true || \
      "${network_denied}" != true ]]; then
  echo "Flatpak isolation invariant failed" >&2
  exit 22
fi

printf '{"inputReadOnly":true,"requestReadOnly":true,"networkDenied":true,"hostFileDenied":true,"outsideWriteAttempted":%s}\n' \
  "${outside_write_attempted}" > "${output}"
