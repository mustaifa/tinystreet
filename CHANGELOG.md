# Changelog

## 0.8.0 (v8), 2026-10-17: Delivery Logic, a rebuilt core puzzle
The owner found the sorting game "feels like clicking highlighted items rather than solving puzzles" and authorised a core rebuild. v8 replaces the puzzle with **Delivery Logic** (working title): a courier pushes picture-marked crates onto matching pads in small storerooms. Save schema 5 → 6. Branch `feature/delivery-logic`.

### New game
- **Rules** (`docs/DELIVERY_RULES.md`) in one module, `src/core/delivery_rules.gd`, used by play, solver, hints, deadlock checks, tests and tools. Walk orthogonally; push one crate if the square beyond is free; no pulling, no double pushes; a wrong pad doesn't count; crates stay movable; undo/redo/restart free. Tap-to-walk only through free floor, never pushing.
- **Solver** (`delivery_solver.gd`): breadth-first over push positions (crate cells, crates of one symbol interchangeable, courier region), exact visited set, provably-dead positions pruned soundly, incremental (`step(budget)`, no threads, so the web build works). SOLVED / UNSOLVABLE / TIMEOUT are distinct; a timeout never claims "no solution"; every solution is replayed through the rules.
- **Deadlocks**: dead cells per symbol (a corner with no matching pad), freeze deadlocks (crates that can never move again), and exhaustive search. Soundness is property-tested: every instant claim is confirmed by exhaustive search on hundreds of random positions.
- **Route blocked** card with the specific proven reason; Undo (primary) and Restart; board stays visible and playable; no reward. Positions the game can't prove stay silent.
- **Hints** (opt-in, recomputed from the position, stale requests cancelled): idea → strategy (which crate, "move it away from its pad first", proven fewest pushes left) → one push (arrow). In a dead position: how many undos lead back to a solvable one.
- **Puzzle Solved!** card: level title, pushes and steps separately, completion reward actually paid (or "already collected"), personal best, **Fewest pushes** medal only against a proved minimum, **Solved without hints** badge; Next Puzzle primary, Replay and Home secondary. Last puzzle → Finish → finale.
- **30 puzzles** in 7 chapters (3 lessons, then 27 that pass every quality gate; `docs/DELIVERY_LEVEL_REPORT.md`, `docs/DELIVERY_DESIGN.md`). Minimum pushes proved and stored in `data/delivery/proofs.json`.
- **Board** (`src/board/delivery_board.gd`): round pads vs square crates, symbols by shape and colour, pad visible under crates (check badge when matched, pad tab when wrong), courier faces its direction; swipe (one move per gesture), arrow buttons, tap-to-walk, keyboard; animations snap on new input; reduced motion honoured; never mirrored in Arabic. Skin keys `delivery.*` with vector fallback.
- **Screens**: `puzzle` (play), `puzzles` (list by chapter with best and medals), Help rewritten for the new rules (four symbols), Home Play/Continue and tiles (Puzzles · Restore · How to play), first launch → two lines from Mira → Puzzle 1.

