# Session Handover

**Last updated:** 2026-10-15, end of session 1.

## State
- The first-release scope is implemented: all 6 stages A–F (see IMPLEMENTATION_PLAN.md). 50/50 tests pass, and 120/120 levels are validated.
- Artifacts are in `build/` (git-ignored; checksums in `build/SHA256SUMS.txt`): a debug-signed APK, an **unsigned** release AAB, and a debug-signed monetisation test APK.
- Git: all work is committed on `main`, locally only (never pushed).

## Environment (this codespace)
| What | Where |
|---|---|
| Godot 4.7.2 | `~/tools/godot/godot`; templates in `~/.local/share/godot/export_templates/4.7.2.stable` (Android only; others deleted for space) |
| Android SDK | `~/tools/android-sdk` (build-tools 36.1.0/35.0.1, platform 36, emulator, system image android-36 google_apis x86_64). **NDK removed** (disk). |
| JDK | `/usr/local/sdkman/candidates/java/21.0.12+1-ms` (set in `~/.config/godot/editor_settings-4.7.tres`) |
| AVD | `ts36` (Pixel 5). Unusable here: no KVM access for this user, so it runs under TCG and system_server crashes during install (2026-10-16, see `build/test-results-emulator/RESULTS.md`). Use `adb install --no-incremental` (a `.idsig` next to the APK triggers a stalling incremental install). |
| Plugin archives | `~/tools/dl/plugins/` (SHA-256 values in THIRD_PARTY_NOTICES) |
| Disk | ~8 GB free after cleanup. Emulator data needs ~7.4 GB. |

## Commands
```bash
G=~/tools/godot/godot
$G --headless --path game --import
$G --headless --path game -s res://tests/run_tests.gd                 # expect 50 passed
$G --headless --path game -s res://tools/validate_levels.gd           # expect 120 PASSED
xvfb-run -a $G --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=play=1-10   # also: shots, rapid, nav, rewards, layouts, lifecycle_a/b
$G --headless --path game --install-android-build-template --export-debug "Android Debug APK" ../build/tinystreet-debug.apk
```

## Gotchas learned
- Godot 4.7 treats Variant-inferred `:=` as an error by default. The project downgrades it to a warning; still type Dictionary reads explicitly.
- `OS.low_processor_usage_mode` stops frames when idle. The QA driver disables it before capturing.
- QA synthetic input must convert canvas → window coordinates (`root.get_final_transform()`).
- Processes started inside a tool call can be cleaned up when the call ends. The emulator also powered itself off about 45 s after boot in later sessions.
- `pkill -f <pattern>` can match its own shell. Use `[x]`-style bracket patterns.

## Next tasks (in order)
1. **Install `build/tinystreet-debug.apk` on a real phone.** First confirm it renders (the SwiftShader canvas-shader failure must not reproduce on hardware), then run `docs/PLAYTEST.md`.
2. Tune the difficulty spikes (c025, c034, c048, c057) after playtests. Regenerate with `generate_levels.gd -- campaign N N`, then re-validate.
3. Get a qualified Arabic review and update `tools/strings_ar.py` → `game/data/i18n/ar.json`.
4. Publisher items in RELEASE_CHECKLIST (package id, upload key, privacy URL, store forms).
5. Optional: verify the monetisation build on a Play-services device; build the purchase verification backend.
