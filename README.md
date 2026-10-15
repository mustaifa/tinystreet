# Tiny Street: Sort & Restore

*Working title, pending availability checks.*

> Sort deliveries, complete customer orders, and bring a forgotten neighbourhood café back to life.

A portrait, single-player, offline puzzle game for Android, built with **Godot 4.7.2-stable** (GDScript, Compatibility renderer).

**Status:** first-release candidate for **internal testing**. It isn't store-ready. See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) and [TEST_REPORT.md](TEST_REPORT.md).

## What's in the box
- A deterministic sorting puzzle with crates, a counter and up to 3 order trays, plus two-stage orders from level 31.
- **60 campaign levels** and a **60-level daily pool**, all verified solvable by the real solver and shipped with recorded solutions.
- Unlimited free undo, free restart, and a hint computed from the current position.
- Café restoration: 5 visible milestones and 4 cosmetic categories, all earnable without purchases.
- English and Arabic (RTL) UI. The Arabic text is awaiting qualified review.
- Versioned, checksummed, atomic saves with backup recovery. In-progress puzzles survive process death.
- Ads, billing, consent and analytics adapters. Simulated variants exist for development only. Real AdMob test ads and Play Billing are opt-in through an export feature, and **real-money purchasing is disabled**.

## Repository layout
```
game/                    Godot project
  src/core/              pure rules: Rules, PuzzleState, PuzzleSession, Solver, LevelValidator, Scoring
  src/meta/              persistence and progression: SaveStore, GameData, Progression, Restoration
  src/services/          ads, billing, entitlements, rewards, analytics, consent adapters
  src/app/               App autoload, main host, audio, build config, QA driver
  src/board/ src/ui/     drawn widgets (crates, orders, counter, café, product art) and UI kit
  src/screens/           every screen
  data/levels/           campaign.json, daily.json (shipped, fixed)
  data/i18n/             en.json, ar.json
  tests/                 headless test suites (run_tests.gd)
  tools/                 generate_levels.gd (authoring aid), validate_levels.gd (report/inspect)
  addons/tinystreet_monetization/   opt-in export plugin + vendored AARs (MIT)
tools/                   make_audio.py, strings_en.py, strings_ar.py
docs/                    LEVEL_REPORT, PRIVACY, STORE_LISTING, PLAYTEST, screenshots
build/                   exported artifacts (git-ignored)
```

## Prerequisites (pinned)
| Tool | Version |
|---|---|
| Godot editor + export templates | 4.7.2-stable (SHA-512 verified against the official `SHA512-SUMS.txt`) |
| JDK | 21 (Temurin/Microsoft; Godot recommends 17, and 21 works with Gradle 8.11.1) |
| Android SDK | platform-tools, build-tools 36.1.0, platforms;android-36, cmdline-tools latest |
| Python | 3.10+ (only for regenerating audio and strings) |

Set `export/android/android_sdk_path` and `export/android/java_sdk_path` in Godot's editor settings (`~/.config/godot/editor_settings-4.7.tres`).

## Commands
Run these from the repo root (`GODOT` = path to the Godot 4.7.2 binary).
```bash
$GODOT --headless --path game --import                                   # import assets once
$GODOT --headless --path game -s res://tests/run_tests.gd                # all tests
$GODOT --headless --path game -s res://tools/validate_levels.gd          # verify levels, write docs/LEVEL_REPORT.md
$GODOT --headless --path game -s res://tools/validate_levels.gd -- inspect c031
$GODOT --path game                                                       # play on desktop
$GODOT --path game -- --qa=shots --qa-out=/tmp/shots                     # capture screenshots (needs a display)

# Android
$GODOT --headless --path game --export-debug "Android Debug APK" ../build/tinystreet-debug.apk
$GODOT --headless --path game --install-android-build-template \
       --export-release "Android Release AAB" ../build/tinystreet-release-unsigned.aab
$GODOT --headless --path game --install-android-build-template \
       --export-debug "Android Monetization Test APK" ../build/tinystreet-monetization-test.apk
adb install -r build/tinystreet-debug.apk
```
Regenerate content (authoring only): `$GODOT --headless --path game -s res://tools/generate_levels.gd -- campaign 1 60` and `python3 tools/make_audio.py game/assets/audio`.

## Install and play
1. `adb install -r build/tinystreet-debug.apk`. The APK is debug-signed and supports arm64-v8a, armeabi-v7a and x86_64.
2. A first launch goes straight into Level 1 with in-flow tutorial tips.
3. Tap a crate to send its front item to the lowest-numbered order that needs it, or to the counter. Hold a crate to preview where it'll go.

## Docs
[GAME_DESIGN](GAME_DESIGN.md) · [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) · [DECISIONS](DECISIONS.md) · [TEST_REPORT](TEST_REPORT.md) · [RELEASE_CHECKLIST](RELEASE_CHECKLIST.md) · [SESSION_HANDOVER](SESSION_HANDOVER.md) · [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) · [docs/PRIVACY](docs/PRIVACY.md) · [docs/PLAYTEST](docs/PLAYTEST.md) · [docs/STORE_LISTING](docs/STORE_LISTING.md) · [docs/LEVEL_REPORT](docs/LEVEL_REPORT.md)
