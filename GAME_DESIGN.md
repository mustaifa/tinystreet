# Game Design: Tiny Street: Sort & Restore (v2)

*Working title, pending name/trademark availability checks.*

Portrait, single-player, offline sorting puzzle for adults. Sort deliveries, serve the neighbours' orders, and restore a forgotten café on Tiny Street. No timers in the campaign, no lives, no energy. One optional timed challenge (Café Rush) only counts up.

## Core rules (as implemented in `game/src/core/rules.gd`)

**Board**
- 2–6 **crates**, each an ordered stack. Only the **front** item is selectable. Every item behind it is drawn above it, so the whole stack is always visible (except paper bags, see below).
- A **counter** with 3–4 slots (+1 temporary slot from a rewarded continue, at most once per attempt).
- Up to **3 order tickets** (trays), numbered 1..3. A deterministic **queue** of upcoming orders: the next three customers and their first request are shown.
- Six products, each with a distinct silhouette: coffee cup, tea tin, croissant, cupcake, strawberry basket, chocolate box.

**A turn**
1. The player taps (or drags) a crate. The front item goes to the **lowest-numbered tray whose current stage still needs it**.
2. Otherwise it goes to the leftmost empty counter slot, unless the item is **fresh**.
3. Otherwise the tap is illegal. The state doesn't change, and the player gets a shake, a soft sound and a reason (counter full / fresh item must wait / crate strapped shut).

**Destination badge.** Each crate's front item always carries a badge showing where a tap would send it: a numbered ticket (to that order), a counter icon, a clock (fresh item has to wait), or a cross (nowhere). Shape and number carry the meaning; colour only reinforces it. Pressing lifts the item and draws a dashed guide line to its destination. Releasing over the crate or its destination confirms; dragging away and releasing elsewhere cancels.

**Automatic resolution** (repeats until nothing changes):
- a. Trays are checked in order. A completed stage reveals the order's next stage. A completed final stage delivers the order, and the next queued order arrives in the **same** tray. Crates whose lock count is reached open now.
- b. Counter slots are scanned left to right. Each item moves to the lowest-numbered tray that needs it.

