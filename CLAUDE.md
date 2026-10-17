# CLAUDE.md: working notes for agents

- The Godot project is `game/` (Godot **4.7.2-stable**, GDScript). Docs live at the repo root. `build/` is git-ignored.
- Godot binary in this codespace: `~/tools/godot/godot`. Android SDK: `~/tools/android-sdk`. JDK 21: `/usr/local/sdkman/candidates/java/21.0.12+1-ms`.
- Always run `godot --headless --path game --import` after adding files, then the tests: `godot --headless --path game -s res://tests/run_tests.gd`.
- Visual checks need a display: `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 720x1280 -- --qa=shots --qa-out=DIR`.
- **v8 core game = Delivery Logic.** Its rules live only in `src/core/delivery_rules.gd` (spec: `docs/DELIVERY_RULES.md`); play, solver, hints, deadlock checks, tests and tools all call it. Never duplicate rule logic.
- Delivery levels: `game/data/delivery/levels.json` (hand-edited, with design notes, `mistake` and `claims`). `proofs.json` is generated. After any level or rule change run `godot --headless --path game -s res://tools/delivery_report.gd -- --write` (all levels must PASS; it rewrites `docs/DELIVERY_LEVEL_REPORT.md`). `tools/delivery_gen.gd` and `tools/delivery_lab.gd` are authoring aids only.
- The retired sorting game's rules live only in `src/core/rules.gd` (validator: `tools/validate_levels.gd`). It is off the primary flow but kept; don't delete it or its save records.
- GDScript 4.7: `:=` with a Variant right-hand side is a warning here (project setting). Prefer explicit types for Dictionary and Array reads.
- UI strings belong in `tools/strings_en.py` + `tools/strings_ar.py`. Regenerate `game/data/i18n/*.json` and keep `%s` counts equal (a test enforces this).
- Never enable `BuildConfig.REAL_PURCHASES_ENABLED` without a server-side verification endpoint. Never commit keystores or credentials.
- Art, sounds and colour overrides come from skins (`game/skins/<id>/skin.json`, `ArtSkin`; see `docs/ART_PIPELINE.md`). New drawable things get a skin key with the code drawing as fallback; never hard-wire an image path.
- UI colours, sizes and components come from `src/ui/style.gd` and `src/ui/ui.gd` (see `docs/DESIGN_SYSTEM.md`); don't style screens ad hoc. For start alignment use `UI.al()` (Godot mirrors LEFT in RTL).
- Delivery QA (real input): `-- --qa=dl_journey|dl_life_a|dl_life_b|dl_look|dl_rapid|dl_migrated --qa-out=DIR` (`src/app/qa_delivery.gd`; give each its own `--save-path`). The QA unlock is the export feature `qa` (Web QA preset only).
- Screen QA: `-- --qa=tour --qa-out=DIR [--qa-lang=ar]` captures every screen. Guides/PDFs are generated (see `SESSION_HANDOVER.md`); never hand-edit `docs/TINY_STREET_PLAYER_GUIDE.md` (edit `docs/guide_src/`).
- Keep `SESSION_HANDOVER.md` current at the end of each session.
