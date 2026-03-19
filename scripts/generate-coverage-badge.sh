#!/usr/bin/env bash

set -euo pipefail

if [[ $# -lt 2 ]]; then
  printf 'Usage: %s <coverage-report.json> <output-json> [target-name]\n' "${0##*/}" >&2
  exit 1
fi

COVERAGE_JSON_PATH="$1"
OUTPUT_JSON_PATH="$2"
TARGET_NAME="${3:-MRR Project.app}"

/usr/bin/python3 - "$COVERAGE_JSON_PATH" "$OUTPUT_JSON_PATH" "$TARGET_NAME" <<'PY'
import json
import pathlib
import sys

coverage_path = pathlib.Path(sys.argv[1])
output_path = pathlib.Path(sys.argv[2])
target_name = sys.argv[3]

payload = json.loads(coverage_path.read_text())
targets = payload.get("targets", [])
target = next((item for item in targets if item.get("name") == target_name), None)
if target is None:
    target = next((item for item in targets if item.get("name", "").startswith("MRR Project")), None)
if target is None:
    target = payload

line_coverage = float(target.get("lineCoverage", 0.0))
percentage = max(0.0, min(100.0, line_coverage * 100.0))

if percentage >= 85.0:
    color = "2ea44f"
elif percentage >= 70.0:
    color = "dfb317"
else:
    color = "cb2431"

badge_payload = {
    "schemaVersion": 1,
    "label": "coverage",
    "message": f"{percentage:.2f}%",
    "color": color,
}

output_path.parent.mkdir(parents=True, exist_ok=True)
output_path.write_text(json.dumps(badge_payload, indent=2) + "\n")
PY
