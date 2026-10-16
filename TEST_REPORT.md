# Test Report

## v2 (0.2.0), 2026-10-16
Environment unchanged: GitHub Codespace, 2 vCPU / 7.8 GB, **no GPU, no KVM**. Rendering checks ran in a **desktop Linux build** under Xvfb with Mesa llvmpipe (software GL). **None of this is Android runtime verification.** The emulator was not retried, because the environment hasn't changed since the 2026-10-16 failure (`docs/EMULATOR_TEST_2026-10-16.md`).

| Check | Command | Result |
|---|---|---|
| Unit/integration tests | `godot --headless --path game -s res://tests/run_tests.gd` | **PASS: 81 passed, 0 failed** (v1: 50) |
| Level validation (rules changed) | `godot --headless --path game -s res://tools/validate_levels.gd` | **PASS: 144/144** (84 campaign + 60 daily), 0 UNVERIFIED; includes the new mechanic-engagement check |
| Play every campaign level through real input | QA `play=1-42`, `play=43-84` | **PASS: 84/84 won** via synthetic touch events (recorded solutions) |
| v2 flows through real input | QA `v2` | **PASS 10/10**: fresh item refused + explained; drag to target moves; drag away cancels; pause mid-animation keeps state and clears effects; locked crate refused; k01 solved by taps; double-tap Restore spends once; task claimed once; Café Rush finished and timed |
| Rapid tapping | QA `rapid` (400 taps, undo/restart mixed) | **PASS**: state equals a clean replay; 0 leftover effects |
| Lifecycle | QA `lifecycle_a` → hard kill → `lifecycle_b` | **PASS**: identical state key and undo count after relaunch |
| Android back / navigation | QA `nav` | **PASS 17/17** (now includes skipping a story bubble with Back, and the Journal) |
| Rewarded flows (simulated ads) | QA `rewards` | **PASS 8/8**. One run aborted at shutdown (exit 134) with a hint solve still on the worker pool. Fixed in `4bef623` (the screen waits for its hint task); 3 later runs clean. |
| Layouts | QA `layouts` at 720×1280, 720×1600 + 90 px cutout, 720×1000, large text | **PASS**: no clipped controls; reviewed visually |
| Screens EN + AR | QA `shots`, `cafe` | Reviewed. Fixed during review: Arabic win card overflow, step-0 "bunting" artefact, tile overflow, gramophone overlap, missing `ch_locks` string, game-screen bottom clipping |
| APK | `--export-debug "Android Debug APK"` → `build/tinystreet-v2-debug.apk` | Built; `apksigner verify` OK (v2+v3 schemes, debug key); manifest `com.tinystreet.sortrestore` versionCode 2 / 0.2.0, target/compile SDK 36, only `VIBRATE`; new scripts, levels and QOA music present. **Not run on Android.** |

New test suites: `test_mechanics.gd` (11: markers, fresh/bag/lock rules, undo, solver, validator schema, engagement, session restore), `test_v2_meta.gd` (17: v2→v3 and v1→v3 migration, ledger idempotency, reload safety, double restore, extras, tasks rotation/completability/single claim, stats, awards claim/announce/cosmetics/reachability, Rush, story strings), `test_scripts.gd` (every script compiles). `test_levels.gd` adds mechanic order and spacing, engagement, spike fix and cast frequency checks.

Frame times under software GL averaged 75–93 ms/frame. That is the CPU rasteriser, **not representative of a phone GPU**; real-device frame timing is still unmeasured.

**Not verified:** anything on Android for v2; haptics; real audio output; install-over-v1 migration on a device; fun, pacing and difficulty (no human playtest).

---

# v1 report (0.1.0)

Date: 2026-10-15. Engine: Godot 4.7.2-stable. Environment: GitHub Codespace, Linux x86_64, **2 vCPU / 7.8 GB RAM, no GPU**. Rendering checks used Xvfb with Mesa llvmpipe (software OpenGL 3.3).

Legend: **PASS** · **FAIL** · **PARTIAL** · **NOT RUN**

## 1. Automated unit/integration tests (real game code)
Command: `godot --headless --path game -s res://tests/run_tests.gd`. Result: **50 passed, 0 failed**.

| Suite | Tests | Covers |
|---|---|---|
| `test_rules.gd` | 21 | routing to order or counter; leftmost-tray priority with multiple eligible orders; counter capacity; direct move legal with a full counter (and not a loss); chained automatic resolution; two-stage orders; loss detection; win evaluated before loss; full-state undo (auto transfers, order changes, queue, peak counter, move count); continuation (once, survives undo); session serialisation round-trip; solver SOLVED/UNSOLVABLE/TIMEOUT; hint from the current state after a different route; "undo N" detection; star rules; validator quantity/schema errors; determinism |
| `test_meta.gd` | 24 | save round-trip; fresh install; corrupt main → backup; interrupted save → tmp; all files corrupt → fresh plus notice; tampered payload rejected; v1→v2 migration; type sanitising; first-clear token once and stars never decrease; 60 tokens = total restoration cost; restoration unlock, choices, premium gating, revoke fallback; level unlocking; daily determinism, spread, no double award, no tokens, streak; share text; reward granted only on callback and idempotent (duplicate and late callbacks); cancel/no-fill/offline/timeout/failed grant nothing; disabled ads fail gracefully; purchase states (cancelled, failed, pending→purchased, already owned, revoked); duplicate purchase callbacks and restore; no raw token in analytics; release profile has no simulated services; analytics dedupe and scrub; language switch and persistence, fallback; EN/AR table completeness and placeholder parity |
| `test_levels.gd` | 5 | 60 campaign + ≥30 daily levels exist; every shipped level passes schema, quantity and recorded-solution replay checks; par achievable; unique ids and layouts; two-stage introduced at level 31; solver on a shipped two-stage level |

