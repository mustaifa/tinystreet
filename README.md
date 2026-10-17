# Tiny Street: Sort & Restore

*Working title, pending availability checks.*

> Sort deliveries, complete customer orders, and bring a forgotten neighbourhood café back to life.

A portrait, single-player, offline puzzle game for Android, built with **Godot 4.7.2-stable** (GDScript, Compatibility renderer).

**Status:** first-release candidate for **internal testing**. It isn't store-ready. See [RELEASE_CHECKLIST.md](RELEASE_CHECKLIST.md) and [TEST_REPORT.md](TEST_REPORT.md).

## What's in the box (v8, 0.8.1): Delivery Logic
The core puzzle was rebuilt in v8. A courier pushes picture-marked crates
(coffee, croissant, strawberry, tea) onto matching pads in small storerooms:
no pulling, no double pushes, wrong pads don't count, and wrong pushes can trap
crates for good. *"Delivery Logic" is an internal working title.*
- **30 puzzles** in 7 chapters, each with a proved minimum push count, a
  verified mistake that leads to a proven dead end, and design notes
  ([docs/DELIVERY_LEVEL_REPORT.md](docs/DELIVERY_LEVEL_REPORT.md)).
- Rules: [docs/DELIVERY_RULES.md](docs/DELIVERY_RULES.md) (one module:
  `game/src/core/delivery_rules.gd`). Design and audit:
  [docs/DELIVERY_DESIGN.md](docs/DELIVERY_DESIGN.md). Player guide:
  [docs/DELIVERY_PLAYER_GUIDE.md](docs/DELIVERY_PLAYER_GUIDE.md). Three-minute
  smoke test and QA access: [docs/DELIVERY_SMOKE_TEST.md](docs/DELIVERY_SMOKE_TEST.md).
- Proven "Route blocked" explanations with Undo/Restart, three-tier hints,
  "Puzzle Solved!" card with pushes and steps, completion reward paid once,
  personal bests and medals; café restoration unchanged.
- Touch (swipe, arrow keys on screen, tap-to-walk), keyboard and game pad:
  every key takes focus with a visible ring, Escape/B is Back (0.8.1).
- Android APK, plus a **Web** build and a separate **Web QA** build.
- The v1–v7 sorting game is retired from the main flow but kept in the source
  (description below), with players' records preserved.

## What was in the box before v8 (v3, 0.3.0, sorting mode)
- A deterministic sorting puzzle with crates, a counter and up to 3 order tickets. Mechanics: the **bell** (choose which customer is served first), fresh items, paper bags, delivery locks, two-part and special orders.
- **96 campaign levels** in 7 chapters, **8 bakery levels**, a **60-level daily pool** and 12 challenge cards. All are proven solvable by the real solver and shipped with recorded solutions; bell claims are proven by search.
- Unlimited free undo, free restart, and a hint that is the first action of a real solution from the current position.
- A living café: 8 visible restoration steps, décor themes with preview, extras, walk-in customers, a cast of three, and a second destination (Mira's Bakery).
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
Regenerate content (authoring only): `$GODOT --headless --path game -s res://tools/generate_levels.gd -- ids p02 c025 …` (bakery: `-- ids m02 …`), `python3 tools/make_audio.py game/assets/audio` and `python3 tools/build_i18n.py`.

## Install and play
1. `adb install -r build/tinystreet-debug.apk`. The APK is debug-signed and supports arm64-v8a, armeabi-v7a and x86_64.
2. A first launch goes straight into Level 1 with in-flow tutorial tips.
3. Tap a crate to send its front item to the lowest-numbered order that needs it, or to the counter. Hold a crate to preview where it'll go.

## Docs
[GAME_DESIGN](GAME_DESIGN.md) · [IMPLEMENTATION_PLAN](IMPLEMENTATION_PLAN.md) · [DECISIONS](DECISIONS.md) · [TEST_REPORT](TEST_REPORT.md) · [RELEASE_CHECKLIST](RELEASE_CHECKLIST.md) · [SESSION_HANDOVER](SESSION_HANDOVER.md) · [THIRD_PARTY_NOTICES](THIRD_PARTY_NOTICES.md) · [docs/PRIVACY](docs/PRIVACY.md) · [docs/PLAYTEST](docs/PLAYTEST.md) · [docs/STORE_LISTING](docs/STORE_LISTING.md) · [docs/LEVEL_REPORT](docs/LEVEL_REPORT.md) · [docs/ECONOMY](docs/ECONOMY.md) · [CHANGELOG](CHANGELOG.md)

## Artifacts
Current builds and checksums are listed in [SESSION_HANDOVER](SESSION_HANDOVER.md) and `build/SHA256SUMS.txt`. The table below records the first (v1) build.

### Session 1 build (2026-10-15)
| File | Signing | SHA-256 |
|---|---|---|
| `build/tinystreet-debug.apk` (87.5 MB, debug engine, 3 ABIs) | **Debug key** (Godot auto-generated, local). Not for store upload. | `61a7b72a7ef0e859c45bfa917f022662f7d1c157c9be2994fc69e022d560e9de` |
| `build/tinystreet-release-unsigned.aab` (53.6 MB, arm64 + armv7) | **Unsigned.** Needs the publisher's upload key. | `f9e161919df7ab6c18eaf9f7a1d666dbdb3ccebb684601d65238bc52bf2163ea` |
| `build/tinystreet-monetization-test.apk` (172 MB, debug) | **Debug key.** Google **test** ad IDs only. | `7446623f03526bf16efb5f5953d42d6769bd1c1172c714b20d6c7003a3631514` |

Rebuilding changes these hashes, because the exports aren't byte-reproducible (timestamps and signing).
