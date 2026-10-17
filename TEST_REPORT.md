# Test Report

## v8.1 (0.8.1), keyboard/pad play, first-run guide, release polish, 2026-10-17
Environment unchanged: GitHub Codespace, **no GPU, no Android device or emulator**. UI checks ran in a desktop Linux build under Xvfb (Mesa software GL) and the Web build in headless Chromium (SwiftShader). **This isn't Android runtime verification.** Branch `feature/game-polish-release` from `feature/delivery-logic` @ `95a5eb1` (v8, 0.8.0).

Note: this file had no v8 (0.8.0) section, although `SESSION_HANDOVER.md` refers to one. The v8 results weren't reconstructed here.

| Kind | Check | Result |
|---|---|---|
| Automated logic | `run_tests.gd` | **PASS: 199 passed, 0 failed** (+5: keys take focus; focus ring on every key variation, ring contrast ≥ 3:1; dialogs focus their main action and scroll to focus; `App.VERSION` = every Android preset's name, one versionCode, package id unchanged; the tips-replay flag survives a save) |
| Automated logic | `validate_levels.gd` (retired sorting mode) | **PASS: levels=164 failed=0 unverified=0** |
| Automated logic | `delivery_report.gd` (run without `--write`; rules and levels unchanged) | **PASS: 30/30**, 27 non-tutorial levels with a verified dependency |
| Repo | `git diff --check` | clean |
| Desktop UI, real input | **`dl_keys`** (new; keyboard and pad events only) 720×1280 | **PASS 23/23**: Enter advances the intro; puzzle 1 shows the first push before any move and the first move clears it; a key-repeat echo moves nothing; puzzle 1 solved by arrows, WASD and D-pad with exactly one move per press; the result card focuses Next Puzzle and Enter opens puzzle 2; Escape opens Pause with Resume focused, Down moves focus, Escape closes it with nothing moved; with a dock key focused by Tab, arrows still move the courier; Z undoes; Pause → Back to café by Tab/Enter; Home focuses Play; Escape on Home asks before leaving with Stay focused; a tap leaves keyboard mode |
| Desktop UI, real input | `dl_keys` in Arabic + Larger text | **PASS 23/23** |
| Desktop UI, real input | v8 battery (`tools/dl_battery.sh`, one scenario at a time, fresh saves) | journey **95/95**; reduced motion **95/95**; life_a/life_b **7/7** (life_a exits 137 by design: hard kill); rapid **4/4**; evidence **4/4**; look EN/AR: 0 script errors |
| Desktop UI, real input | journey in Arabic at **480×800 + Larger text** | **93/96**. Before any change, the same run in English failed too (36 pass / 72 fail with three runs in parallel; 38 pass / 5 fail alone, the same steps): timing under software GL. Fixed in the QA script: the Hint tap now waits past the blocked card's 600 ms guard, as Undo/Restart already did. **Still failing (3, QA timing, not a regression):** the scripted rapid-input storm after puzzle 7's last push runs ~4 s on this slow renderer, so a later press lands on the result card's **Replay** after its 450 ms guard; the level restarts. The reward was still paid exactly once (checked) |
| Desktop UI | Screens at Larger text, EN + AR (`dl_look`, now also Settings, Credits and the end of Help) | Reviewed by eye. **Found and fixed:** the Arabic "On" word in Settings switches was clipped to one letter at Larger text (now shrinks to fit). HUD captions now 21 px and the strip grows with text size |
| Web | `build/web` in headless Chromium (405×720) | Loads, **0 page errors**; Enter advances the intro, puzzle 1 shows the guide arrow, one ArrowRight = one step and clears it (`docs/screenshots/v8.1/web_*.jpg`) |
| Build | APK `build/tinystreet-v8.1-polish-debug.apk` | `com.tinystreet.sortrestore` **0.8.1 / versionCode 9**, permissions: VIBRATE only; `apksigner` certificate SHA-256 **`62fa12828ad217be61c751322a58f2ce10988c3fccc11b1c704b7259a6281b2e`** (same as v1–v8: updates in place); APK SHA-256 `946d9cefef7b896a4acc5f22dc6bd04e6c3fd65f8a813acad2502e5a1b45b813` |
| Android emulator / device | none | **NOT RUN** |

Evidence: `docs/screenshots/v8.1/`.

**Not verified (needs the phone):** Android Back during each overlay, the 28 px bottom margin against a real gesture bar, a hardware keyboard or game pad over Bluetooth, an Android TV remote, real-font text sizes.

## v7 (0.7.0), gameplay clarity (score, results, failure), 2026-10-17
Environment unchanged: GitHub Codespace, 2 vCPU, **no GPU, no Android device**. `/dev/kvm` is still `root:109 0660` and not accessible to this user; the Oct 16 attempt showed Android 16 crashing under software emulation, so **the emulator wasn't retried**. Every UI check below ran in a **desktop Linux build** under Xvfb (Mesa software GL). **This isn't Android runtime verification.** The Appetize session the owner described (0.5.0, Pixel 7 / Android 13) was an external observation; Appetize was not driven in this session.

### What ran, by kind
| Kind | Check | Result |
|---|---|---|
| Automated logic | Unit/integration tests | **PASS: 148 passed, 0 failed** (+13 `tests/test_score.gd`: points reward deliveries, not taps or bells; tidy bonus only on completion; undo/redo/restart exact, with no double count on redo; a saved attempt rebuilds the same score; solver key ignores the tallies; all 96 shipped solutions score every item once; best score kept and never pays; win rewards idempotent; schema 4 → 5 migration keeps stars and tokens, with a backup; last-level and last-bakery main action; a full counter with a delivery left is not lost; loss detected, retry clean, undo recovers) |
| Automated logic | Level validation | **PASS: levels=164 failed=0 unverified=0**; `docs/LEVEL_REPORT.md` unchanged (only score tallies were added to `Rules`) |
| Automated logic | Guide data | All stored routes (96 + 8 + 60 + 13) replayed to a win; appendix routes unchanged |
| Desktop UI, real input | **`player`** (new; fresh save, taps only on visible keys and crates) | **PASS 33/33**: first launch → level 1 → result card **≈0.6 s** after the last delivery (measured 600–713 ms), nothing covering it; "Level complete!", score, +tokens; best saved; story plays **after** the result; **Next level opens level 2**; levels 2–3 via Next; **genuine loss on level 4** (a losing line found by search, played by taps) with the reason "counter is full (3 of 3)…", no reward or unlock; **Retry → fresh board, score 0, crates respond**; two undos return the score exactly, replaying adds nothing; Restart → 0; Restart/Undo/Pause/Help/crate taps before the card are refused; a tap on a card key as the card lands is swallowed; rewards paid once; Replay pays no repeat tokens; best kept; Next after a replay → level 5; Pause → Level map |
| Desktop UI, real input | **`player_reopen`** (relaunch on the same save) | **PASS 12/12**: tokens, cleared levels 1–4 and their best scores survive a restart; level 5 not cleared; Play opens level 5 |
| Desktop UI, real input | **`finale`** | **PASS 5/5**: level 96 opens from Play; its card's only primary is "Celebrate the grand finale"; it lands on Home with the finale message |
| Desktop UI, real input | `player` in **Arabic** (720×1280) | **PASS 32/32** (run before the extra lock check was added); RTL strip, result and failure cards inspected |
| Desktop UI, real input | `player` at **720×1080 (3:2) + large text + reduced motion** | **PASS 33/33**; result and failure cards fit without scrolling |
| Desktop UI | All 96 campaign levels via taps | **PASS: 96/96 won** |
| Desktop UI | Existing flows on fresh saves | **PASS**: slice 4/4, v3 11/11, v2 10/10, nav/Back 17/17, rewards 8/8, ledger 17/17; rapid 400 taps consistent, 0 leftover effects; layouts and EN/AR tours: 0 script errors |
| Desktop UI | Frame times (software GL; not a phone) | play avg 88.5–93.2 ms, p95 ~121 ms (v6: 78–82 ms) |
| Build | APK `build/tinystreet-v7-clarity-debug.apk` | `com.tinystreet.sortrestore` **0.7.0 / versionCode 7**; `apksigner` certificate SHA-256 **`62fa12828ad217be61c751322a58f2ce10988c3fccc11b1c704b7259a6281b2e`** (same as v1–v6: updates in place); APK SHA-256 `a57e7aa1823434ce80fb6891ccda2284dc176c936ec95c99ad65d27fe2619b35` |
| Android emulator | none | **NOT RUN (blocked: no KVM access)** |
| Physical device | none | **NOT RUN** (owner: `docs/ANDROID_ACCEPTANCE_TESTS.md` part A2, G-01…G-10) |

### Defects found and fixed in v7
1. **Result card could be lost (pre-existing, confirmed by real-input QA).** Every board input first snaps effects (`_finish_effects`), which killed the tween that would show the win card 1 s later. A tap in that window left a won board with no result and no Next. The same applied to the loss card, the Café Rush hand-off and the ledger "Page solved" card. Now a scene-tree timer drives them.
2. **Story beat before the result** (owner's Appetize observation). It now plays after the card.
3. Restart / Undo / Pause / **Help** during the win delay could start a new attempt or leave the screen (Help: the card never appeared and the level restarted). A won attempt now refuses them.
4. A card that appears under a still-tapping finger could take the tap as a choice (seen with reduced motion). Card keys now ignore presses for 450 ms (same mechanism as screen transitions).
5. Competing primaries on the first win (Restore above Next); "Next level" on the last level; `delete_all()` missing the new `.schema4.bak`.
6. Found during the redesign and fixed: the result card scrolled at 720×1280 (compacted); the inline Restore key broke mid-word; "1 spaces" wording; the +25 pop-up overlapped +10/+5.

QA-harness mistakes, not game bugs: a fresh install opens level 1 directly (the first script expected Home); `_texts()` ignored button captions; a fixed (60, 60) "pause" tap hit Help in RTL. All corrected.

**Not verified (needs the phone):** touch comfort of the new strip and card keys, real fonts and density, how the +10/+25 pop-ups and score roll-up feel at 60 fps, sound of the score count, Android Back during the result, installing over v6. Whether the loop now *feels* clear and satisfying is the owner's call.

## v6 (0.6.0), production polish phase A (skins, art, sound, board), 2026-10-16
Environment unchanged: GitHub Codespace, 2 vCPU, **no GPU, no Android device or emulator**. Visual and interaction checks ran in a desktop Linux build under Xvfb (Mesa software GL). **This isn't Android runtime verification.**

| Check | Result |
|---|---|
| Unit/integration tests | **PASS: 135 passed, 0 failed** (+6 `test_skin.gd`: default skin complete and every file loads; nine-patch margins follow import density; a partial user:// skin extends the default and overrides images and colours, with errors reported; a missing skin falls back; a missing key returns false so built-in art draws; skin selection from settings) |
| Level validation | **PASS: levels=164 failed=0 unverified=0** (rules and levels unchanged) |
| All 96 campaign levels via simulated taps on the new board | **PASS: 96/96 won** (`play=1-48`, `play=49-96`) |
| Scripted UI flows, each on a fresh save (`game/tools/qa_battery.sh`) | **PASS**: slice 4/4, v3 11/11, v2 10/10, ledger 17/17, nav/Android Back 17/17, rewards 8/8 |
| Rapid tapping (400 taps) | **PASS**: consistent with a clean replay, 0 leftover effects |
| Layouts | 720×1280, 720×1600, and 720×1000 with large text (renders 921×1280): no script errors, no clipping or overlap; reviewed by eye. With 6 crates on a short screen the stacked items shrink to fit (as designed) |
| Screen tour EN + AR (39 screens) | 0 script errors; game, home, win, bakery and ledger screens reviewed by eye. RTL tickets, units and dock mirror correctly |
| Frame times (software GL, not representative of a phone) | play runs avg 78–82 ms, p95 ~102 ms: the same range as v5 (75–93 ms), so the SVG art adds no measurable cost here |
| Skin contact sheet (`tools/skin_sheet.gd`) | 11 images, 0 errors (`docs/screenshots/v6/skin_default_sheet.png`) |
| APK `build/tinystreet-v6-polish-debug.apk` | `com.tinystreet.sortrestore` **0.6.0 / code 6**, contains `skins/default/skin.json` and all skin art and sounds; SHA-256 `93e14be0…6cb4cca` (in `build/SHA256SUMS.txt`). **Not run on Android.** |

Found during v6 QA:
- **Win card, café fully restored:** the "café is restored" line wrapped one letter per line (a wrapping label in a row without width; the old stat chips had hidden it by widening the card). Fixed and re-checked in Arabic.
- **QA harness:** running scenarios back to back on one save made reward-once checks fail (rewards already paid, tasks claimed, ledger lantern earned). Not a game bug. `game/tools/qa_battery.sh` now gives every scenario its own fresh save; all four affected scenarios then passed.

Known nit: the tiled crate slats show a faint seam at some heights (art, not layout).

Not verified (needs the phone): real sound levels of the Kenney effects on a phone speaker, haptics, GPU frame rate, touch comfort with the larger items.

## v5 (0.5.0), UI polish, 2026-10-16
Environment unchanged: GitHub Codespace, 2 vCPU, **no GPU**. `/dev/kvm` exists but is still `root:109 0660` and this user isn't in group 109 (checked: opening it fails with "Permission denied"), so the emulator acceleration blocker hasn't changed and **the emulator wasn't retried**. No Android device is attached (`adb devices` is empty). All visual and interaction checks below ran in a **desktop Linux build** under Xvfb (Mesa software GL). **This isn't Android runtime verification.**

Baseline before v5 (branch `feature/ui-polish` from `c8b2653`): 123/123 tests, and the 39-screen `tour` captured as "before" images.

| Check | Result |
|---|---|
| Unit/integration tests | **PASS: 129 passed, 0 failed** after the PR #1 review fixes (+2 `test_ledger_rules.gd`: preview reuse, `sequence`/`bell_budget` schema checks; previously 127) (+4 `test_ui.gd`: theme variations exist, 14 text/background contrast pairs meet targets, double-press guard, RTL start alignment) |
| Level validation | **PASS: 164/164, 0 UNVERIFIED** (rules and level files unchanged) |
| Ledger proofs (`ledger_tool.gd -- build`) | **PASS: 13/13** (output identical apart from timing fields, which were reverted) |
| All 96 campaign levels via simulated taps on the redesigned UI | **PASS: 96/96 won** |
| Scripted UI flows | **PASS**: slice 4/4, v2 10/10, v3 11/11, ledger 14/14, nav/Android Back 17/17, rewards 8/8 |
| Rapid tapping (400 taps) | **PASS**: state consistent with a clean replay, 0 leftover effects. Frame times under software GL: average 87 ms, p95 117 ms (not representative of a phone GPU) |
| Lifecycle (moves → background → hard kill → relaunch) | **PASS**: identical state key and undo count |
| Layouts | QA `layouts` at 720×1280, 720×1600 + simulated 90 px cut-out, 720×1000 + larger text: no script errors; reviewed visually |
| New `tour` scenario (39 screens and dialogs) | Captured and **personally inspected** in English and Arabic at 720×1280, and English at 720×1600 + cut-out and 720×1000 + larger text: 4 × 39 screenshots, 0 script errors |
| Guide data | Every stored route (96 campaign + 8 bakery + 60 daily + 13 ledger) **replayed to a win** through the real rules (`tools/guide_data.gd`) |
| PDFs | Rendered with PyMuPDF and inspected page by page: player guide 37 pages, Android tests 12 pages; text is searchable; 0 missing-glyph characters; bookmarks for every section |
| APK `build/tinystreet-ui-polish-debug.apk` | Built from `32a5100`; `apksigner verify` OK (v2 + v3); certificate SHA-256 `62fa1282…1b2e`, the same as v1–v4; `com.tinystreet.sortrestore` 0.5.0 / code 5; only `VIBRATE`. Earlier APKs still match `build/SHA256SUMS.txt`. **Not run on Android.** |

Defects found by inspecting the renders, then fixed and re-checked:
- **RTL alignment (pre-existing).** Godot already mirrors `LEFT` to the right edge in RTL; the old code passed `RIGHT` for Arabic, so start-aligned text sat on the wrong side (speech bubbles, list titles). Fixed in one helper (`UI.al()`), with a test.
- Arabic "Redo" and "Restart" used the same word (إعادة) side by side in the ledger dock. Now distinct; Arabic still awaits a qualified review.
- "How to play" said each level gives 1 token; the game pays 1 token per new star (pre-existing text error). Corrected in EN and AR.
- v4 win card's last button ran off the bottom of the screen. Dialog bodies now scroll when too tall.
- During the redesign: icon buttons without a subtitle lost their text (zero-width label); the moon icon failed to triangulate; notification dots rendered as tall pills; chips stretched into ovals beside two-line titles; disabled night keys turned grey; on 20:9 screens the awning floated away from the café; long décor names were clipped; the ledger move counter was clipped in RTL; coin icons turned into dark blobs on coloured keys; PDF tables squeezed short columns letter by letter, and headings were stranded at page bottoms.

Before/after images: `docs/screenshots/v5/before_after/` (`overview.jpg` and 12 pairs).

**Not verified (needs the phone):** real touch accuracy and target comfort, real display density and fonts, safe areas reported by hardware, audio/vibration, Android Back gestures, interruptions, installing over v3/v4, frame rate on a GPU. These are in `docs/ANDROID_ACCEPTANCE_TESTS.md`, all marked NOT RUN. Whether the new look actually *feels* inviting is the owner's call.

---

## v4 (0.4.0), The Midnight Ledger, 2026-10-16
Environment unchanged: GitHub Codespace, **no GPU, no KVM**. Visual and interaction QA ran in a **desktop Linux build** under Xvfb. **This isn't Android runtime verification**; the emulator wasn't retried. The owner's V3 phone feedback is still pending; V3 "currently works" on their phone (user-reported).

Baseline re-run before any v4 change (branch `feature/midnight-ledger` from `618cf5a`): **102/102 tests, 164/164 levels**, V3 APK hash `1a59a0b9…8c29` confirmed.

| Check | Result |
|---|---|
| Unit/integration tests | **PASS: 123 passed, 0 failed** (+21: `test_ledger_rules.gd` 9, `test_ledger_pages.gd` 12) |
| Level validation (campaign, bakery, daily) | **PASS: 164/164, 0 UNVERIFIED** (after the fix below) |
| Ledger proofs (`tools/ledger_tool.gd -- build`) | **13/13 pages PASS**: witness replay with budget and sequence; min rings proved; every alternative at every witness step classified (0 unknown); idea verified. See `docs/EXPERT_PUZZLE_PROOFS.md`. |
| Solver vs brute-force reference (100+ tiny boards with budgets and sequences) | **PASS**: identical solvable/unsolvable verdicts; every witness replays |
| QA `ledger` (real UI) | **PASS 14/14**: home invitation retired after visiting; budget enforced with a message; stamp + no-hint; reference route recognised; "why" shown; stage-3 hint = verified next move; wrong turn proven unsolvable; recovery to the proven route; redo; resume; stale (changed) page not resumed; lantern for the collection; restart grants nothing |
| Campaign regression: all 96 levels via input; slice 4/4; v2 10/10; v3 11/11; nav 17/17; rewards 8/8; rapid; lifecycle; layouts (20:9 + cutout, short + large text); EN/AR shots | **PASS** |
| APK `build/tinystreet-v4-expert-debug.apk` | Built from `d837a07`; `apksigner verify` OK (v2+v3); same certificate as v1–v3; 0.4.0 / code 4; only `VIBRATE`. **Not run on Android: pending the owner's phone test.** |

Found and fixed during v4 QA:
- **Regression caught by the validator.** Putting `rings_used` in the search key unconditionally made unlimited-bell searches infinite (every ring looked new): 5 campaign/daily levels became UNVERIFIED. Now rings are part of the key only when a budget exists; back to 0 UNVERIFIED, with a test for both cases.
- With the bell budget spent, tickets stopped accepting taps and gave no explanation. They now show a crossed-out bell and a message.
- "Why this works" compared the route with JSON floats and said "different" for the reference route.
- The Home invitation text overflowed the screen width.
- QA script timing (a click in the same frame as a dialog closing) was a test artefact, not a game bug.

**Not verified:** v4 on Android; whether the puzzles are interesting, fair and learnable (no human playtest); the designer difficulty estimates.

---

# v3 report (0.3.0)

## v3 (0.3.0), 2026-10-16
Environment unchanged: GitHub Codespace, 2 vCPU, **no GPU, no KVM**. Visual and interaction QA ran in a **desktop Linux build** under Xvfb (software GL). **This isn't Android runtime verification.** The emulator wasn't retried (blocker unchanged). The owner's report that "the updated Android version works on a phone" is recorded as a user-reported runtime check; the exact build wasn't stated.

Baseline before v3 work (v2 code at `f67bbde`): 81/81 tests, 144/144 levels.

| Check | Result |
|---|---|
| Unit/integration tests (`tests/run_tests.gd`) | **PASS: 102 passed, 0 failed** |
| Level validation (`tools/validate_levels.gd`) | **PASS: 164/164** (96 campaign + 8 bakery + 60 daily), 0 UNVERIFIED. Every `required`/`tidier` bell claim is re-proven by search on each run. |
| All 96 campaign levels through real input (QA `play=1-48`, `play=49-96`) | **PASS: 96/96 won** (bell rings sent as ticket taps) |
| v3 slice p01–p12 (QA `slice`) | **PASS 4/4**: 12/12 won via input; p06 chalkboard reward; p12 bakery unlock; special reward once |
| v3 flows (QA `v3`) | **PASS 11/11**: visitor present after the counter step; preview saves nothing; revert restores; keep saves the theme; owned choices free; extra preview doesn't buy; challenge pays, then pays once; two bakery steps bought once each; oven closed until the first order; bakery level won via input |
| v2 flows (QA `v2`) | **PASS 10/10** (fresh refusal, drag, cancel, pause mid-animation, locks, double-tap restore, task once, Rush) |
| Navigation / Android back (QA `nav`) | **PASS 17/17** |
| Rewarded flows, simulated ads (QA `rewards`) | **PASS 8/8**, clean exit |
| Rapid tapping (400 taps) | **PASS**: state equals a clean replay; 0 leftover effects |
| Lifecycle: moves → pause → hard kill → relaunch | **PASS**: identical state key (now includes the bell) and undo count |
| Layouts: 720×1280, 720×1600 + 90 px cutout, 720×1000 large text; EN + AR shots | Reviewed: no clipped controls; RTL mirrors tickets and the bell. Fixed during review: bakery sign overlap, 3-part order label vs bell position, bell "First" text removed (collided with products). |
| APK `build/tinystreet-v3-debug.apk` | Built from `2297fb1`; `apksigner verify` OK (v2+v3 schemes); same debug certificate as v1/v2; versionCode 3 / 0.3.0; only `VIBRATE`; new levels, scripts and sounds present. **Not run on Android: pending the owner's phone test.** |

New or extended suites: `test_bell.gd` (10: routing, counter priority, toggle, clear on delivery, disabled levels, the bell never changes legality, undo/replay with rings, solver proves bell-required, hint says "ring", no double rings, schema), `test_v3_meta.gd` (10: schema-3 → 4 migration of a full v2 player with backup file, v1 → 4, mastery once, special rewards once, challenge cards validity/goals/once, tidy goals reachable by solver, themes, bakery persistence, bakery levels and ovens, restart clears the bell, hint path completes), `test_levels.gd` (slice structure, bell proofs, counts).

**Not verified:** v3 on Android (install-over-v2 update, haptics, audio, performance); whether the bell and the slice are *fun* (no human playtest yet).

---

# v2 report (0.2.0)

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
