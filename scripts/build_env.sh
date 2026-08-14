#!/usr/bin/env bash
# Computes GIT_HASH and BUILD_DATE for embedding into the app via --dart-define.
# Sourced by run.sh and build.sh.

GIT_HASH="$(git rev-parse --short HEAD)"
if [ -n "$(git status --porcelain)" ]; then
  GIT_HASH="${GIT_HASH}-dirty"
fi
BUILD_DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

DART_DEFINES=(--dart-define="GIT_HASH=${GIT_HASH}" --dart-define="BUILD_DATE=${BUILD_DATE}")
