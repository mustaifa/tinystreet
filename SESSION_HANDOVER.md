# Session Handover

**Last updated:** 2026-10-16, end of session 5 (v5 / 0.5.0, UI polish).

## State
- Branch **`feature/ui-polish`**, built on `feature/midnight-ledger` (v4, `c8b2653`). `main` still holds V3. Pushed to `origin` (no force push). The local branch `backup/pre-strip-build` holds large files: **never push it**.
- The owner installed v4 on a phone: "the screens work, but the UI looks dull and does not feel inviting". v5 answers that with a full visual and usability pass. **Rules, levels, economy and save schema (4) are unchanged.**
- **APK: `build/tinystreet-ui-polish-debug.apk`**
  - `com.tinystreet.sortrestore`, **0.5.0 / versionCode 5**, built from commit `32a5100`.
  - SHA-256 `2f3f3da341fe6485bc95523f37d19023348dab31d74caf58bd1f0befb2f6a052` (also in `build/SHA256SUMS.txt`).
  - Same debug signing certificate as v1–v4 (`62fa1282…1b2e`), so it updates in place.
  - **Not run on Android.** Phone checks: `docs/ANDROID_ACCEPTANCE_TESTS.md` (all NOT RUN).
- Tests 127/127; levels 164/164; ledger 13/13; 96/96 campaign levels via the UI; all QA flows pass. See `TEST_REPORT.md`.
- Earlier APKs (v1–v4, AAB, monetisation test) are untouched.

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
$G --headless --path game -s res://tests/run_tests.gd                       # expect 127 passed
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
1. **Owner:** install the v5 APK over v4 and run the 15-minute smoke test (`docs/ANDROID_ACCEPTANCE_TESTS.md` part A); report how the new look feels. The ledger playtest questions (`docs/EXPERT_PLAYTEST.md`) are still open.
2. Fix whatever the phone shows (touch comfort, safe areas, readability, performance on a GPU).
3. Decide whether to merge `feature/ui-polish` (which contains v4) into `main`.
4. Qualified Arabic review (now including ~40 new v5 strings).
5. Carried over: release AAB/monetisation rebuild, publisher items, purchase verification (real purchases stay off).
