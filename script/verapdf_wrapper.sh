#!/bin/sh
set -eu

BASE_DIR="$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)"
export JAVA_HOME="$BASE_DIR/jre"
exec "$BASE_DIR/verapdf-app/verapdf" "$@"
