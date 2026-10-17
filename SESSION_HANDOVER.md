# Session Handover

**Last updated:** 2026-10-16, session 6 (v6 / 0.6.0: production polish, phase A).

## State
- Branch **`feature/production-polish`**, built on `feature/ui-polish` (v5 + PR #1 review fixes, `8b958df`). **PR #1** (`feature/ui-polish` → `main`) is still open and unmerged; the owner hasn't decided. Not pushed yet unless the commit log says otherwise. `backup/pre-strip-build` holds large files: **never push it**.
- The owner asked for a production-ready, revenue-earning game, agreed to the plan in **`docs/PRODUCTION_ROADMAP.md`**, and set two constraints: **free resources only for now**, and **art must be easy to swap and customise later**.
- v6 delivers phase A:
  - the **skin system** (`ArtSkin`, `docs/ART_PIPELINE.md`)
  - new SVG product and board art
  - Kenney CC0 sound effects
  - the ticket and crate redesign, plus the home and win-card trims
- Rules, levels, economy and save schema (4) are unchanged.
- **APK: `build/tinystreet-v6-polish-debug.apk`**, `com.tinystreet.sortrestore` **0.6.0 / versionCode 6**, same debug key as v1–v5 (updates in place). SHA-256 `93e14be03d940d20f492818464f84c4e3cfe8ebf595a7292c94e2f9bd6cb4cca`. **Not run on Android.**
- Tests 135/135; levels 164/164; 96/96 campaign via UI; all QA flows pass on fresh saves. See `TEST_REPORT.md`.

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
$G --headless --path game -s res://tests/run_tests.gd                       # expect 129 passed
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
