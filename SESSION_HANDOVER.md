# Session Handover

**Last updated:** 2026-10-17, session 8 (v8 / 0.8.0: Delivery Logic core rebuild).

## State
- Branch **`feature/delivery-logic`**, created from `feature/gameplay-clarity` @ `72993d7` (the latest baseline: v7 0.7.0 / code 7; `origin/main` is an older ancestor). **Pushed to `origin/feature/delivery-logic`** (this also published the v6/v7 commits); a PR to `main` is open for it. Nothing merged. PR #1 is still open. `backup/pre-strip-build`: **never push it**.
- Late session-8 fixes: v8 wins no longer feed the retired mode's achievements/journal (`puzzle_screen.gd`, test in `test_delivery_meta.gd`); the Route blocked card is compact and ignores taps for its first 600 ms (QA journeys wait 0.8 s before tapping it). Tests: **194 passed**. `tools/qa_battery.sh` is the retired mode's battery; the v8 one is `tools/dl_battery.sh`.
- The owner said the game "feels like clicking highlighted items rather than solving puzzles" and authorised a core rebuild. v8 replaces the puzzle with **Delivery Logic** (working title): push picture-marked crates onto matching pads (Sokoban-family rules with symbols). See `docs/DELIVERY_RULES.md`, `docs/DELIVERY_DESIGN.md`.
- **30 puzzles**, all passing the quality gates (`docs/DELIVERY_LEVEL_REPORT.md`); minimum pushes proved (`data/delivery/proofs.json`).
- The sorting game is **retired from the primary flow, not deleted** (source, levels, tests and players' records kept).
- Save **schema 6** (`logic` namespace). Real migration verified on a save produced by the v7 build.
- **APK** `build/tinystreet-v8-delivery-debug.apk`: `com.tinystreet.sortrestore` **0.8.0 / versionCode 8**, same debug key as v1–v7. **Web** `build/web/` and **Web QA** `build/web-qa/` (feature `qa` opens all puzzles). See `TEST_REPORT.md` v8 for hashes and results. **Not run on Android** (no KVM, no device).

## Where things are (v8)
| Topic | Files |
|---|---|
| Rules (the only rule module) | `game/src/core/delivery_rules.gd` (moves, walk paths, win, reach, canonical keys, dead cells, freeze) |
| Data model | `delivery_level.gd` (ASCII map parser/validator), `delivery_state.gd`, `delivery_session.gd` (undo/redo, save/restore with guards) |
| Solver | `delivery_solver.gd` (incremental BFS over push positions; SOLVED/UNSOLVABLE/TIMEOUT; `expand_pushes`, `validate`) |
| Hints | `delivery_hints.gd` (pure; tiers 2–3); tier 1 text is per level (`nudge`) |
| Analysis (tools/tests only) | `delivery_analysis.gd` (complete graph, path metrics, random/greedy/fixed-order agents, claims, mistakes, duplicates) |
| Progress & rewards | `game/src/meta/delivery_progress.gd` (`record_win`, medals, best, attempt save/load) |
| UI | `src/board/delivery_board.gd`, `src/screens/puzzle_screen.gd` (async check, blocked card, hints, rewind search), `puzzles_screen.gd`, `solved_panel.gd`; Home/Boot/Help rewired |
| Levels | `game/data/delivery/levels.json` (+ generated `proofs.json`) |
| Tools | `tools/delivery_report.gd -- --write` (gates + report), `tools/delivery_lab.gd FILE [ids] [--explain] [--solution]`, `tools/delivery_gen.gd ROOMS OUT [trials] [seed]` (authoring aid) |
| QA (real input) | `src/app/qa_delivery.gd`: `dl_journey`, `dl_life_a`/`dl_life_b`, `dl_look`, `dl_rapid`, `dl_migrated`, `dl_evidence`, `dl_clip_*` |
| Docs | `docs/DELIVERY_RULES.md`, `DELIVERY_DESIGN.md`, `DELIVERY_LEVEL_REPORT.md` (generated), `DELIVERY_PLAYER_GUIDE.md`, `DELIVERY_SMOKE_TEST.md`; evidence `docs/screenshots/v8/`, `docs/recordings/` |

## Commands (v8)
```bash
G=~/tools/godot/godot
$G --headless --path game --import
$G --headless --path game -s res://tests/run_tests.gd                         # all suites
$G --headless --path game -s res://tools/delivery_report.gd -- --write        # 30 levels must PASS
cd game && xvfb-run -a $G --path . --rendering-driver opengl3 --resolution 720x1280 -- \
   --save-path=/tmp/s.json --qa=dl_journey --qa-out=/tmp/out              # fresh save per scenario
$G --headless --path game --export-debug "Android Debug APK" ../build/<name>.apk
$G --headless --path game --export-release "Web" ../build/web/index.html
$G --headless --path game --export-release "Web QA" ../build/web-qa/index.html
python3 -I <scratch>/web_smoke.py build/web OUTDIR 8765                      # headless Chromium check (see TEST_REPORT)
xvfb-run -a $G --path game ... --write-movie out.avi --fixed-fps 30 -- --qa=dl_clip_win ...   # recordings
```

## Gotchas learned (v8)
- `delivery_report.gd` needs `-- --write` (with the `--`) to write proofs and the report; without it nothing is written and medals have no proved minimum (the QA journey caught this).
- Claims: "every solution must push X" is checked by a search that forbids the push; "no solution passes a position with P" must be checked against the complete graph's exact distances (forbidding P positions and searching is the wrong test).
- A 2×2 block of crates, or two crates side by side against a wall, is a genuine freeze deadlock; tests were wrong about this first, not the code.
- The arrow keys act on `button_down` with a 90 ms guard (the UI's 350 ms debounce would make them sluggish).
- The Route blocked card replaces the arrow row while shown, so the board keeps its size; swipes still work.
- A QA script that fails to parse leaves Godot hanging under xvfb: the driver now guards the load. Kill stray `godot` processes after a timeout.
- `rm -rf $VAR/...` is refused by the session's safety check: use `"${VAR:?}"/...`.

## Next tasks (in order)
1. **Owner:** play the Web build (or the APK) with `docs/DELIVERY_SMOKE_TEST.md`; then puzzles 4–12. Questions: is each "aha" readable? Are lessons 1–3 enough? Is the ramp right? Which puzzles feel arbitrary?
2. Human playtests (5+ people): record time, restarts, hint tiers used per puzzle; re-order or replace puzzles that feel arbitrary.
3. Qualified Arabic review (≈ 120 new v8 strings).
4. Art pass on the board via `delivery.*` skin keys (crate, pad, wall, floor, courier).
5. Decide the sorting mode's future (keep hidden, offer as "Classic", or remove) and PR #1.

---
*Session 7 notes below remain valid for the retired sorting mode.*

**Last updated:** 2026-10-17, session 7 (v7 / 0.7.0: gameplay clarity: score, results, failure).

## State
- Branch **`feature/gameplay-clarity`**, created from `feature/production-polish` after committing the previously uncommitted v6 work there as `621e9c3`. Nothing is pushed or merged. PR #1 (`feature/ui-polish` → `main`) is still open. `backup/pre-strip-build` holds large files: **never push it**.
- The owner said the game "feels basic and does not clearly communicate scoring, winning, losing, or progression". An external Appetize test of 0.5.0 saw a story popup before the results, no points counter and tall empty crates. v7 answers this:
  - live **score** (`Scoring.points`, derived from state)
  - Orders · Score · Counter **HUD**
  - a prompt **"Level complete!"** card with one primary action; story beats after it
  - a **failure card** with the cause, Retry primary and Undo secondary
  - crates that shrink as they empty
  - personal bests (save **schema 5**)
- **Confirmed defect fixed:** a tap during the post-win delay cancelled the result card (also the loss card, the Rush hand-off and the ledger card). See `TEST_REPORT.md` v7.
- Rules and level data are unchanged (validator 164/164, `LEVEL_REPORT.md` identical). The economy is unchanged. Real purchases stay off.
- **APK: `build/tinystreet-v7-clarity-debug.apk`**, `com.tinystreet.sortrestore` **0.7.0 / versionCode 7**, signed with the same Godot debug key as v1–v6 (cert SHA-256 `62fa1282…1b2e`; updates in place). APK SHA-256 `a57e7aa1823434ce80fb6891ccda2284dc176c936ec95c99ad65d27fe2619b35`. **Not run on Android** (no KVM; no device).
- Tests 148/148; QA battery 15/15 scenarios clean on fresh saves, including the new `player` (33), `player_reopen` (12) and `finale` (5).

## Where things are (v7 additions)
| Topic | Files |
|---|---|
| Score formula and tallies | `game/src/core/scoring.gd` (`points`, `breakdown`); tallies `served_direct` / `served_counter` in `rules.gd` and `puzzle_state.gd` (not in the solver key) |
| Best scores | `Progression.record_score` / `best_score`, `data.campaign.best`; migration `SaveStore.migrate` step 5 |
| HUD | `game_screen.gd` `_Hud` (var `progress`; `snap()` after undo/restart/resume) |
| Result timing | `game_screen._after()` (scene-tree timer, not cancelled by `_finish_effects`); `Main.lock_input(ms)` |
| Result card | `win_panel.gd` (`create(..., beat)`, `_next_text`, `_score_row`, `_goal(restore)`) |
| Failure card | `game_screen._show_lost` / `_lost_reason` (`lost_body_full`) |
| QA journeys | `qa_driver.gd` `player`, `player_reopen`, `finale` (`_tap_button` by visible text, `_tap_named` by caption, `_losing_line`); `--qa-lang`, `--qa-large-text`, `--qa-reduced-motion` |
| Evidence | `docs/screenshots/v7/` (`before_after.jpg`, `win.jpg`, `lost.jpg`, `after_retry.jpg`, `next_level_opened.jpg`, `story_after_result.jpg`, `ar_*`, `small_large_text_*`, `finale_*`) |

## Gotchas learned (v7)
- `_finish_effects()` kills every tween in `_tweens`. Never schedule an outcome (result, navigation) with `_delay`; use `_after`.
- Under reduced motion `App.dur(x)` is 0.01 s, so cards appear instantly; QA "stray tap" steps must account for that.
- On a fresh save, the first launch goes straight into level 1 (after the intro story), not Home.
- In RTL the top bar mirrors: never tap the Pause/Help chips by coordinates; use `_tap_named(root, caption)`.
- `player_reopen` reuses the `player` save (`qa_battery.sh` handles this).

## Next tasks (in order)
1. **Owner:** install `tinystreet-v7-clarity-debug.apk` over v6 and run `docs/ANDROID_ACCEPTANCE_TESTS.md` **A2 (G-01…G-10)** plus the smoke test. Does the loop now read clearly? Is the score worth keeping as designed?
2. Tune from phone feedback: pop-up size and timing, score roll-up speed, the result-card density on the owner's phone.
3. Qualified Arabic review (about 25 new v7 strings, plus the earlier backlog).
4. Carried over from v6: phase A remainder, phase B groundwork, Play Console/AdMob decisions, PR #1.

---
*v6 notes below remain valid unless superseded above.*

## Where things are (v6 additions)
| Topic | Files |
|---|---|
| Skins (art/sound/colour swap) | `game/src/ui/art_skin.gd` (`ArtSkin`); default skin `game/skins/default/skin.json` (+ `products/`, `board/`, `sfx/`); guide `docs/ART_PIPELINE.md`; tests `game/tests/test_skin.gd` |
| Skin selection | `BuildConfig.skin_id()` (`settings.skin`, `--skin=<id>`), loaded in `App.boot()` before the theme |
| Skin hooks | `ProductArt.draw`, `CrateView.draw_bag/_draw_crate`, `CounterView`, `CharacterArt.draw`, `Glyph.paint`, `Backdrop`, `ScreenBackdrop`, `AudioManager.reload_streams` |
| Skin contact sheet | `godot --headless --path game -s res://tools/skin_sheet.gd -- <id> OUT.png 200` |
| QA battery with fresh saves | `game/tools/qa_battery.sh OUT_DIR [scenario ...]` (`tour:ar` = Arabic tour) |
| Roadmap | `docs/PRODUCTION_ROADMAP.md` (phases A–E, free options for each) |

## Gotchas learned (v6)
- `Skin` is a built-in Godot class: the art class is **`ArtSkin`**.
- `Style` colours are now `static var`s (overridable by skins). Static vars are listed by `Script.get_property_list()`, not `get_script_property_list()`.
- Nine-patch margins in `skin.json` are design pixels; SVGs import at 2× (`importer_defaults` in `project.godot`) and `ArtSkin.density()` reads the factor from the `.import` file.
- QA scenarios assume a new player: give each its own `--save-path` (the battery script does). Running them on one save gives false "reward once" failures.

## Where things are (v5)
| Topic | Files |
|---|---|
| Design tokens + theme | `game/src/ui/style.gd` (documented in `docs/DESIGN_SYSTEM.md`) |
| Components | `game/src/ui/ui.gd` (button, icon_text_button, chip, badge, pill, tag, progress, medallion, section, row, header, segmented, switch, fit_font) |
| Icons | `game/src/ui/glyph.gd` (`Glyph.paint()`; `"p_<product>"` uses product art) |
| Backgrounds / shop front / level key | `screen_backdrop.gd`, `storefront.gd`, `level_cell.gd`; board setting `game/src/board/backdrop.gd` (`mode`) |
| Dialogs | `game/src/ui/dialog.gd` (`icon`, `night`, scroll-capped body, paired secondary buttons) |
| Transitions, input lock | `game/src/app/main.gd` (`input_locked()`, `screen_mode` hook) |
| QA screen tour | `qa_driver.gd` `tour` (`--qa-lang=ar`, `--qa-large-text`) |
| Guides | sources `docs/guide_src/player_guide.md`, `docs/ANDROID_ACCEPTANCE_TESTS.md`; builders below |

## Commands
```bash
G=~/tools/godot/godot
$G --headless --path game -s res://tests/run_tests.gd                       # expect 148 passed
$G --headless --path game -s res://tools/validate_levels.gd                 # expect levels=164 unverified=0
xvfb-run -a $G --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=tour --qa-out=DIR [--qa-lang=ar]
# guides (pip install --user reportlab fonttools pillow pymupdf)
$G --headless --path game -s res://tools/guide_data.gd -- /tmp/guide_data.json
python3 tools/build_guide_appendix.py /tmp/guide_data.json                  # writes the guide MD + solutions appendix
python3 tools/export_screenshots.py TOUR_DIR [BEFORE_DIR] [AR_TOUR_DIR]     # docs/screenshots/v5
python3 tools/build_guide_pdf.py docs/TINY_STREET_PLAYER_GUIDE.md docs/TINY_STREET_PLAYER_GUIDE.pdf
python3 tools/build_guide_pdf.py docs/ANDROID_ACCEPTANCE_TESTS.md docs/ANDROID_ACCEPTANCE_TESTS.pdf
cd game && $G --headless --path . --export-debug "Android Debug APK" ../build/<new-name>.apk
```

## Gotchas learned (v5)
- **RTL alignment:** Godot mirrors `HORIZONTAL_ALIGNMENT_LEFT` for RTL controls. Use `UI.al()` (always LEFT, meaning "start"); never pass RIGHT for Arabic.
- Overlay children in a Button (HBox with labels): a label with `text_overrun_behavior` has ~0 minimum width. Only set overrun inside an expanding container.
- `ledger_tool.gd -- build` rewrites `ledger.json` / `EXPERT_PUZZLE_PROOFS.md` with new timings; revert if nothing else changed.
- reportlab can't shape Arabic: keep Arabic script out of PDF sources.
- Don't edit `game/` while a QA battery is running.

## Next tasks (in order)
1. **Owner:** install `tinystreet-v6-polish-debug.apk` over v5 and play 10 minutes. Do the new products, crates, tickets and sounds feel right? Are the sound levels balanced on the phone speaker (tune with `volume_db` in `skin.json`)?
2. Phase A remainder (`docs/PRODUCTION_ROADMAP.md`): make the café interior / bakery / shop front / level keys skinnable; a CC0 music loop; street-map level select; store graphics.
3. Phase B groundwork that needs no accounts: `config/economy.json` + `config/ads.json`, boosters (rules + solver + validator), interstitial frequency logic, Remove Ads entitlement, theme skins as purchasable entitlements.
4. Owner decisions/accounts still open: merge PR #1; Play Console ($25 one-time), AdMob, Firebase/GameAnalytics; qualified Arabic review (now ~45 new strings since v4, plus the v6 credit lines).
5. Carried over: release AAB/monetisation rebuild, publisher items, purchase verification (real purchases stay off).

---
*v5 handover notes below remain valid unless superseded above.*

## Next tasks (in order)
1. **Owner:** install the v5 APK (`tinystreet-ui-polish-r2-debug.apk`) over v4 and run the 15-minute smoke test (`docs/ANDROID_ACCEPTANCE_TESTS.md` part A); report how the new look feels. The ledger playtest questions (`docs/EXPERT_PLAYTEST.md`) are still open.
2. Fix whatever the phone shows (touch comfort, safe areas, readability, performance on a GPU).
3. Decide whether to merge PR #1 (`feature/ui-polish`, which contains v3 and v4) into `main`.
4. Qualified Arabic review (now including ~40 new v5 strings).
5. Carried over: release AAB/monetisation rebuild, publisher items, purchase verification (real purchases stay off).
