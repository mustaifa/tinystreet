# Session Handover

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
