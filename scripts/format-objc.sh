#!/bin/sh

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

if command -v clang-format >/dev/null 2>&1; then
  CLANG_FORMAT_BIN="clang-format"
elif xcrun --find clang-format >/dev/null 2>&1; then
  CLANG_FORMAT_BIN="$(xcrun --find clang-format)"
else
  echo "clang-format is not installed. Install it with: brew install clang-format" >&2
  exit 1
fi

format_file() {
  file_path="$1"
  case "$file_path" in
    *.h|*.m|*.mm)
      "$CLANG_FORMAT_BIN" -i -style=file "$file_path"
      ;;
  esac
}

if [ "$#" -gt 0 ]; then
  for file_path in "$@"; do
    format_file "$file_path"
  done
else
  find "$REPO_ROOT/MRR Project" "$REPO_ROOT/MRR ProjectTests" \
    \( -name '*.h' -o -name '*.m' -o -name '*.mm' \) -print0 |
    while IFS= read -r -d '' file_path; do
      format_file "$file_path"
    done
fi

echo "Objective-C formatting completed with clang-format."
