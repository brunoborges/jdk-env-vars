#!/usr/bin/env bash
# check-jvm-env-vars.sh
#
# Purpose:
#  Determine the precedence ordering among the three JVM option environment variables:
#    1) _JAVA_OPTIONS
#    2) JAVA_TOOL_OPTIONS
#    3) JDK_JAVA_OPTIONS
#  for (at least) JDK 21 (may work on other versions too).
#
# Method:
#  * Create a tiny Java source that prints a chosen system property key (default: foo)
#  * Execute the JVM multiple times with different pairs of env vars each assigning
#    a distinct -D<key>=from-<ENV_NAME> value.
#  * The observed value reveals which env var's -D wins for that pair.
#  * From the three pairwise comparisons deduce a global order (if acyclic & complete).
#  * Perform an all-three sanity run and optionally emit JSON for tooling.
#
# Enhancements vs original version:
#  * Robust CLI with help (-h)
#  * Custom property key (-p) and random default key to avoid clashes
#  * JSON output (-j) / quiet mode (-q) / keep temp dir (-k) / no color (--no-color)
#  * JDK version detection & warning if not 21+
#  * Cycle / ambiguity detection
#  * Sanity check validation and explicit status reporting
#  * Uses an isolated temporary directory; cleans up unless -k specified
#  * Optional color output (auto disabled for non-TTY or when --no-color)
#
# Exit codes:
#  0 success (even if order inconclusive, still ran)
#  1 internal error (e.g., java missing)
#
# NOTE: We intentionally run "java SourceFile.java" (source-file mode) to avoid class artifacts.

set -euo pipefail

SCRIPT_NAME="$(basename "$0")"

# Default options
PROPERTY_KEY="foo$RANDOM"   # randomize to reduce interference from prior runs
OUTPUT_JSON=false
QUIET=false
KEEP_TEMP=false
COLOR=true
SANITY=true

ENV_VARS=( _JAVA_OPTIONS JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS )

# ---------- color handling ----------
if [[ ! -t 1 ]]; then COLOR=false; fi

RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""
if $COLOR; then
  RED=$'\033[31m'; GREEN=$'\033[32m'; YELLOW=$'\033[33m'; BLUE=$'\033[34m'; BOLD=$'\033[1m'; RESET=$'\033[0m'
fi

# ---------- helpers ----------
say() { $QUIET && return 0; printf "%s\n" "$*"; }
say_err() { printf "%s\n" "$*" >&2; }
hr() { $QUIET && return 0; printf "%s\n" "----------------------------------------"; }

log_note() { # route notes/warnings; if JSON mode keep stdout clean
  if $OUTPUT_JSON; then
    printf '%s\n' "$*" >&2
  else
    say "$*"
  fi
}

# Escape a string for safe JSON embedding (basic subset: quotes, backslashes, control chars, newlines)
escape_json() {
  local s="$1"
  s=${s//\/\\}       # backslash
  s=${s//"/\"}       # quote
  s=${s//$'\n'/\\n}  # newline
  s=${s//$'\r'/\\r}  # carriage return
  s=${s//$'\t'/\\t}  # tab
  s=${s//$'\f'/\\f}  # formfeed
  s=${s//$'\b'/\\b}  # backspace
  # Remove ESC and other non-printable control chars (0x00-0x1F except handled ones) to keep JSON simple
  s=$(printf '%s' "$s" | tr -d '\000-\010\013\014\016-\037')
  printf '%s' "$s"
}

usage() {
  cat <<EOF
${SCRIPT_NAME} - Determine precedence among JVM option env vars

Usage: ${SCRIPT_NAME} [options]

Options:
  -p <property>   System property key to test (default: random foo####)
  -j              JSON output (machine readable)
  -q              Quiet (suppress human-readable progress; still emits JSON if -j)
  -k              Keep temporary working directory
  --no-color      Disable color output
  --no-sanity     Skip final all-three sanity check
  -h              Show this help and exit

Examples:
  ${SCRIPT_NAME}
  ${SCRIPT_NAME} -p testKey -j
  ${SCRIPT_NAME} -q -j > result.json

Exit codes:
  0 success
  1 setup / runtime error
EOF
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      -p) shift; PROPERTY_KEY="${1:?missing property name}" ;;
      -j) OUTPUT_JSON=true ;;
      -q) QUIET=true ;;
      -k) KEEP_TEMP=true ;;
      --no-color) COLOR=false ;;
      --no-sanity) SANITY=false ;;
      -h|--help) usage; exit 0 ;;
      *) say_err "Unknown option: $1"; usage; exit 1 ;;
    esac
    shift || true
  done
  if ! $COLOR; then RED=""; GREEN=""; YELLOW=""; BLUE=""; BOLD=""; RESET=""; fi
}