### Rewards and saves
- First clear pays 3 / 4 / 5 tokens (135 total ≥ the café's 129), once per level via the grant ledger (`dl:clear:<id>`); medals pay nothing; undo, replay, reopening and restarts can't pay twice.
- Schema 6 adds `logic` {cleared, best, medals, current}, separate from the sorting records; older files are backed up as `.schema5.bak` before the first migrated write; nothing new is marked solved; tokens, restoration and old records are untouched.
- The attempt in progress (position **and** undo/redo history) is saved on every move and on background; it resumes only against the same layout (content hash) and is discarded with a notice if the level changed.

### Retired from the primary flow (not deleted)
Sorting campaign, bakery, Midnight Ledger, daily and challenge entries are hidden from Home; source, levels, tests and player records remain. The Journal chip appears only while something is claimable.

### Builds
- Android 0.8.0 / versionCode 8, same package and debug key as v1–v7.
- **Web** (`build/web/`, single-threaded, no special headers) and **Web QA** (`build/web-qa/`, export feature `qa` opens every puzzle; not present in player builds).

### Tools and QA
- `tools/delivery_report.gd` (gates + report + proofs), `tools/delivery_lab.gd` (metrics, `--explain` traces), `tools/delivery_gen.gd` (placement search inside hand-drawn rooms; authoring aid only).
- Tests: `test_delivery_rules.gd`, `test_delivery_meta.gd`, `test_delivery_levels.gd`.
- Real-input QA journeys `dl_journey`, `dl_life_a/b`, `dl_look`, `dl_clip_*` (`src/app/qa_delivery.gd`); recordings in `docs/recordings/`.

## 0.7.0 (v7), 2026-10-17: gameplay clarity (score, results, failure)
After the owner's feedback ("feels basic; doesn't clearly communicate scoring, winning, losing or progression") and an external Appetize playtest of 0.5.0. Puzzle rules, level data and the economy are unchanged. The save schema goes 4 → 5 (adds best scores only).

### Bug fixes (confirmed by real-input QA)
- **Result card could vanish.** Any tap in the second after the winning move (crate, ticket, Undo, Restart, Hint) snapped effects and, with them, killed the delayed tween that showed "Orders delivered!". The player was left on a finished board with no result and no Next. The same applied to the "No moves left" card, the Café Rush hand-off and the Midnight Ledger "Page solved" card. All four now use a scene-tree timer that effects can't cancel. Found by the new `player` QA scenario ("stray taps" step).
- **Story popup before the result.** The first-served and special-order beats were shown before the win card, so players had to dismiss a story to learn they had won. They now play after the result, when the player picks Next, Replay or Café.
- **Restart, Undo or Pause during the win delay** could start a new attempt or open Pause under the incoming result. A won attempt now ignores them.
- **Two main buttons on the first win** ("Restore the café" above "Next level"). Next is now always the only primary action; Restore is an inline key on the café-goal row.
- **Last level:** the win card offered "Next level" on level 96 (it went to the finale anyway). It now says "Celebrate the grand finale" (bakery: "Back to the bakery").
- `SaveStore.delete_all()` left the `.schema4.bak` migration backup behind.

### Design changes
- **Live score**, separate from stars and tokens: +10 for each item served straight from a crate, +5 from the counter, +25 per order, and +10 per unused counter space at the end. It is derived from puzzle state, so undo, redo, restart and resume are exact; taps, bells, undos and hints earn nothing. Points pop up (+10 / +5 / +25) where they are earned, and the readout rolls up. **Personal best** per level ("New best!").
- **Heads-up strip** on every puzzle: Orders n/N (with a bar) · Score · Counter used/size (amber at one space left, terracotta "FULL"), above the upcoming-customer queue. The subtitle states the goal ("Opening up · Goal: serve all 4 orders").
- **"Level complete!" card** about 0.6 s after the last delivery (was 1.0 s, sometimes behind a story popup): stars, the score counting up, a one-line breakdown, tokens actually paid ("Spend tokens to restore the café"), the next café step, then Next level / Replay · Café.
- **Failure card:** "No moves left" names the cause (a full counter with nothing wanted, a fresh item, a strapped crate). **Retry level** is primary and **Undo last move** (free) secondary. A full counter is explained as not a loss while deliveries remain ("Counter full: only items an order needs can move now"; Help gains "A full counter").
- **Board:** crates settle down as they empty (no tall empty slats), and queued items are larger (76% of the front item).
- Pause lists the points rules under the star rules; Help gains "Score, stars and tokens".
- New EN/AR strings (about 25 keys; the Arabic is unreviewed).

### Level audit (no data changes)
Levels 1–3 can't be lost; level 4 is the first genuine-loss level (random legal play wins about 80%), level 6 about 53%. Scores vary with play from level 1 (105–120). Move limits weren't added: every solution takes one tap per item, so a move limit would mean nothing.

### QA
New real-input scenarios `player`, `player_reopen` and `finale` (`tools/qa_battery.sh` runs them first), and `tests/test_score.gd` (13 tests).

## 0.6.0 (v6), 2026-10-16: production polish, phase A (skins, art, sound, board)
First step of the production plan (`docs/PRODUCTION_ROADMAP.md`), with the owner's direction: **free resources only for now, and built so art can be swapped easily later.** Puzzle rules, levels, economy and save format are unchanged (schema 4).

### Skins: all art, sound and colour can be replaced without code
- New **`ArtSkin`** system (`src/ui/art_skin.gd`): a skin is a folder with a `skin.json` that maps keys (`product.coffee`, `board.counter`, `character.mira.happy`, `icon.gear`, `bg.cafe.wall`, `sfx.deliver`, `music.cafe`, …) to SVG/PNG/WebP/OGG/WAV/MP3 files, plus optional colour-token overrides.
- Skins can **extend** another skin and override only some keys (seasonal or purchasable themes later). They load from `res://skins/` or, for future downloads, `user://skins/`. Every missing key falls back to the built-in art, and errors never crash the game.
- Nine-patch support (margins in design pixels, density-aware, optional tiling), "cover" backgrounds, tintable icons (mirrored in Arabic), per-sound volume.
- Colour tokens in `Style` are now `static var`s, so a skin can recolour the UI.
- `--skin=<id>` previews a skin; `tools/skin_sheet.gd` renders a contact sheet of a skin's images.
- Guide: **`docs/ART_PIPELINE.md`** (every key, size and format, plus the workflow for an art drop). Tests: `tests/test_skin.gd` (6 tests).

### New default art and sound (free)
- **Products redrawn** as shaded SVG illustrations (gradients, highlights, soft shadows) with the same distinct silhouettes; new paper bag.
- **Wooden crate, crate front, counter and counter plates** as nine-patch SVG art.
- **Sound effects** replaced by Kenney's CC0 packs (plate and wood impacts, chimes, chips for coins, paper slide for bags, a real bell; pizzicato win jingle). Credited in-game and in `THIRD_PARTY_NOTICES.md`.

### Puzzle board
- **Order tickets show one picture per unit** ("2 coffees" = two cups), ghosted until filled and then ticked. This replaces the small icon plus dot pips. Tickets are sized to their largest stage.
- **Crates fit their contents**: a crate is as tall as its starting stack, and the café wall shows above short crates. Front items are larger (up to 136 px); stacked items are larger too (70% of the front, was 62%).
- Less text: the "Counter 0/3" caption is gone (the plates show it; warnings still use the status line), and "Orders 1/6" is now "1/6" beside the bar.

### Home and win card
- Home: the **Play key leads with the level number** ("Level 54", with "Continue · chapter" under it). The help chip moved off the top bar (Help stays in Settings and on every puzzle).
- Win card: stars, then a **coin reward that counts up** with coin sounds, one quiet stats line instead of three stat chips, the next café step, and the actions. Award and task notices are no longer repeated here (the home screen badges them).

## 0.5.0 (v5), 2026-10-16: UI polish ("an inviting miniature café street")
After the owner's phone feedback ("the screens work, but the UI looks dull and does not feel inviting"). A presentation and usability milestone: **puzzle rules, level content, economy and save format are unchanged** (schema 4; the level validator and ledger proofs re-run clean). Design: `docs/DESIGN_SYSTEM.md`.

### A cohesive look
- **Design system** in `style.gd` / `ui.gd`: colour and state tokens, a type scale, spacing and motion tokens, and shared components (tactile keys, chips, pills, tags, progress bars, medallions, list rows, segmented control, switch, badges) used by every screen.
- **Tactile keys** with a darker bottom edge that sink when pressed; round icon chips instead of outlined squares; slim warm scroll bars.
- **~60 vector icons** in one stroke style (new: map/levels, brush, moon, lantern, stamp, calendar, bolt, music, sound, vibrate, target, shield, and more); product icons reuse the game's own art.
- **Themed backgrounds**: café wallpaper, a night sky for the Midnight Ledger, rose for the bakery. Puzzle boards get a matching setting (night: midnight lattice and walnut counter).

### Screens
- **Home**: the café now stands in a **shop front** (striped awning, pillars, pavement, planters); one clear **Play / Continue** key with the level and chapter; a tappable next-step card with progress and **Ready!**; "next door" cards for the bakery and the ledger; illustrated tiles for Levels, Restore and Challenges with notification dots.
- **Level map**: chapter cards with progress and stars; finished chapters fold away; four distinct level states (completed with stars, current with a play mark, locked with a padlock, mastered with a rosette); tapping a locked level explains what opens it; a sticky **Play level N** key.
- **Puzzle screen**: chips in the top bar, a reserved status pill that never moves the board, a coach bubble with an icon, and a **dock** for Undo / Hint / (Redo) / Restart with captions and a free-hint count.
- **Win card**: stars land one by one, three stat chips, one rewards line, one tip, the next café step; **Next level** is the main action with **Replay** and **Café** side by side. Long cards now scroll instead of running off-screen (the v4 win card's last button was cut off).
- **Restore**: shop front, a sticky **Previewing … Keep / Revert** bar, a step card with a stepper and a clear cost and shortfall, colour swatches for décor options, extras with Owned and Shown/Hidden states.
- **Challenges**: illustrated Daily (calendar page), a night card for the Midnight Ledger, challenge cards with goal icons, reward and **Done**, and a Rush card.
- **Midnight Ledger**: a night-sky collection with an illustrated ledger, a stamp tracker, parchment page cards grouped as Lessons / Puzzles / The final page, and badge tags. In play: a readable **strip** (bell budget as bell icons with spent ones crossed out, moves vs target, the serve order as faces), an icon-row **rule card**, a **1 Idea / 2 Bottleneck / 3 Move** hint stepper, a stamp that lands on completion, and night dialogs.
- **Bakery, Journal, Settings, Help, Credits, Privacy, Shop, Boot**: rebuilt from the same components (segmented tabs, real On/Off switches, grouped settings, icon-led help cards).

### Interaction and motion
- Immediate press feedback on every key; short screen transitions (fade and rise); limited, gentle emphasis on the next action; a pill-style toast.
- **Double-tap protection**: keys ignore a second press within 350 ms and any press during a screen transition.
- Reduced motion turns off transitions, pulses, flights and confetti.

### Fixes found during visual QA
- Arabic: start-aligned text appeared on the wrong side (Godot already mirrors LEFT in RTL; the old code flipped it twice).
- Arabic: "Redo" and "Restart" used the same word; now distinct (still awaiting a qualified review).
- "How to play" said each level pays 1 token; it actually pays 1 token per new star. Text corrected (EN and AR).
- The 20:9 layout separated the awning from the café; icon-only buttons lost their text; long décor names were clipped; the ledger move counter was clipped in RTL.

### Documentation
- `docs/TINY_STREET_PLAYER_GUIDE.md` / `.pdf`: the complete illustrated guide with a generated appendix of every level and page (from game data).
- `docs/TINY_STREET_SOLUTIONS_APPENDIX.md`: verified walkthroughs for every level, replayed through the real rules (spoilers, separate file).
- `docs/ANDROID_ACCEPTANCE_TESTS.md` / `.pdf`: a 15-minute smoke test, a detailed regression checklist and optional playtests, all NOT RUN.
- `docs/DESIGN_SYSTEM.md`, before/after screenshots in `docs/screenshots/v5/`.

### Technical
- Version 0.5.0 / versionCode 5; same package and debug key. Save schema 4, unchanged. No new binary assets.
- New tools: `game/tools/guide_data.gd`, `tools/build_guide_appendix.py`, `tools/build_guide_pdf.py`, `tools/export_screenshots.py`. New QA scenario `tour` (every screen, EN/AR, any size). New tests `tests/test_ui.gd` (4).

## 0.4.0 (v4), 2026-10-16: The Midnight Ledger (expert mode)
Built while the owner's V3 phone feedback is still pending. The campaign, café, bakery, economy and difficulty are **unchanged**. Design: `docs/EXPERT_MODE_DESIGN.md`.

### New
- **The Midnight Ledger**, an optional expert mode: 3 lessons, 9 puzzles and a final page. Small boards, explicit rules, no timers. Entry from Challenges and a one-time "Try expert mode" button on Home after the bell lesson.
- Two constraints, as rules in `rules.gd`:
  - **bell budget**: every ring counts, refused when spent;
  - **order sequence**: a tap that would serve a listed customer early is refused, including through cascades.
- The bell itself works exactly as in v3.
- **Expert strip**: bells left, moves (with a proven precision target where offered), and the order sequence as faces.
- **Rule card**, **redo**, and resume protected by a content hash.
- **Three-stage hints** (idea → bottleneck with live facts → one verified move). They never suggest a random move. When stuck, they offer to undo to a point on the proven solution. A search timeout is reported as "couldn't decide", never as "unsolvable".
- **"Why this works"** after each page, stating honestly whether your route matched the reference.
- **Rewards without tokens**: stamp, no-hint badge, precision badge (2 pages, proven minimal), and the Midnight Lantern café extra for the full collection. All granted once.

### Proofs and tooling
- `tools/ledger_tool.gd` (search / review / build): witness replay through the real rules, proven minimum rings, every alternative at every witness step classified by exhaustive search, and a machine-checked "idea" per page. The build fails if any proof or idea check fails.
- Outputs: `docs/EXPERT_PUZZLE_PROOFS.md` (no spoilers) and `docs/EXPERT_SOLUTIONS_SPOILERS.md`.
- Solver `4.0-ledger`: the search key includes the rings used. Cross-checked against a brute-force reference on 100+ tiny boards.

### Fixed during QA
- With a spent budget, tickets ignored taps and gave no explanation; they now show a crossed-out bell and a message.
- "Why this works" compared the route against JSON floats and wrongly said "different".
- The Home invitation overflowed the screen width.

### Technical
- Save schema stays **4**: the new `ledger` block is additive (tested with a V3 save; no migration, no backup needed).
- Version 0.4.0 / versionCode 4. Same package and debug key.

## 0.3.0 (v3), 2026-10-16
Built after the owner reported that the updated Android build works on a phone (exact build unspecified) and asked for deeper gameplay, a livelier world, stronger progression and better presentation. Audit: `docs/V3_AUDIT.md`.

### Deeper puzzles
- **The bell** (new rule): tap an order ticket to ring its bell, and that customer is served first, from crates and from the counter. Free, undoable, clears on delivery. Crate badges update instantly, so you see the consequence before tapping. The solver, hints ("Ring the bell on ticket 2"), validator and generator all understand it. Bell levels are **proven** by search to need it (`required`) or to be tidier with it (`tidier`).
- **v3 slice: "Ring the bell"** (levels 9–20): a hand-made bell lesson whose coach follows the real solution, then alternating decision and relaxed levels. Two **special orders** (3-part catering orders with a gold frame, a story beat and a one-time reward). The slice ends with the key to the bakery.
- **Mastery ribbon** per level: tidiest possible counter (solver-proven minimum) and no hint. Optional, tracked separately from first clear, pays 1 token once.

### A living café
- Neighbours come in through the new side door, queue, get served by Mira and leave with their drink. Plants sway, the door swings, and the cast cheers on milestones.
- Décor is **previewed before you keep it** (Keep / Revert). Owned choices switch for free. Four **themes** (Classic, Garden, Parisian, Harbour). Extras can be previewed before buying.
- New earned decorations: chalkboard menu (special order p06) and bread basket (bakery special m08).

### Progression and replay
- **Challenge cards**: 12 validated puzzles, each with one goal and a one-time reward; replayable.
- The Daily shows **days played** instead of a resetting streak.
- New story beats: first customer served, the bell, both special orders, the bakery opening, Mr. Basil's loaf. All replayable from the Journal.
- Economy reviewed and documented in `docs/ECONOMY.md`.

### Mira's Bakery (second destination)
- Unlocked by the p12 special order. It has its own look (brick oven with a live fire, rose-and-mint tiles, awning), a 4-step restoration with choices, and 8 levels with **oven batches**: a locked crate drawn as an oven, full of hot pastries. It shares tokens and saves with the café.

### Technical
- Save schema **4** (additive). The old save file is copied to `save.json.schema<N>.bak` before the first migrated write. Nothing is reset or paid twice; tests cover a full v2 player.
- Tests 81 → 102. QA scenarios `slice` and `v3` added. 164 levels validated (96 campaign + 8 bakery + 60 daily), with bell claims re-proven.
- Version 0.3.0, versionCode 3. Same package and debug signing key as v1/v2, so it installs over them.

## 0.2.0 (v2), 2026-10-16
Built after the first real-device smoke test. The owner's report: v1 installs and renders correctly, but feels very basic.

### Feel
- Every crate's front item shows **where a tap will send it**: a numbered order, the counter, "must wait" (fresh) or nowhere. These are shapes and numbers, not colour alone.
- Press lifts the item and draws a dashed guide line to its destination. **Drag or tap**; dragging away cancels.
- Landing sparkles, ticket pops, a delivery burst with the **customer's happy face**, unwrap and unlock bursts, and a confetti finish before the win card.
- **Streaks** ("Nice!", "Great run!", …) for consecutive direct deliveries, with rising pitch. Cosmetic only.
- **Orders bar** (delivered / total) and a **next-customers** row showing who arrives next and what they want first.
- Specific reasons for refused taps and losses (counter full, fresh item must wait, crate strapped shut).
- Café backdrop behind the puzzle (wallpaper, counter top), restyled crates and order tickets.
- New sounds (streak, coin, paper bag, unlock) and a longer 87 s music loop that now loops correctly from its import settings.

### New gameplay
- **Fresh items** (steam ring): must go straight into an order, never onto the counter.
- **Paper bags**: contents hidden until they reach the front.
- **Delivery locks**: strapped crates open after N orders.
- Each is introduced by a forgiving hand-made level with a coach (levels 7, 22 and 58), then mixed in gradually. Two-stage orders now have a coach too (level 41).
- Campaign **60 → 84 levels** in 6 chapters. The flagged spikes c025, c034, c048 and c057 were regenerated.
- Generator, validator and solver understand all mechanics. Mechanic levels must use their mechanic on the solution line.

### Café restoration
- New **interior café** with 8 visible steps: clean, walls, floor, counter, lights, seating, plants, sign and grand opening.
- 7 decor categories with 3+ choices each (plus the evening theme and a gilded sign award). The picker opens right after purchase, with the café in view.
- **Preview** of the next step, its cost and a token progress bar on Home, the win card and Restore.
- **Extras**: wall clock, cake stand, gramophone, Pip the café cat, photo wall (award).
- Celebrations on every step, with a bigger one for the grand opening.
- Tokens are now **stars**: 1 per star per level, once. The first step costs 3 and is affordable after level 1.

### Personality and return reasons
- Cast: **Mira** (baker next door), **Theo** (student, coffee), **Mr. Basil** (retired postman, tea) and six neighbours. Short, skippable story beats at chapter, mechanic and restoration moments. The cast appears in the café as it is restored.
- **Journal**: 3 café tasks a day, 19 awards (tokens and two cosmetics), a progress overview and story replays.
- **Challenges**: Daily puzzle plus the optional **Café Rush** (3 puzzles, count-up clock, personal best).

### Technical
- Save schema **3** with migration from v1/v2: café milestones map onto the new steps, earned stars are credited, and the balance never drops.
- **Idempotent reward ledger** for stars, tasks and awards. Restore purchases are double-tap safe.
- Pause clears in-flight effects without touching state.
- Tests 50 → 81, including a compile check of every script. A QA `v2` scenario drives drag, mechanics, restore, tasks and Rush through real input. A QA `cafe` scenario captures every café state.
- `tools/build_i18n.py` builds and checks the string tables (EN and AR; Arabic still awaiting review).

## 0.1.0, 2026-10-15
First playable: 60 levels, 5-milestone café, daily challenge, EN/AR, simulated or opt-in monetisation, debug APK.
