#!/usr/bin/env bash
# Usage: build.sh <platform> [flutter build flags...]
# e.g. build.sh macos --debug
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
if [ "$#" -lt 1 ]; then
  echo "Usage: build.sh <platform> [flutter build flags...]" >&2
  exit 1
fi
source scripts/build_env.sh
platform="$1"
shift
flutter build "$platform" "${DART_DEFINES[@]}" "$@"
