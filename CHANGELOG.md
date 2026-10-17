# Changelog

## 0.2.1, 2026-10-17
- Added keyboard and D-pad activation for gameplay crates and shared UI buttons, including Enter/Space activation for a focused crate.
- Gameplay destination badges, lock counts and order-ticket numbers now respect the existing larger-text setting.
- Corrected the README to describe the 84-level campaign and the actual skippable first-run intro flow.

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