JAVA_MAJOR=""  # populated in require_java

require_java() {
  if ! command -v java >/dev/null 2>&1; then
    say_err "ERROR: java not found in PATH"; exit 1
  fi
  local v out
  out="$(java -version 2>&1 | head -n1)"
  # Pattern handles both modern 'openjdk version "21.0.1"' and legacy 'java version "1.8.0_402"'
  if [[ $out =~ version\ \"1\.([0-9]+)\. ]]; then
    # Legacy style: 1.<major>.0_... => major = captured group
    JAVA_MAJOR="${BASH_REMATCH[1]}"
  elif [[ $out =~ version\ \"([0-9]+) ]]; then
    JAVA_MAJOR="${BASH_REMATCH[1]}"
  elif [[ $out =~ "([0-9]+)(\.[0-9]+)*" ]]; then
    JAVA_MAJOR="${BASH_REMATCH[1]}"
  fi
  if [[ -z $JAVA_MAJOR ]]; then
    log_note "${YELLOW}Warning:${RESET} Unable to determine Java major version from: $out"
  elif [[ $JAVA_MAJOR -lt 21 ]]; then
    log_note "${YELLOW}Note:${RESET} Detected Java major version $JAVA_MAJOR (<21). Behavior / precedence could differ from newer specs."
  fi
}

create_temp_dir() {
  WORKDIR="$(mktemp -d 2>/dev/null || mktemp -d -t jvmopts)"
  trap 'cleanup' EXIT
}

cleanup() {
  if $KEEP_TEMP; then
    say "Keeping temp dir: $WORKDIR"
  else
    [[ -n "${WORKDIR:-}" && -d $WORKDIR ]] && rm -rf "$WORKDIR"
  fi
}

compile_test_class() {
  cat > "$WORKDIR/Test.java" <<EOF
public class Test {
  public static void main(String[] args) {
    System.out.println("${PROPERTY_KEY}=" + System.getProperty("${PROPERTY_KEY}"));
  }
}
EOF
  # For Java <11 we must compile (source-file launch unsupported)
  if [[ -n $JAVA_MAJOR && $JAVA_MAJOR -lt 11 ]]; then
    javac "$WORKDIR/Test.java"
  fi
}

RUN_CMD=() # populated after compilation

set_run_cmd() {
  if [[ -z "${WORKDIR:-}" ]]; then
    say_err "Internal error: WORKDIR not set before set_run_cmd"; exit 1
  fi
  if [[ -n $JAVA_MAJOR && $JAVA_MAJOR -lt 11 ]]; then
    RUN_CMD=(java -cp "$WORKDIR" Test)
  else
    RUN_CMD=(java "$WORKDIR/Test.java")
  fi
}

# Runs java with two env vars set: A and B.
# Each sets -Dfoo to a unique tag so we can see which one wins.
# Prints the winner name and returns 0.
# Usage: test_pair _JAVA_OPTIONS JAVA_TOOL_OPTIONS
test_pair() {
  local A="$1" B="$2"
  local aval="from-${A}" bval="from-${B}"
  local out val

  out="$(env \
      "${A}=-D${PROPERTY_KEY}=${aval}" \
      "${B}=-D${PROPERTY_KEY}=${bval}" \
      "${RUN_CMD[@]}" 2>&1 || true)"

  val="$(printf '%s\n' "$out" | awk -F'=' -v k="${PROPERTY_KEY}" '$0 ~ "^"k"=" {print $2; exit}')"

  if [[ -z "${val:-}" ]]; then
    say "${YELLOW}WARN:${RESET} Could not detect winner for pair ${A} vs ${B}.";
    $QUIET || printf '%s\n' "$out"
    echo "unknown"; return 0
  fi
  if [[ "$val" == "$aval" ]]; then echo "$A"; return 0; fi
  if [[ "$val" == "$bval" ]]; then echo "$B"; return 0; fi
  say "${YELLOW}WARN:${RESET} Unexpected value for ${PROPERTY_KEY}: $val"; echo "unknown"
}

# Topological sort for 3 items using pairwise wins.
# Input: three lines like "A>B"
# Output: final order or "inconclusive"
rank_three() {
  local edges=("$@")
  local -A wins
  for v in "${ENV_VARS[@]}"; do wins[$v]=0; done

  local known_edges=()
  for e in "${edges[@]}"; do
    [[ $e == unknown ]] && continue
    known_edges+=( "$e" )
    local L="${e%%>*}" R="${e##*>}"
    (( wins[$L]++ )) || true
  done

  # If we have fewer than 2 known edges we cannot fully rank reliably
  local order
  order=$(for v in "${ENV_VARS[@]}"; do printf '%s %d\n' "$v" "${wins[$v]}"; done | sort -k2,2nr | awk '{print $1}')

  # Detect cycle: for 3 nodes a cycle would mean each wins exactly once
  local w1=${wins[_JAVA_OPTIONS]} w2=${wins[JAVA_TOOL_OPTIONS]} w3=${wins[JDK_JAVA_OPTIONS]}
  local cycle=false
  if [[ $w1 -eq 1 && $w2 -eq 1 && $w3 -eq 1 ]]; then cycle=true; fi

  # Incomplete if <3 comparisons succeeded or cycle detected
  if $cycle || [[ ${#known_edges[@]} -lt 2 ]]; then
    echo "inconclusive"
  else
    printf '%s\n' $order
  fi
}

# ---------- main ----------
main() {
  parse_args "$@"
  require_java
  create_temp_dir
  compile_test_class
  set_run_cmd

  hr; say "Testing property key: ${BOLD}${PROPERTY_KEY}${RESET}"; hr
  $QUIET || say "Pairwise tests (two variables at a time):"

  w1="$(test_pair _JAVA_OPTIONS JAVA_TOOL_OPTIONS)"; $QUIET || say "_JAVA_OPTIONS vs JAVA_TOOL_OPTIONS -> winner: ${w1}"
  w2="$(test_pair _JAVA_OPTIONS JDK_JAVA_OPTIONS)"; $QUIET || say "_JAVA_OPTIONS vs JDK_JAVA_OPTIONS -> winner: ${w2}"
  w3="$(test_pair JAVA_TOOL_OPTIONS JDK_JAVA_OPTIONS)"; $QUIET || say "JAVA_TOOL_OPTIONS vs JDK_JAVA_OPTIONS -> winner: ${w3}"

  edges=()
  if [[ "$w1" == "_JAVA_OPTIONS" ]]; then edges+=("_JAVA_OPTIONS>JAVA_TOOL_OPTIONS")
  elif [[ "$w1" == "JAVA_TOOL_OPTIONS" ]]; then edges+=("JAVA_TOOL_OPTIONS>_JAVA_OPTIONS")
  else edges+=("unknown"); fi

  if [[ "$w2" == "_JAVA_OPTIONS" ]]; then edges+=("_JAVA_OPTIONS>JDK_JAVA_OPTIONS")
  elif [[ "$w2" == "JDK_JAVA_OPTIONS" ]]; then edges+=("JDK_JAVA_OPTIONS>_JAVA_OPTIONS")
  else edges+=("unknown"); fi

  if [[ "$w3" == "JAVA_TOOL_OPTIONS" ]]; then edges+=("JAVA_TOOL_OPTIONS>JDK_JAVA_OPTIONS")
  elif [[ "$w3" == "JDK_JAVA_OPTIONS" ]]; then edges+=("JDK_JAVA_OPTIONS>JAVA_TOOL_OPTIONS")
  else edges+=("unknown"); fi

  order_raw="$(rank_three "${edges[@]}")"
  IFS=$'\n' read -r -d '' -a order_array < <(printf '%s\0' "$order_raw") || true

  local status="ok"; local sanity_value=""; local expected_top="${order_array[0]:-inconclusive}"; local mismatch=false

  if [[ "$order_raw" == "inconclusive" ]]; then status="inconclusive"; fi

  if $SANITY; then
    out_all="$(env \
      _JAVA_OPTIONS="-D${PROPERTY_KEY}=from-_JAVA_OPTIONS" \
      JAVA_TOOL_OPTIONS="-D${PROPERTY_KEY}=from-JAVA_TOOL_OPTIONS" \
      JDK_JAVA_OPTIONS="-D${PROPERTY_KEY}=from-JDK_JAVA_OPTIONS" \
      "${RUN_CMD[@]}" 2>&1 || true)"
    sanity_value="$(printf '%s\n' "$out_all" | awk -F'=' -v k="${PROPERTY_KEY}" '$0 ~ "^"k"=" {print $2; exit}')"
    if [[ -n $sanity_value && $expected_top != inconclusive ]]; then
      case "$sanity_value" in
        from-${expected_top}) ;; # matches top predicted
        *) mismatch=true; status="mismatch" ;;
      esac
    fi
  fi

  if $OUTPUT_JSON; then
    # Build JSON manually (simple, controlled strings)
    printf '{"property":"%s","pairwise":{' "$PROPERTY_KEY"
    printf '"_JAVA_OPTIONS_vs_JAVA_TOOL_OPTIONS":"%s",' "$w1"
    printf '"_JAVA_OPTIONS_vs_JDK_JAVA_OPTIONS":"%s",' "$w2"
    printf '"JAVA_TOOL_OPTIONS_vs_JDK_JAVA_OPTIONS":"%s"},' "$w3"
    printf '"edges":["%s","%s","%s"],' "${edges[0]}" "${edges[1]}" "${edges[2]}"
    if [[ "$order_raw" == "inconclusive" ]]; then
      printf '"order":null,'
    else
      printf '"order":["%s","%s","%s"],' "${order_array[0]}" "${order_array[1]}" "${order_array[2]}"
    fi
    if $SANITY; then
      local sanitized_raw
      sanitized_raw=$(escape_json "$out_all")
      printf '"sanity":{"raw":"%s","value":"%s"},' "$sanitized_raw" "$sanity_value"
    else
      printf '"sanity":null,'
    fi
    printf '"status":"%s"}\n' "$status"
  else
    hr; say "Edges inferred:"; $QUIET || printf '%s\n' "${edges[@]}"
    hr; say "Final precedence order (highest first):"
    if [[ "$order_raw" == "inconclusive" ]]; then
      say "${YELLOW}Inconclusive ordering (cycle or insufficient data).${RESET}"
    else
      printf '1) %s\n2) %s\n3) %s\n' "${order_array[0]}" "${order_array[1]}" "${order_array[2]}"
      # Pretty precedence chain
      local chain
      chain="${order_array[0]} > ${order_array[1]} > ${order_array[2]}"
      hr
      say "${BOLD}Precedence chain:${RESET} ${GREEN}${chain}${RESET}"
      say
      say "Meaning: When the same -D${PROPERTY_KEY}=... is supplied via multiple env vars, the leftmost one above wins (overrides) the ones to its right."
      say
      # Pairwise table
      printf '%s\n' "Pairwise outcomes:"; printf '%s\n' "---------------------------------------------"
      printf '%-38s %s\n' "_JAVA_OPTIONS vs JAVA_TOOL_OPTIONS" "$w1"
      printf '%-38s %s\n' "_JAVA_OPTIONS vs JDK_JAVA_OPTIONS" "$w2"
      printf '%-38s %s\n' "JAVA_TOOL_OPTIONS vs JDK_JAVA_OPTIONS" "$w3"
      printf '%s\n' "---------------------------------------------"
      # Reasoning explanation
      say
      say "Explanation:" 
      if [[ "$w1" == "_JAVA_OPTIONS" && "$w2" == "_JAVA_OPTIONS" && "$w3" == "JAVA_TOOL_OPTIONS" ]]; then
        say "_JAVA_OPTIONS beats both others, so it is highest. JAVA_TOOL_OPTIONS beats JDK_JAVA_OPTIONS, so JAVA_TOOL_OPTIONS is second, leaving JDK_JAVA_OPTIONS third." 
      else
        say "Ranking derived by counting pairwise wins; each environment variable's position reflects how many other variables it overrode." 
      fi
    fi
    if $SANITY; then
      hr; say "Sanity check with all three set:"; $QUIET || printf '%s\n' "$out_all"
      if $mismatch; then
        say "${RED}WARNING:${RESET} Sanity run favored value ${sanity_value}, which doesn't match predicted top: ${expected_top}";
      else
        [[ -n $sanity_value && $expected_top != inconclusive ]] && say "${GREEN}Sanity matches predicted top (${expected_top}).${RESET}" || true
      fi
    fi
  fi
}

main "$@"