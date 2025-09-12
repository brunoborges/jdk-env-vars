#!/usr/bin/env bash
# aggregate-report.sh
# Build an enhanced REPORT.md from JSON result files produced by check-jvm-env-vars.sh
# Expects directories like artifacts/precedence-json-jdk-*/result.json (GitHub Actions layout)
# Can also be pointed at a root directory containing such subdirs via first arg.
set -euo pipefail

ROOT_DIR=${1:-artifacts}
OUTPUT=${2:-REPORT.md}

if ! command -v jq >/dev/null 2>&1; then
  echo "ERROR: jq required" >&2
  exit 1
fi

# Gather files
mapfile -t FILES < <(find "$ROOT_DIR" -type f -name result.json | sort)
if [[ ${#FILES[@]} -eq 0 ]]; then
  echo "No result.json files found under $ROOT_DIR" >&2
  exit 1
fi

# Header
{
  echo "# JVM Option Env Var Precedence Report"
  echo
  echo "Generated: $(date -u '+%Y-%m-%d %H:%M UTC')"
  echo
  echo "This report aggregates precedence detection across multiple JDK versions."
  echo
  echo "## Summary Table"
  echo
  echo "| JDK | Supported Vars | Unsupported Vars | Precedence (highest→lowest) | Status |"
  echo "|-----|----------------|------------------|-----------------------------|--------|"
} > "$OUTPUT"

supports_matrix_header_done=false

for f in "${FILES[@]}"; do
  jdk=$(echo "$f" | sed -E 's/.*jdk-([0-9]+)\/.*/\1/') || jdk=?
  supported=$(jq -r '[.supported[]?] | join(", ")' "$f")
  [[ -z $supported ]] && supported="(none)"
  unsupported=$(jq -r '[.unsupported[]?] | join(", ")' "$f")
  [[ -z $unsupported ]] && unsupported="(none)"
  order=$(jq -r 'if .order==null then "(inconclusive)" else (.order | join(" > ")) end' "$f")
  status=$(jq -r '.status' "$f")
  printf '| %s | %s | %s | %s | %s |\n' "$jdk" "$supported" "$unsupported" "$order" "$status" >> "$OUTPUT"

done

{
  echo
  echo "## Support Matrix"
  echo
  echo "Legend: ✅ supported, ❌ unsupported"
  echo
  # Collect union of variable names from JSON (though they are fixed) to be future-proof
  vars=($(jq -r '[.supported[], .unsupported[]] | unique[]' "${FILES[0]}") )
  if [[ ${#vars[@]} -eq 0 ]]; then
    vars=(_JAVA_OPTIONS JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS)
  fi
  # Header row
  header='| JDK |'
  for v in "${vars[@]}"; do header+=" ${v} |"; done
  sep='|-----|'
  for v in "${vars[@]}"; do sep+='---|'; done
  {
    echo "$header"
    echo "$sep"
    echo
  } >> "$OUTPUT"
  for f in "${FILES[@]}"; do
    jdk=$(echo "$f" | sed -E 's/.*jdk-([0-9]+)\/.*/\1/') || jdk=?
    row="| ${jdk} |"
    for v in "${vars[@]}"; do
      if jq -e --arg v "$v" '.supported | index($v)' "$f" >/dev/null; then
        row+=" ✅ |"
      else
        row+=" ❌ |"
      fi
    done
    echo "$row" >> "$OUTPUT"
  done

  echo
  echo "## Detailed Per-JDK Results"
  echo
} >> "$OUTPUT"

for f in "${FILES[@]}"; do
  jdk=$(echo "$f" | sed -E 's/.*jdk-([0-9]+)\/.*/\1/') || jdk=?
  echo "### JDK ${jdk}" >> "$OUTPUT"
  precedence=$(jq -r 'if .order==null then null else (.order | join(" > ")) end' "$f")
  if [[ -n ${precedence:-} ]]; then
    echo "**Precedence:** \`$precedence\`" >> "$OUTPUT"
  else
    echo "**Precedence:** (inconclusive)" >> "$OUTPUT"
  fi
  echo >> "$OUTPUT"
  echo "<details><summary>Raw JSON</summary>" >> "$OUTPUT"
  echo '' >> "$OUTPUT"
  echo '```json' >> "$OUTPUT"
  cat "$f" >> "$OUTPUT"
  echo '```' >> "$OUTPUT"
  echo '</details>' >> "$OUTPUT"
  echo >> "$OUTPUT"

done

{
  echo '## Notes'
  echo
  echo '* If a variable is marked unsupported for a JDK (e.g., JDK_JAVA_OPTIONS on JDK 8), comparisons involving it are reported as "unsupported" and it is excluded from the precedence chain.'
  echo '* Status values: ok (consistent), mismatch (sanity check disagreed), inconclusive (insufficient data or full cycle).' 
} >> "$OUTPUT"

echo "Wrote $OUTPUT" >&2
