# Version Display in Settings

Date: 2026-08-14

## Problem

The user runs RunLog on a device and, over time, loses track of which build/commit is actually installed. There's no way to check from within the app which version of the code is running.

## Goal

Show the git commit hash and build timestamp in the Settings screen, so the user can confirm which build is on a device at a glance.

## Design

### Build-time injection

Git info isn't available at runtime in a compiled Flutter app, so it must be baked in at build time via `--dart-define`.

- `scripts/build_env.sh`: a shared shell snippet that computes
  - `GIT_HASH` — `git rev-parse --short HEAD`, with `-dirty` appended if `git status --porcelain` is non-empty
  - `BUILD_DATE` — current UTC timestamp, ISO-8601 (`date -u +%Y-%m-%dT%H:%M:%SZ`)
- `scripts/run.sh` and `scripts/build.sh` source `build_env.sh` and call `flutter run` / `flutter build "$@"` with:
  ```
  --dart-define=GIT_HASH=$GIT_HASH --dart-define=BUILD_DATE=$BUILD_DATE
  ```
- `devbox.json` gains a new `run` script that calls `scripts/run.sh` (no arguments needed). `scripts/build.sh` is invoked directly as `devbox run -- bash scripts/build.sh <platform>` rather than as a named devbox script, since devbox's generated script wrappers don't forward extra CLI arguments to the script body — a named `build` script could never receive the platform argument. Existing `test` and `analyze` scripts are unchanged.
- IDE "Run" buttons (Android Studio, VS Code) and plain `flutter run`/`flutter build` bypass these wrapper scripts entirely, so the app will show `Version unknown · built unknown` when launched that way, unless the IDE wiring below is set up.

### IDE wiring (Android Studio)

Android Studio's Flutter run configuration doesn't invoke `scripts/run.sh`, so it needs its own path to fresh values:

- `scripts/gen_version_json.sh` sources `build_env.sh` and writes `version.dartdefine.json` (checked into git with `"unknown"` placeholders, so a fresh clone's Run button doesn't hard-error before the tool has run once — `flutter run --dart-define-from-file=<missing file>` errors rather than degrading).
- The Flutter run configuration's "Additional run args" is set to `--dart-define-from-file=version.dartdefine.json`, with a "Before launch: Run External tool" step that re-runs `scripts/gen_version_json.sh` on every Run, keeping the file fresh (including the `-dirty` suffix).
- This wiring lives in `.idea/runConfigurations/main_dart.xml`, which is gitignored (machine-local IDE state) — each developer sets it up once via Run > Edit Configurations…, documented in the README. It is not committed or scripted, since IntelliJ's before-launch/external-tool XML schema isn't safe to hand-write blind and risks corrupting the run config if the field names are wrong.

### App code

- `lib/version.dart`: two constants read via `String.fromEnvironment`:
  ```dart
  const String gitHash = String.fromEnvironment('GIT_HASH', defaultValue: 'unknown');
  const String buildDate = String.fromEnvironment('BUILD_DATE', defaultValue: 'unknown');
  ```
  Defaulting to `"unknown"` means a plain `flutter run` (bypassing the wrapper script) still works, just without version info — no crash, no build failure.

- `lib/tabs/settings/settings.dart`: new "About" section added below the existing "Backups" section, showing:
  ```
  About
  Version abc1234-dirty · built 2026-08-14 21:10
  ```
  The build date is parsed from the ISO-8601 string and formatted with `intl`'s `DateFormat('yyyy-MM-dd HH:mm')`, matching the existing backup-timestamp style. If parsing fails (e.g. `"unknown"`), show the raw string as a fallback.

### Out of scope

- No `package_info_plus` dependency — pubspec version/build number isn't shown, only git hash + build time, per the user's decision.
- No CI wiring — this is a single-developer local-build workflow.
- No dirty-diff detail beyond the `-dirty` suffix.

## Testing

This is a thin display of build-time constants; no new unit tests planned. Verification is a manual run via `devbox run run`, checking the Settings > About section shows a real (non-"unknown") hash and timestamp.
