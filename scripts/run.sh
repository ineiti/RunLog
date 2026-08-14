#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/build_env.sh
flutter run "${DART_DEFINES[@]}" "$@"
