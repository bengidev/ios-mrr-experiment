#!/bin/sh

set -eu

REPO_ROOT="$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)"

git -C "$REPO_ROOT" config core.hooksPath .githooks

echo "Git hooks configured to use $REPO_ROOT/.githooks"
