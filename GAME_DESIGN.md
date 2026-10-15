# Game Design — Tiny Street: Sort & Restore

*Working title, pending name/trademark availability checks.*

Portrait, single-player, offline sorting puzzle for adults. Sort deliveries, complete customer orders, and restore a forgotten neighbourhood café. No timers, no lives, no energy.

## Core rules (as implemented in `game/src/core/rules.gd`)

**Board**
- 2–6 **crates**, each an ordered stack. Only the **front** item is selectable. Every item behind it is drawn above it, so the whole stack is always visible.
- A **counter** with 3–4 slots (+1 temporary slot from a rewarded continue, at most once per attempt).
- Up to **3 order trays**, numbered 1..3. A deterministic **queue** of upcoming orders; the next three are previewed.
- Six products, each with a distinct silhouette: coffee cup, tea tin, croissant, cupcake, strawberry basket, chocolate box.

**A turn**
1. The player taps a crate. The front item goes to the **lowest-numbered (leftmost in LTR, rightmost in RTL) tray whose current stage still needs it**.
2. Otherwise it goes to the leftmost empty counter slot.
3. Otherwise the tap is illegal. The state doesn't change, and the player gets a gentle shake, a soft sound and an explanation.

Pressing and holding a crate previews the destination (a teal outline on the tray or counter slot) before the player releases.

**Automatic resolution** (repeats until nothing changes):
- a. Trays are checked in order. A completed stage reveals the order's next stage. A completed final stage delivers the order, and the next queued order arrives in the **same** tray.
- b. Counter slots are scanned left to right. Each item moves to the lowest-numbered tray that needs it.

**Two-stage orders** (from level 31): a tray asks for one group of products, then a second group. Both groups are shown from the start, with the second under "then".

**Win**: every order is delivered. The validator guarantees that crate supply equals order demand for each product, so all products are used up.
**Loss**: the level isn't won and no legal tap exists. Completion is evaluated first. A full counter doesn't count as a loss while a direct-to-order move exists.

**Always free**: unlimited undo (restores the complete prior state, including automatic transfers, order changes, peak counter and move count), restart, and one hint per attempt.

## Hints
Hints are computed from the **current** state with the real solver (on a worker thread, with a 30k-node budget):
- `SOLVED`: the next crate glows.
- `UNSOLVABLE`: "This position can't be finished. Undo N moves", with N found by searching recent snapshots, or "restart".
- `TIMEOUT`: "No quick hint found" (no claim is made).
One hint per attempt is free. Further hints are offered through an optional rewarded ad when ads are available. Hints never affect stars.

## Scoring (shown in the pause menu and win card)
- ★ Complete the level.
- ★★ Peak counter use ≤ `par_counter`. That is the solver's minimum achievable peak + 1, capped at capacity.
- ★★★ The ★★ conditions, plus at most 1 undo and no extra-slot continuation.

The undo count is per attempt and isn't restored by undo, so undo can't be used to erase the cost of undoing. Restart begins a new attempt.

## Economy
- **1 restoration token** for the **first** clear of each campaign level. That makes 60 tokens. Replays can raise stars but never award tokens again.
- Five milestones cost 8 / 10 / 12 / 14 / 16 tokens, 60 in total. The final milestone (sign and grand opening) therefore arrives with the final level. No purchase is needed for any restoration.
- The daily challenge awards a dated completion record and a streak only. It awards no tokens, because local clocks can be changed.

## Café restoration
| # | Milestone | Visible change | Unlocks choice |
|---|---|---|---|
| 0 | (start) | Grey, grimy facade, boarded windows and door, litter | — |
| 1 | Clean the storefront | Painted walls, tidy pavement, broom | Wall colour (cream / sage / blush) |
| 2 | Windows & entrance | Glass windows, wooden door, step, striped awning | — |
| 3 | Counter & coffee | Interior visible: counter, espresso machine, shelves | — |
| 4 | Seating, lights, plants | Tables and chairs, string lights, planters | Seating (bistro / rattan / booth), plants (ferns / olive / flowers) |
| 5 | Sign & opening | Painted sign, bunting, OPEN board, gentle confetti | Sign style (classic / modern / painted) |

The optional cosmetic purchase "Evening Lights" adds an *evening* option for walls, seating and sign. It has no gameplay effect. Choices can be revisited at any time. If an entitlement is revoked, the choice falls back to its default.

## Level format (`game/data/levels/*.json`)
```json
{"id": "c031", "counter": 3, "trays": 2,
 "crates": [["tea", "coffee"], ["croissant", "tea"]],
 "orders": [[{"coffee": 1}, {"tea": 2}], [{"croissant": 1}]],
 "meta": {"par_counter": 2, "solution": [0, 1, 0, 1], "verified": "PASSED",
          "playtest": "AWAITING_HUMAN", "tier": "two_stage", "metrics": {...}}}
```
Crate arrays list the front item first. Each order is a list of stages, and each stage maps products to quantities.

## Campaign structure
| Levels | Chapter | Focus |
|---|---|---|
| 1–3 | Opening up | Hand-authored tutorials: tap, counter, routing priority |
| 4–5 | Opening up | Forgiving, 3 crates |
| 6–15 | Morning rush | 3–4 crates, order sequencing |
| 16–30 | Busy counter | 4–5 crates, deeper stacks, 3-slot counter pressure |
| 31–45 | Two-part orders | Two-stage orders introduced (31–33 gentle) |
| 46–60 | Head barista | 3 trays, 5–6 crates, combined rules |

See `docs/LEVEL_REPORT.md` for per-level metrics. The difficulty proxies are random-play win rate, minimum counter needed, solver nodes and item count. **They are not evidence of fun or fair difficulty.** All 120 levels await human playtesting. Curve spikes to review first: c025, c034, c048, c057.

## Daily challenge
- The puzzle comes from a separate pool of 60 validated levels (`daily.json`). It's chosen by the device's **local calendar date** through a fixed, salted permutation, so the same app version and date always give the same puzzle.
- Completion is recorded once per date, and replay is allowed for fun. There's no leaderboard.
- The share card contains the date, stars and move count only. It's copied to the clipboard, because Godot has no built-in Android share sheet.

## Game feel
Pick/transfer arcs, landing pops, a lift-and-tick on delivery, a slide-in for arrivals, star pops, a restoration flash, a calm amber counter warning (no flashing), soft invalid feedback and optional haptics. Reduced-motion mode collapses all movement to near-instant changes. A tap during an animation snaps every effect to its end state first. The game state is never behind the view, so there are no lost or duplicated actions.
