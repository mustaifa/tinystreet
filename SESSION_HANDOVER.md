# Session Handover

**Last updated:** 2026-10-16, end of session 3 (v3 / 0.3.0).

## State
- The owner reports the updated Android version works on a phone (user-reported; exact build not stated) and asked for deeper play, a livelier world, stronger progression and better presentation. Audit and plan: `docs/V3_AUDIT.md`.
- **v3 delivered** (milestones A–F, see `CHANGELOG.md`):
  - **Bell mechanic.** A 12-level "Ring the bell" slice (#9–#20) with 2 special orders.
  - **Mastery ribbons.** Optional, per level.
  - **Living café.** Visitors, door, plant sway, cast cheering; décor preview/keep/revert, 4 themes, extra preview.
  - **Challenges and Daily.** 12 challenge cards; the Daily shows days played instead of a streak.
  - **Mira's Bakery.** 4 steps, 8 oven-batch levels.
  - **Save.** Schema 4 with a pre-migration backup.
- **Tests and QA.** 102/102 tests; 164/164 levels validated (bell claims re-proven). Desktop QA:
  - All 96 campaign levels won via input.
  - Scenarios: slice 4/4, v3 11/11, v2 10/10, nav 17/17, rewards 8/8; rapid, lifecycle and layouts pass. See `TEST_REPORT.md`.
- **APK: `build/tinystreet-v3-debug.apk`**
  - Package `com.tinystreet.sortrestore`, **0.3.0 / versionCode 3**, built from commit **`2297fb1`**.
  - SHA-256 `1a59a0b9ea3e7588fc898a55d9b182082bb120807377ceba2b613ad10c558c29`.
  - Signing certificate SHA-256 `62fa12828ad217be61c751322a58f2ce10988c3fccc11b1c704b7259a6281b2e`: Godot debug key, same as v1/v2, so it updates in place.
  - **Not run on Android; pending the owner's phone test** (`docs/PLAYTEST.md`).
- Earlier APKs are kept: `build/tinystreet-debug.apk` (v1), `build/tinystreet-v2-debug.apk`. The release AAB and monetisation test APK in `build/` are still **v1** builds.
- Git: v3 commits are local on `main` (not pushed). `build/` is git-ignored.

## Where things are (v3)
| Topic | Files |
|---|---|
| Bell rule | `src/core/rules.gd` (`ring`, `apply_action`, `first_tray_needing`), `puzzle_state.gd` (`pin`), `puzzle_session.gd` (`ring`, replay) |
| Solver with bell | `src/core/solver.gd` (rings as actions, never two in a row, `_onpath`, dead-state levels) |
| Bell proofs | `LevelValidator.bell_value` (`required` / `tidier` / `optional`), re-checked in `tools/validate_levels.gd` |
| Slice and specials | `tools/generate_levels.gd` (`ORDER`, `HAND` p01, `mech_tier` "p", `SPECIALS`), `src/meta/specials.gd` |
| Mastery | `Progression.record_mastery`, `mastery_target` |
| Café life and customization | `src/board/cafe_view.gd` (`_visit_state`, `_door`, `cheer`), `src/screens/restore_screen.gd` (preview/keep/revert, themes), `Restoration.THEMES` |
| Challenges | `src/meta/challenges.gd`, `src/screens/daily_screen.gd` |
| Bakery | `src/meta/bakery.gd`, `src/board/bakery_view.gd`, `src/screens/bakery_screen.gd`, `data/levels/bakery.json`, oven crates in `crate_view.gd` |
| Save | `SaveStore.SCHEMA = 4`, `_backup_before_migration` |
| Economy | `docs/ECONOMY.md` |

## Commands
```bash
G=~/tools/godot/godot
$G --headless --path game --import
$G --headless --path game -s res://tests/run_tests.gd                 # expect 102 passed
$G --headless --path game -s res://tools/validate_levels.gd           # expect levels=164 failed=0 unverified=0
xvfb-run -a $G --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=slice --save-path=user://qa_$RANDOM.json
#   scenarios: slice, v3, v2, shots, cafe, play=1-96, nav, rewards, rapid, layouts, lifecycle_a/b
cd game && $G --headless --path . --export-debug "Android Debug APK" ../build/tinystreet-v3-debug.apk
python3 tools/build_i18n.py        # after editing tools/strings_*.py
```

## Gotchas learned (v3)
- Bell rings make cycles in the search graph: the solver keeps `_onpath` and records "dead" separately for states reached right after a ring.
- Random-playout win rate never rings the bell, so it can't judge bell levels. The generator uses search proofs (`bell_value`) for them.
- `Loc.t(key, args)` fails if args are passed to a string without `%s`. Use `Challenges.goal_text`.
- Mechanic levels may not be "trivial" (random play always wins and no counter needed); the generator rejects them except tutorials.
- Earlier notes still apply (Variant `:=`, `pkill` self-match, story bubbles block QA taps).

## Next tasks (in order)
1. **Owner phone test of v3**: install over v2 (no uninstall), then the 15-minute session and the 6 questions in `docs/PLAYTEST.md`. Confirm the migration kept progress.
2. Tune from that feedback: bell levels (#9–#20), special orders, visitor frequency, token pace (`docs/ECONOMY.md`).
3. Rebuild the release AAB / monetisation test APK from v3 if a store or ad test is next. Purchase verification is still not built (`REAL_PURCHASES_ENABLED` stays false).
4. Qualified Arabic review (≈260 v2/v3 strings marked awaiting review).
5. Publisher items in `RELEASE_CHECKLIST.md`.
6. Optional: a specialist art and audio pass; more bakery levels only if the playtest says the bakery works.