**Mechanics** (each optional per level, all enforced by `Rules` and the solver):
| Mechanic | Data | Rule | First appears |
|---|---|---|---|
| Two-stage orders | an order with 2 stages | The second group is requested after the first is complete; both are shown from the start ("then"). | c031 (#41) |
| **Fresh items** | item `"coffee!"` | Must go straight into an order; can never wait on the counter. If no order needs it, the crate is blocked behind it. | f01 (#7) |
| **Paper bags** | item `"?tea"` | Hidden until it becomes the front item. Routing is unchanged; only the player's information changes. | b01 (#22) |
| **Delivery locks** | `"locks": [0, 0, 2]` | A crate stays strapped shut until that many orders have been delivered. Its tag counts down. | k01 (#58) |

**Win**: every order is delivered. **Loss**: not won and no legal tap exists. The loss dialog names the blocking mechanic if there is one. Completion is evaluated first.

**Always free**: unlimited undo (restores the complete prior state, including locks, reveals, auto transfers, move count and peak counter), restart, and one hint per attempt.

**Streaks**: consecutive moves that go straight into an order show "Nice!", "Great run!" and so on, with a rising pitch. They are cosmetic: streaks never affect stars, tokens or rules. Their only other effect is the "streak" café task and the "On a roll" award.

## Hints
Computed from the **current** state with the real solver (worker thread, 30k-node budget): SOLVED (the next crate glows), UNSOLVABLE ("undo N moves" or "restart"), TIMEOUT (no claim). Hints never affect stars.

## Scoring
- ★ Complete the level.
- ★★ Peak counter use ≤ `par_counter` (the solver's minimum achievable peak + 1, capped at capacity).
- ★★★ The ★★ conditions, plus at most 1 undo and no extra-slot continuation.

## Economy (v2)
- **Tokens = stars.** Each level pays 1 token per star, once per (level, star). Replaying 1★ → 3★ pays 2; repeating pays 0. Up to 252 tokens from the campaign.
- **Café tasks**: 3 per day (local device date), 2–3 tokens each, claimed once per date and task.
- **Achievements**: 19, 2–5 tokens each, claimed once. Two also unlock cosmetics.
- **Every reward has a ledger key** (`star:c004:2`, `task:2026-10-16:orders`, `ach:first_steps`) stored in `data.grants` and saved in the same atomic write as the balance. Reloads, replays or double taps can't duplicate a reward.
- Restoration costs 3 / 6 / 10 / 14 / 18 / 22 / 26 / 30 = 129. The first step is affordable after the first 3-star tutorial. At an average of 2 stars per level, the whole café is reachable from the campaign alone (a test enforces this). Extras (10–18 each) remain a goal afterwards.
- The Daily and Rush pay no tokens directly. Device clocks can be changed, so they only count toward tasks, achievements, a streak and a personal best.

## Café restoration (v2)
The café is an interior cut-away (`CafeView`, drawn in code). Every step changes it visibly, and decor can be changed at any time.

| # | Step | Cost | Visible change | Choices |
|---|---|---|---|---|
| 0 | (start) | | Grey cracked walls, boarded window, broken floor, dust sheet over the counter, boxes, cobwebs, flickering bare bulb, "CLOSED" | |
| 1 | Sweep & scrub | 3 | Boards off the window, clutter and cobwebs gone, steady light | |
| 2 | Paint the walls | 6 | Painted walls, wainscot, picture rail, coloured fascia | cream / sage / blush (+ evening theme) |
| 3 | Lay a new floor | 10 | New floor | oak planks / checker tiles / terracotta |
| 4 | Counter & espresso machine | 14 | Counter, steaming machine, shelves of stock, pastry case; **Mira** behind the counter | oak / marble / painted teal |
| 5 | Hang the lights | 18 | Lighting and a warm wash | pendants / string lights / brass globes |
| 6 | Tables & chairs | 22 | Two tables; **Theo** and **Mr. Basil** sit down | bistro / rattan / booth (+ evening) |
| 7 | Plants & window box | 26 | Corner plants, window box, hanging plant | ferns / olive / flowers |
| 8 | New sign & grand opening | 30 | The sign, bunting, OPEN board, neighbours at the window, confetti; the cast smile | classic / modern / painted / gilded (award) (+ evening) |

**Extras** (bought once with tokens, can be shown or hidden): wall clock (shows the phone's time), cake stand, gramophone, Pip the café cat (sleeps, tail sways), photo wall (award "The regulars").

**Buying a step**: tokens are spent once (the button is guarded against double taps), the screen flashes, confetti falls, a "Restored!" label appears and the café updates instantly. The decor picker for that step then opens with the café in view, followed by a one-to-three-line story beat. **Preview** shows the next step before buying.

A future street expansion is teased in the Journal once the café is complete (the bakery next door). It is text only: there is no button or destination.

## Cast and story
- **The player**: the café's new owner (never drawn).
- **Mira**: baker next door, warm mentor. Orders pastries (croissant, cupcake).
- **Theo**: sleepy student. Orders only coffee.
- **Mr. Basil**: retired postman, nostalgic. Orders only tea.
- Everyone else is one of six neighbour portraits.

Who orders is deterministic from the order's contents (`Customers.for_order`), so the cast's faces recur, and the tasks and awards "Serve Theo N times" follow real gameplay. Story beats (`Story.BEATS`) are 1–3 short, skippable lines at: first launch, chapter and mechanic introductions, and every restoration step. Each plays once and can be replayed from the Journal. All lines are localised (`st_*`). Portraits are original vector drawings with distinct silhouettes (bun and headscarf; spiky hair and glasses; flat cap and moustache).

## Campaign (84 levels, 6 chapters)
| # | Chapter | Focus |
|---|---|---|
| 1–8 | Opening up | Tutorials (tap, counter, priority), then **Fresh** intro f01 at #7 |
| 9–20 | Morning rush | 3–4 crates, sequencing; fresh levels f02–f05 interleaved |
| 21–40 | Busy counter | 4–5 crates, counter pressure; **Paper bags** b01 at #22, b02–b05 interleaved |
| 41–57 | Two-part orders | **Two-stage** intro c031 at #41, with fresh (f06) and bag (b06) combinations |
| 58–70 | Delivery day | **Locks** intro k01 at #58, k02–k06 with 2–3 trays |
| 71–84 | Head barista | Mixed levels x01–x06 combining everything |

New mechanics are at least 8 levels apart, each introduced by a forgiving hand-made level with a coach line (tests enforce both). Every mechanic level must exercise its mechanic on the solution line (`LevelValidator.mechanic_engagement`). The generator rejects candidates that don't, and the validator fails them.

v1 level ids keep their content (saves refer to them), except c025, c034, c048 and c057, which were regenerated to remove difficulty spikes (random-play win rates 0.03 / 0.10 / 0.06 / 0.03 → 0.29 / 0.30 / 0.37 / 0.11). These are proxies only. **No level has been human-playtested.**

## Return reasons
- **Café tasks** (Journal): three a day from a pool of 12, chosen by date. Mechanic tasks are only offered once that mechanic has been met.
- **Awards** (Journal): 19 achievements on lifetime counters.
- **Daily puzzle**: same puzzle per date and app version; streak; share text.
- **Café Rush** (Challenges): 3 validated daily-pool puzzles back to back, count-up clock, personal best, no fail state. In memory only: leaving abandons the run.
- **Journal → Progress**: chapters (levels, stars), café steps, extras, awards, streak, Rush best, and story replay.

## First ten minutes
1. Launch → Mira's 2-line welcome → level 1 (no menus, no account).
2. Levels 1–3 teach tap, counter and priority with an in-play coach and a glowing target.
3. Level 1 at 3★ pays 3 tokens → the win card's primary button becomes **Restore the café** → "Sweep & scrub": boards come off the window.
4. Level 4: Theo arrives (story). Levels 4–6 are forgiving.
5. Level 7: **fresh coffee** discovered (Theo: "No parking it on the counter!"). The clock badge shows "must wait" before the player ever taps.
6. By about level 8, two or three café steps are done (walls painted, a colour chosen). The home screen always shows the next step and its token progress.

## Game feel
Lift-and-guide on press; drag or tap; arcing flights; landing sparkles; ticket pop on stage; a delivery burst with the customer's happy face and a tick; streak words with rising pitch; unwrap and unlock bursts; confetti finish before the win card; a soft shake with a specific reason on invalid taps. Reduced motion collapses movement to near-instant changes and swaps particles for a brief still glow. A tap during any animation snaps every effect to its end state first: the game state is never behind the view, and pausing clears effects without touching state.
