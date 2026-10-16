# Session Handover

**Last updated:** 2026-10-16, end of session 4 (v4 / 0.4.0, The Midnight Ledger).

## State
- Branch **`feature/midnight-ledger`** (from `main` at `618cf5a`). Not merged, not pushed. `main` still holds V3.
- The owner is testing V3 on their phone ("currently works"); full feedback pending. The campaign, café, bakery, economy and difficulty were **not changed** in v4.
- **v4 adds The Midnight Ledger**, an optional expert mode: 13 proven pages (3 lessons, 9 puzzles, 1 final), bell budget and order sequence constraints, three-stage verified hints, redo, resume guarded by a content hash, and stamps/badges/lantern with no tokens. Design: `docs/EXPERT_MODE_DESIGN.md`; proofs: `docs/EXPERT_PUZZLE_PROOFS.md`; spoilers: `docs/EXPERT_SOLUTIONS_SPOILERS.md`.
- **Tests and QA:** 123/123 tests; 164/164 levels (0 UNVERIFIED); 13/13 ledger pages proved. Desktop QA all pass (ledger 14/14 plus every earlier scenario). See `TEST_REPORT.md`.
- **APK: `build/tinystreet-v4-expert-debug.apk`**
  - Package `com.tinystreet.sortrestore`, **0.4.0 / versionCode 4**, built from commit **`d837a07`**.
  - SHA-256 `997c7ca252ceecf826fe128c8c305bc68a940eaf419802e0747303970cd40cc2`.
  - Signing certificate SHA-256 `62fa12828ad217be61c751322a58f2ce10988c3fccc11b1c704b7259a6281b2e`: the same Godot debug key as v1–v3, so it updates in place.
  - **Not run on Android; pending the owner's phone test** (`docs/EXPERT_PLAYTEST.md`).
- Earlier APKs kept untouched: v1, v2, v3 (`1a59a0b9…8c29`). Checksums in `build/SHA256SUMS.txt`.

## Where things are (v4)
| Topic | Files |
|---|---|
| Constraints | `src/core/rules.gd` (`rings_left`, `can_ring`, `_route`/`_apply_routed`, `_sequence_allows`, `sequence_next`, `is_lost`), `level_def.gd` (`bell_budget`, `sequence`, `content_hash`, `with_budget`), `puzzle_state.gd` (`rings_used`, `delivered`, key) |
| Redo | `src/core/puzzle_session.gd` (`redo_log`, `redo`, saved in `to_dict`) |
| Proof tooling | `src/core/ledger_analysis.gd` (min rings, trace, replay, idea checks, reference search), `tools/ledger_tool.gd` (search / review / build), `tools/ledger_pages.gd` (curated sources) |
| Content | `data/levels/ledger.json` (pages + proofs) |
| Mode logic | `src/meta/ledger.gd` (unlocks, rewards once, lantern) |
| UI | `src/screens/ledger_screen.gd` (page list), `src/screens/ledger_play.gd` (strip, rule card, hints, recovery, win, why), hooks in `game_screen.gd`; entry in `daily_screen.gd` + `home_screen.gd` |
| Strings | `tools/strings_*.py` (`ledger_*`, `name_n0..n5`) → `python3 tools/build_i18n.py` |

## Commands
```bash
G=~/tools/godot/godot
$G --headless --path game -s res://tests/run_tests.gd                         # expect 123 passed
$G --headless --path game -s res://tools/validate_levels.gd                   # expect levels=164 unverified=0
$G --headless --path game -s res://tools/ledger_tool.gd -- build              # re-prove the 13 pages (fails on any gap)
$G --headless --path game -s res://tools/ledger_tool.gd -- review '<board json>'
$G --headless --path game -s res://tools/ledger_tool.gd -- search both 400 15
xvfb-run -a $G --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=ledger --save-path=user://qa_$RANDOM.json
cd game && $G --headless --path . --export-debug "Android Debug APK" ../build/tinystreet-v4-expert-debug.apk
```

## Gotchas learned (v4)
- **Search keys:** include budget state only when a budget exists; otherwise ring cycles never repeat and searches blow up (caught by the validator as UNVERIFIED).
- **Sequence legality** needs a simulated cascade; use `_route` + `_apply_routed` (never call `apply_move` inside `preview`).
- **JSON numbers load as floats:** convert witnesses with `PackedInt32Array(...)` before comparing.
- **QA timing:** click at least a frame after closing a dialog (a freed dialog still blocks input that frame).
- **Ring dead ends:** with a budget of 1, "ring now" is a dead end at many steps. Report non-bell choice points separately; don't sell the raw count as difficulty.

## Next tasks (in order)
1. **Owner:** finish the V3 feedback; then install v4 over it and play the ledger with `docs/EXPERT_PLAYTEST.md` (6 questions).
2. Tune the ledger from that: the order of pages, which pages are too easy or too obscure, and hint wording. Re-run `ledger_tool.gd -- build` after any change (the content hash changes; old saved attempts are set aside safely).
3. Decide whether to merge `feature/midnight-ledger` into `main` and push.
4. Arabic review now also covers ~95 ledger strings.
5. Carried over: release AAB/monetisation rebuild, publisher items, purchase verification (still not built; real purchases stay off).
