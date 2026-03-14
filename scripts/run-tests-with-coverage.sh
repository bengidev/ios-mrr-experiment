#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/MRR Project.xcodeproj}"
SCHEME="${SCHEME:-MRR Project}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/ci_artifacts}"
RESULTS_DIR="$ARTIFACTS_DIR/test-results"
COVERAGE_DIR="$ARTIFACTS_DIR/coverage"
DERIVED_DATA_PATH="$ARTIFACTS_DIR/DerivedData"
RESULT_BUNDLE_PATH="$RESULTS_DIR/MRR-Project-Tests.xcresult"
COVERAGE_REPORT_PATH="$COVERAGE_DIR/coverage-report.txt"
COVERAGE_JSON_PATH="$COVERAGE_DIR/coverage-report.json"

declare -a PREFERRED_SIMULATORS=()
if [[ -n "${IOS_SIMULATOR_NAME:-}" ]]; then
  PREFERRED_SIMULATORS+=("${IOS_SIMULATOR_NAME}")
fi
PREFERRED_SIMULATORS+=("iPhone 16e" "iPhone 16" "iPhone 15" "iPhone 14")

mkdir -p "$RESULTS_DIR" "$COVERAGE_DIR"
rm -rf "$DERIVED_DATA_PATH" "$RESULT_BUNDLE_PATH"

find_simulator_name() {
  local destinations_output="" candidate="" fallback=""

  destinations_output="$(xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME" \
    -showdestinations 2>&1 || true)"

  for candidate in "${PREFERRED_SIMULATORS[@]}"; do
    if [[ -n "$candidate" ]] && printf '%s\n' "$destinations_output" | grep -F "name:$candidate" >/dev/null; then
      printf '%s\n' "$candidate"
      return 0
    fi
  done

  fallback="$(printf '%s\n' "$destinations_output" \
    | sed -n 's/.*platform:iOS Simulator[^}]*name:\([^,}]*\).*/\1/p' \
    | sed 's/[[:space:]]*$//' \
    | head -n 1)"

  if [[ -n "$fallback" ]]; then
    printf '%s\n' "$fallback"
    return 0
  fi

  printf 'Unable to find an iOS Simulator destination for scheme "%s".\n' "$SCHEME" >&2
  printf '%s\n' "$destinations_output" >&2
  return 1
}

SIMULATOR_NAME="$(find_simulator_name)"
DESTINATION="platform=iOS Simulator,name=$SIMULATOR_NAME,OS=latest"

printf 'Running tests for scheme "%s" on destination "%s"\n' "$SCHEME" "$DESTINATION"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -destination-timeout 120 \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO \
  clean test

xcrun xccov view --report "$RESULT_BUNDLE_PATH" > "$COVERAGE_REPORT_PATH"
xcrun xccov view --report --json "$RESULT_BUNDLE_PATH" > "$COVERAGE_JSON_PATH"

if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
  {
    printf '## iOS Test Coverage\n\n'
    printf -- '- Scheme: `%s`\n' "$SCHEME"
    printf -- '- Destination: `%s`\n' "$DESTINATION"
    printf -- '- Result bundle: `%s`\n\n' "$RESULT_BUNDLE_PATH"
    printf '```text\n'
    cat "$COVERAGE_REPORT_PATH"
    printf '```\n'
  } >> "$GITHUB_STEP_SUMMARY"
fi

printf 'Coverage report saved to %s\n' "$COVERAGE_REPORT_PATH"
printf 'Coverage JSON saved to %s\n' "$COVERAGE_JSON_PATH"
