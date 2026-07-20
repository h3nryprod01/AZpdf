#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FIXTURE_DIR="${1:-$ROOT_DIR/Tests/Fixtures/generated}"
OUTPUT_DIR="${2:-$ROOT_DIR/qa-report/mupdf-benchmark}"
MUTOOL_BIN="${MUTOOL_BIN:-$(command -v mutool || true)}"

[[ -n "$MUTOOL_BIN" && -x "$MUTOOL_BIN" ]] || {
  echo "MuPDF mutool is required for the benchmark." >&2
  exit 2
}
[[ -d "$FIXTURE_DIR" ]] || {
  echo "Fixture directory does not exist: $FIXTURE_DIR" >&2
  exit 2
}

mkdir -p "$OUTPUT_DIR/render" "$OUTPUT_DIR/text"
METRICS="$OUTPUT_DIR/metrics.tsv"
REPORT="$OUTPUT_DIR/report.md"
version_output="$($MUTOOL_BIN --version 2>&1 || true)"
printf 'fixture\tpages\tbytes\trender_seconds\tpeak_rss_bytes\n' > "$METRICS"

shopt -s nullglob
fixtures=("$FIXTURE_DIR"/*.pdf)
(( ${#fixtures[@]} > 0 )) || { echo "No PDF fixture found." >&2; exit 2; }

for pdf in "${fixtures[@]}"; do
  name="$(basename "$pdf" .pdf)"
  timing="$OUTPUT_DIR/$name.time"
  pages="$($MUTOOL_BIN pages "$pdf" | awk '/<MediaBox /{count++} END{print count+0}')"
  bytes="$(wc -c < "$pdf" | tr -d ' ')"

  if [[ "$(uname -s)" == "Darwin" ]]; then
    /usr/bin/time -p -l -o "$timing" \
      "$MUTOOL_BIN" draw -q -F png -r 144 -o "$OUTPUT_DIR/render/$name-%d.png" "$pdf"
    peak_rss="$(awk '/maximum resident set size/{print $1; exit}' "$timing")"
  else
    /usr/bin/time -p -v -o "$timing" \
      "$MUTOOL_BIN" draw -q -F png -r 144 -o "$OUTPUT_DIR/render/$name-%d.png" "$pdf"
    peak_rss="$(awk -F: '/Maximum resident set size/{gsub(/^[[:space:]]+/, "", $2); print $2 * 1024; exit}' "$timing")"
  fi

  render_seconds="$(awk '/^real /{print $2; exit}' "$timing")"
  if [[ -z "$render_seconds" ]]; then
    elapsed="$(awk -F': ' '/Elapsed \(wall clock\) time/{print $2; exit}' "$timing")"
    render_seconds="$(awk -v value="$elapsed" 'BEGIN {
      count = split(value, part, ":")
      if (count == 3) printf "%.3f", part[1] * 3600 + part[2] * 60 + part[3]
      else if (count == 2) printf "%.3f", part[1] * 60 + part[2]
      else print value
    }')"
  fi
  "$MUTOOL_BIN" draw -q -F stext.json -o "$OUTPUT_DIR/text/$name.json" "$pdf"
  printf '%s\t%s\t%s\t%s\t%s\n' \
    "$name" "$pages" "$bytes" "$render_seconds" "${peak_rss:-0}" >> "$METRICS"
done

{
  echo '# MuPDF prototype benchmark'
  echo
  echo "- Runtime: \`$(printf '%s\n' "$version_output" | head -n 1)\`"
  echo "- Platform: \`$(uname -sm)\`"
  echo '- Render: PNG, 144 dpi'
  echo
  echo '| Fixture | Pages | Input bytes | Render seconds | Peak RSS bytes |'
  echo '| --- | ---: | ---: | ---: | ---: |'
  awk -F '\t' 'NR > 1 {printf "| %s | %s | %s | %s | %s |\n", $1, $2, $3, $4, $5}' "$METRICS"
} > "$REPORT"

echo "MuPDF benchmark report: $REPORT"
