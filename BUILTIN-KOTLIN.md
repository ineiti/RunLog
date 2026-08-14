# Built-in Kotlin Migration Status

Tracking readiness for Flutter's built-in Kotlin migration
(https://docs.flutter.dev/release/breaking-changes/migrate-to-built-in-kotlin/for-app-developers).

Last checked: 2026-08-14.

## What this migration requires

Flutter 3.47+ moves Android projects from the separate Kotlin Gradle Plugin (KGP)
to Kotlin built into AGP 9.0+. A plugin is compatible if it:

1. Does **not** apply `kotlin-android` (aka `org.jetbrains.kotlin.android`)
2. Uses the `kotlin.compilerOptions{}` DSL instead of the legacy `kotlinOptions{}` block
3. Works with AGP 9.0.0+

## App module status: not migrated

- `android/settings.gradle.kts` pins AGP `8.11.1` (need >= 9.0.0)
- `android/app/build.gradle.kts` still applies `id("kotlin-android")` and uses the
  legacy `kotlinOptions{}` block

These need to be fixed regardless of plugin status.

## Plugin status (as currently pinned in pubspec.yaml)

| Plugin | Status | Notes |
|---|---|---|
| `geolocator` (`geolocator_android` 5.0.1+1) | Compatible | No KGP plugin applied |
| `path_provider` (`path_provider_android` 2.2.17) | Compatible | |
| `sqflite` / `sqflite_common_ffi` (`sqflite_android` 2.4.1) | Compatible | |
| `file_picker` (permission_handler/url_launcher deps) | Compatible | |
| `flutter_map` | N/A | Pure Dart, no Android code |
| `flutter_pcm_sound` 3.1.7 | Compatible | No KGP applied in build.gradle |
| `audio_session` 0.2.2 (currently pinned) | **Not compatible** | Applies `kotlin-android` unconditionally |
| `audio_session` 0.2.4 (latest) | **Fix available** | Guards the KGP apply behind `if (agpMajor < 9)` — bump the pin |
| `shared_preferences` (`shared_preferences_android`, latest cached 2.4.23) | **Not compatible** | Still unconditionally applies `kotlin-android`, even in the newest release — no fix published yet |
| `flutter_tts` 4.2.3 (latest 4.2.5) | **Not compatible** | Changelog shows only AGP-version bumps, no KGP removal |
| `flutter_osm_plugin` 1.3.8 (latest published) | **Not compatible** | Applies `kotlin-android`; changelog shows no migration |
| `receive_sharing_intent` (pinned git commit `2cea396`) | **Not compatible** (pinned commit) | Pinned commit uses AGP 7.3.1 + `kotlin-android`. Upstream `master` has since migrated (conditional KGP apply guarded by AGP version + `compilerOptions`) — repointing the git `ref` would likely fix this one |

## Action items to become build-in-Kotlin ready

1. Upgrade AGP to 9.0+ in `android/settings.gradle.kts`
2. Remove `id("kotlin-android")` and migrate `kotlinOptions` to `kotlin.compilerOptions{}`
   in `android/app/build.gradle.kts`
3. Bump `audio_session` to `^0.2.4`
4. Update the `receive_sharing_intent` git `ref` to a newer commit on `master`
5. Wait on (or fork/patch) `shared_preferences`, `flutter_tts`, and `flutter_osm_plugin` —
   no migrated release exists yet as of this check
6. Once all plugins are fixed, set `android.builtInKotlin=true` in `android/gradle.properties`
   and verify with `flutter run` / `flutter build apk`
