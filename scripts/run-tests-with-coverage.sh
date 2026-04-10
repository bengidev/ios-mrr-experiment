#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_PATH="${PROJECT_PATH:-$ROOT_DIR/MRR Project.xcodeproj}"
SCHEME="${SCHEME:-MRR Project}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-$ROOT_DIR/ci_artifacts}"
RESULTS_DIR="$ARTIFACTS_DIR/test-results"
COVERAGE_DIR="$ARTIFACTS_DIR/coverage"
DERIVED_DATA_ROOT="${DERIVED_DATA_ROOT:-${TMPDIR%/}/ios-mrr-experiment-ci}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$DERIVED_DATA_ROOT/DerivedData}"
CLONED_SOURCE_PACKAGES_DIR_PATH="${CLONED_SOURCE_PACKAGES_DIR_PATH:-$DERIVED_DATA_ROOT/SourcePackages}"
RESULT_BUNDLE_PATH="$RESULTS_DIR/MRR-Project-Tests.xcresult"
COVERAGE_REPORT_PATH="$COVERAGE_DIR/coverage-report.txt"
COVERAGE_JSON_PATH="$COVERAGE_DIR/coverage-report.json"
COBERTURA_XML_PATH="$COVERAGE_DIR/cobertura.xml"

declare -a PREFERRED_SIMULATORS=()
if [[ -n "${IOS_SIMULATOR_NAME:-}" ]]; then
  PREFERRED_SIMULATORS+=("${IOS_SIMULATOR_NAME}")
fi
PREFERRED_SIMULATORS+=("iPhone 16e" "iPhone 16" "iPhone 15" "iPhone 14")
PREFERRED_SIMULATORS=("iPhone 17e" "${PREFERRED_SIMULATORS[@]}")

mkdir -p "$RESULTS_DIR" "$COVERAGE_DIR" "$DERIVED_DATA_ROOT"
rm -rf "$DERIVED_DATA_PATH" "$CLONED_SOURCE_PACKAGES_DIR_PATH" "$RESULT_BUNDLE_PATH"

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
    | grep -v '^Any iOS' \
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
printf 'Using DerivedData at "%s"\n' "$DERIVED_DATA_PATH"

xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -destination "$DESTINATION" \
  -destination-timeout 120 \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  -clonedSourcePackagesDirPath "$CLONED_SOURCE_PACKAGES_DIR_PATH" \
  -resultBundlePath "$RESULT_BUNDLE_PATH" \
  -enableCodeCoverage YES \
  CODE_SIGNING_ALLOWED=NO \
  clean test

xcrun xccov view --report "$RESULT_BUNDLE_PATH" > "$COVERAGE_REPORT_PATH"
xcrun xccov view --report --json "$RESULT_BUNDLE_PATH" > "$COVERAGE_JSON_PATH"
python3 "$ROOT_DIR/scripts/generate-cobertura-from-xccov.py" "$RESULT_BUNDLE_PATH" "$COVERAGE_JSON_PATH" "$COBERTURA_XML_PATH" "${SCHEME}.app" "$ROOT_DIR"

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
printf 'Cobertura XML saved to %s\n' "$COBERTURA_XML_PATH"
