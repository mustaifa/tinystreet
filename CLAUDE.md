# CLAUDE.md: working notes for agents

- The Godot project is `game/` (Godot **4.7.2-stable**, GDScript). Docs live at the repo root. `build/` is git-ignored.
- Godot binary in this codespace: `~/tools/godot/godot`. Android SDK: `~/tools/android-sdk`. JDK 21: `/usr/local/sdkman/candidates/java/21.0.12+1-ms`.
- Always run `godot --headless --path game --import` after adding files, then the tests: `godot --headless --path game -s res://tests/run_tests.gd`.
- Visual checks need a display: `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=shots --qa-out=DIR`.
- **Rules live only in `src/core/rules.gd`.** The solver, hints, tests and validator all call it. Never duplicate rule logic.
- Levels are fixed data. After any rule change, run `tools/validate_levels.gd`. Use the generator only for authoring.
- GDScript 4.7: `:=` with a Variant right-hand side is a warning here (project setting). Prefer explicit types for Dictionary and Array reads.
- UI strings belong in `tools/strings_en.py` + `tools/strings_ar.py`. Regenerate `game/data/i18n/*.json` and keep `%s` counts equal (a test enforces this).
- Never enable `BuildConfig.REAL_PURCHASES_ENABLED` without a server-side verification endpoint. Never commit keystores or credentials.
- UI colours, sizes and components come from `src/ui/style.gd` and `src/ui/ui.gd` (see `docs/DESIGN_SYSTEM.md`); don't style screens ad hoc. For start alignment use `UI.al()` (Godot mirrors LEFT in RTL).
- Screen QA: `-- --qa=tour --qa-out=DIR [--qa-lang=ar]` captures every screen. Guides/PDFs are generated (see `SESSION_HANDOVER.md`); never hand-edit `docs/TINY_STREET_PLAYER_GUIDE.md` (edit `docs/guide_src/`).
- Keep `SESSION_HANDOVER.md` current at the end of each session.
