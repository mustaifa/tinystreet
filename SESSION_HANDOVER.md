# Session Handover

**Last updated:** 2026-10-16, end of session 2 (v2 / 0.2.0).

## State
- v1 had a real-phone smoke test from the owner: it installs and renders, but "feels very basic". v2 answers that: core feel, three new mechanics, an interior café with 8 visible steps and decor choices, a cast and story beats, Journal (tasks, awards, progress), and Challenges (Daily + Café Rush). See `CHANGELOG.md` and `docs/V2_PLAN.md`.
- **81/81 tests pass. 144/144 levels validated** (84 campaign + 60 daily). Desktop QA under Xvfb: all 84 levels won through real input; v2 flows 10/10, nav 17/17, rewards 8/8, rapid, lifecycle and layouts pass. Details in `TEST_REPORT.md`.
- **APK: `build/tinystreet-v2-debug.apk`**, debug-signed, versionCode 2 / 0.2.0, built from commit `4bef623`. SHA-256 `f2177a1f994eb688d3c8e2065a735b7cf2d726de1ed51c91036c976bebf087f8` (also in `build/SHA256SUMS.txt`). **Not run on Android.** The v1 APK `build/tinystreet-debug.apk` is kept for comparison.
- The release AAB and monetisation test APK in `build/` are still **v1** builds. Rebuild them (Gradle presets) before any store or monetisation test.
- Git: `main` is pushed to GitHub up to the v1 commits. The v2 commits are local until pushed. `build/` is git-ignored.

## Where things are (v2)
| Topic | Files |
|---|---|
| Mechanics (fresh `x!`, bag `?x`, `locks`) | `game/src/core/rules.gd`, `level_def.gd`; tests `tests/test_mechanics.gd` |
| Level authoring | `game/tools/generate_levels.gd` (`ORDER`, `CHAPTERS`, `HAND`, `mech_tier`; mode `ids f02 c025 …`) |
| Validation | `LevelValidator.mechanic_engagement` + `tools/validate_levels.gd` (writes `docs/LEVEL_REPORT.md` in play order) |
| Economy | `src/meta/wallet.gd` (ledger), `restoration.gd`, `tasks.gd`, `achievements.gd`, `meta.gd` (stats on win) |
| Café art | `src/board/cafe_view.gd`; cast `src/ui/character_art.gd`; story `src/meta/story.gd` + `src/ui/speech_bubble.gd` |
| Game feel | `src/screens/game_screen.gd`, `src/board/crate_view.gd`, `order_card.gd`, `backdrop.gd`, `src/ui/fx.gd` |
| Save | `SaveStore.SCHEMA = 3`, `migrate_v2_to_v3` (frozen v2 cost table) |
| Strings | `tools/strings_en.py`, `tools/strings_ar.py` → `python3 tools/build_i18n.py` (checks keys and `%s` parity) |
| Audio | `python3 tools/make_audio.py game/assets/audio` (music loop is set in `music_cafe.wav.import`) |

## Environment (this codespace)
| What | Where |
|---|---|
| Godot 4.7.2 | `~/tools/godot/godot`; templates in `~/.local/share/godot/export_templates/4.7.2.stable` (Android only) |
| Android SDK | `~/tools/android-sdk` (build-tools 36.1.0, platform 36). NDK removed. |
| JDK | `/usr/local/sdkman/candidates/java/21.0.12+1-ms` |
| AVD | `ts36`. **Unusable here** (no KVM; see `docs/EMULATOR_TEST_2026-10-16.md`). Don't retry unless the environment changes. |
| Disk | ~4 GB free |

## Commands
```bash
G=~/tools/godot/godot
$G --headless --path game --import
$G --headless --path game -s res://tests/run_tests.gd                 # expect 81 passed
$G --headless --path game -s res://tools/validate_levels.gd           # expect levels=144 failed=0
xvfb-run -a $G --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=v2 --save-path=user://qa.json
#   other scenarios: shots, cafe, play=1-84, nav, rewards, rapid, layouts, lifecycle_a/b
#   use a fresh --save-path per run so earlier QA saves don't leak in
cd game && $G --headless --path . --export-debug "Android Debug APK" ../build/tinystreet-v2-debug.apk
```

## Gotchas learned
- Godot 4.7 treats Variant-inferred `:=` as an error by default (downgraded to a warning here); still type Dictionary reads.
- A `var ready` on a Control collides with the `ready` signal. `tests/test_scripts.gd` now compiles every script, so such errors fail headless.
- `pkill -f pattern` kills your own shell if the same command line contains the pattern. Run it as a separate command.
- Story bubbles are overlays: QA that taps right after entering a level must close overlays first (`play` and `nav` do).
- Hints run on `WorkerThreadPool`. The game screen waits for the task in `_exit_tree` (an abort at shutdown was seen once before that fix).

## Next tasks (in order)
1. **Install `build/tinystreet-v2-debug.apk` over v1 on the phone** (tests save migration), then run the 10–15 min session in `docs/PLAYTEST.md` and answer its questions.
2. Tune from that data: level curve (watch #7, #22, #34, #45, #58, #62, #77), token pace, star thresholds, and how busy the effects feel. Regenerate with `generate_levels.gd -- ids …`, then re-validate.
3. Rebuild the release AAB and the monetisation test APK from v2 if a store or monetisation test is next.
4. Qualified Arabic review (≈200 new v2 strings, marked awaiting review).
5. Publisher items in `RELEASE_CHECKLIST.md` (package id, upload key, privacy URL, store forms). Purchase verification server is still not built; `REAL_PURCHASES_ENABLED` stays false.
6. Art and audio pass by specialists (café, portraits, music), if the playtest says the style works.
