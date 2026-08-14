#!/usr/bin/env bash
# Regenerates version.dartdefine.json for IDE run configurations that use
# --dart-define-from-file. Intended to be wired as a "before launch" step
# in Android Studio / IntelliJ, so it re-runs every time you hit Run.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
source scripts/build_env.sh

cat > version.dartdefine.json <<EOF
{
  "GIT_HASH": "${GIT_HASH}",
  "BUILD_DATE": "${BUILD_DATE}"
}
EOF