## 2. Level validation
`godot --headless --path game -s res://tools/validate_levels.gd`. Result: **120 levels, 120 PASSED, 0 FAILED, 0 UNVERIFIED**. This includes an independent solver search (300k-node budget), a min-counter analysis, duplicate and trivial-layout checks, and recorded-solution replay. Report: `docs/LEVEL_REPORT.md`.
**Automated solvability doesn't establish fun or fair difficulty. All levels are AWAITING HUMAN PLAYTEST.**

## 3. Rendered interaction tests (real GUI input events, desktop build under Xvfb)
| Scenario | Result |
|---|---|
| `play=1-10` (milestone B gate): solution taps sent as real mouse/touch events | **PASS**: 10/10 won, 10 tokens |
| `play=1-60` long session (≈4,600 frames, 60 levels in one process) | **PASS**: 60/60 won, 60 tokens, no script errors |
| `rapid`: 400 taps with no frame waits between pairs, mixed undo/restart | **PASS**: final state equals a clean replay of the move log; 0 leftover effect nodes |
| `lifecycle_a/b`: moves + undo → pause notification → **hard process kill** → relaunch | **PASS**: identical state key and undo count restored |
| `nav`: Android back in game, overlays, every screen, exit confirmation, pause→level map, continue | **PASS** (14/14 checks) |
| `rewards`: loss → simulated rewarded continue (cancel = nothing, earn = +1 slot, second refused); free hint; ad-gated hint | **PASS** (8/8 checks) |
| `shots`: every screen in EN and AR at 1080×1920 | **PASS** (visually reviewed; Arabic RTL mirroring and shaping correct) |
| `layouts`: 16:9 (720×1280), 20:9 + simulated 90 px cutout, 4:3, large text | **PASS** after the fix below |

Defects found and fixed during testing:
1. Tutorial bubble covered queued crate items → moved into the layout flow.
2. At 4:3, deep crates hid queued items → items now shrink to fit and are never omitted.
3. Font weights weren't applied (OpenType tag keys) → fixed.
4. Toggle switches nearly invisible → replaced with labelled On/Off buttons.
5. The pause menu's "Level map" went home when the level was started from home → fixed (QA `nav` covers it).
6. Level 31 lacked a two-stage order → generator constraint added and levels 31–60 regenerated.
7. Save sanitiser crashed on nested dictionaries → fixed (tests cover it).

**Frame timing (desktop, software rendering, not representative of a phone):** 60-level run avg 52.5 ms, p95 77 ms, max 181 ms per frame. This measures Mesa llvmpipe on 2 shared vCPUs. **No device frame-timing data exists.**

## 4. Exported builds (inspected, not just editor runs)
| Artifact | Checks | Result |
|---|---|---|
| `tinystreet-debug.apk` | `aapt2 dump badging`: package, versionCode 1, minSdk 24, **targetSdk 36**, permissions = VIBRATE only; ABIs arm64-v8a, armeabi-v7a, x86_64; apksigner verification during export | **PASS** |
| `tinystreet-release-unsigned.aab` | Gradle export completed | **PASS (unsigned)** |
| `tinystreet-monetization-test.apk` | Manifest contains the AdMob test App ID meta-data, the Poing AdMob and Play Billing plugin registrations, and the SDK permissions (INTERNET, AD_ID, BILLING, …) | **PASS** (static inspection only) |

## 5. Android emulator (Android 16 / API 36, google_apis x86_64, Pixel 5 profile, 2 cores, SwiftShader)
| Check | Result |
|---|---|
| Install debug APK | **PASS** |
| App process starts, Godot runs, activity resumed | **PASS** (observed once) |
| Rendering | **FAIL on SwiftShader**: Godot's GLES3 canvas shader failed to link ("Fragment shader active uniforms exceed GL_MAX_FRAGMENT_UNIFORM_VECTORS (261)"), so the screen showed only the cream clear colour. This looks like a SwiftShader limitation, but **it is unconfirmed on real hardware and is the top risk to verify on a device.** |
| ANGLE backend (`swangle_indirect`), lifecycle, back key, memory | **NOT RUN**: subsequent emulator sessions powered off about 45 s after boot (cause unresolved in this environment) |

## 6. Not run / not verifiable here
- **Any real Android device.** No touch latency, frame timing, memory, thermal, haptics, audio output (the desktop used a dummy audio driver), or cutout tests on hardware.
- AdMob rewarded ads, UMP consent and Play Billing on a device: the code paths exist but are **unverified**.
- TalkBack / screen reader. Godot UI isn't exposed to TalkBack in this build; known accessibility gap.
- Offline startup on a device: the default build has no network code or INTERNET permission, so it is offline by construction. The monetisation build's offline behaviour is untested.
- Qualified Arabic language review; human playtests.
