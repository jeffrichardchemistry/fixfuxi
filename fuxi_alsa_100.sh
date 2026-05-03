#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
BASE_SCRIPT="$SCRIPT_DIR/FixFuxiH3.sh"

if [ ! -x "$BASE_SCRIPT" ]; then
    echo "Error: base script not found or not executable: $BASE_SCRIPT" >&2
    exit 1
fi

exec "$BASE_SCRIPT" --volume-only "$@"
