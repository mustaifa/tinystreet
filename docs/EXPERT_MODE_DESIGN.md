# The Midnight Ledger: expert mode design (v4, 0.4.0)

*After closing time, the café owner finds a ledger of unusually difficult orders. Each page is a compact logic puzzle.*

An optional mode for players who like to plan several steps ahead. It is a separate collection: the campaign, café, bakery, economy and difficulty are unchanged. It pays **no tokens**.

## Baseline verified before work (2026-10-16)
- Branch `feature/midnight-ledger`, created from `main` at `618cf5a` with a clean tree.
- Version 0.3.0 / versionCode 3; save schema 4; package `com.tinystreet.sortrestore`.
- Re-run: **102/102 tests, 164/164 levels**.
- `build/tinystreet-v3-debug.apk` SHA-256 `1a59a0b9…8c29` (unchanged and not overwritten).

## Rules: what is reused and what is new
Everything from the café applies unchanged: crates (front item only), the counter, tickets, the queue, fresh items, strapped crates, and the **bell exactly as in v3** (ring a ticket and it is served first; it stops when that order is served). Bags are excluded from the ledger, so no information is hidden.

Two **constraints** were kept after prototyping; both are rules in `src/core/rules.gd`:

| Constraint | Data | Rule | Why kept |
|---|---|---|---|
| **A. Bell budget** | `"bell_budget": n` | Every ring uses one, including ringing to stop a bell. With none left, ringing is refused (the ticket shows a crossed-out bell and says so). | Turns the bell from "free" into a decision: *when* is a ring worth it? Proven minimum rings range from 0 to 3. |
| **B. Order sequence** | `"sequence": [o1, o2, …]` | Listed orders must be served in that order. A tap whose result (including the cascade it triggers) would serve a listed order early is refused, with "Not yet: the ledger says X must be served first". Unlisted customers can be served any time. | Creates backward reasoning and the "a good-looking move blocks a later need" deduction without new objects on screen. |

Not kept:
- **C. Reserved space**: the counter already provides a scarce, clearly visible space (one-space counters on several pages). A new space type would have added a rule without adding a deduction.
- **D. Precision contract**: kept as an optional **badge, not a constraint**, and only where it is proven. A move is one crate tap or one bell ring; every solution taps exactly once per item, so the minimum number of moves is items + the **proven minimum rings**. It is offered only where the budget allows more rings than the minimum (2 pages). Elsewhere it would be either automatic or meaningless.

One consequence handled explicitly: with a sequence, a ring can redirect a cascade and turn a refused tap into a legal one. So "lost" now means *no legal tap and no single ring that would create one* (`Rules.is_lost`). Without a sequence this is identical to v3.

## The collection (13 pages)
| # | Page | Group | Reasoning idea (tag, machine-verified) | Designer difficulty (provisional) |
|---|---|---|---|---|
| e01 | One Bell | lesson | when a single bell is worth ringing (`bell_timing`) | 1/5 |
| e02 | The Last Shall Be First | lesson | an order sequence where the first required customer arrives last (`backward`) | 1/5 |
| e03 | The Precise Hand | lesson | the precision badge: one ring where two are allowed (`precision`) | 2/5 |
| e04 | One Empty Chair | puzzle | the one counter space must hold the right item (`empty_space`) | 2/5 |
| e05 | Patience | puzzle | delay a tempting completion (`delay_completion`) | 2/5 |
| e06 | Last Orders | puzzle | work backward from the last customer's final item (`backward`) | 3/5 |
| e07 | The Quiet Bell | puzzle | ring only after arranging the board (`ring_late`) | 3/5 |
| e08 | False Economy | puzzle | finishing an unlisted order blocks a later need (`local_good`) | 3/5 |
| e09 | Three Bells | puzzle | three rings are proven necessary (`min_rings`) | 3/5 |
| e10 | Hot Croissants | puzzle | fresh items + sequence + bell (`fresh`) | 4/5 |
| e11 | The Strapped Crate | puzzle | a strapped crate + sequence + bell (`lock`) | 4/5 |
| e12 | Two Lessons | puzzle | patience and the quiet bell in one board (`combine`) | 4/5 |
| e13 | The Midnight Ledger | final | sequence of three, one bell, one counter space, two hot items (`combine`) | 5/5 |

**How pages were made.**
1. `tools/ledger_tool.gd -- search <goal>` generates small boards (2–3 crates, 6–14 items, 2 tickets, 4–5 orders, all orders visible from the start). It keeps only boards where the constraint changes the answer and where proven dead ends exist at several steps.
2. Each kept board was reviewed step by step (`-- review`), with every alternative at every step classified by exhaustive search.
3. Boards were chosen for a single clear idea, then named, given distinct named customers, hints and a "why this works" written from the trace.
4. `-- build` re-proves everything and **fails** if a page doesn't exhibit its stated idea (`LedgerAnalysis.verify_idea`).

Boards with a bell budget but no sequence almost never *needed* a ring: the budget-only searches kept 1 board out of about 1,600 candidates (it became e01), and the precision search kept 1 out of 600 (e03). So bell pressure comes from budgets combined with sequences. Nothing is labelled "genius", and nothing claims to measure intelligence.

**Unlocks.** The mode opens after the bell lesson (p01, campaign #9): a one-time "Try expert mode" button on Home and a card in Challenges. Lessons open one after another, the nine puzzles open after the lessons, and the final page opens after any six puzzles. There is no grind and nothing to buy.

## Interface
- **Expert strip** under the orders bar: bells left (∞, or a number), a move counter (with "/target" where precision is offered), and the order sequence as customer faces with ticks and a gold ring on the next one.
- **Rule card** (book icon, top right): goal, budget, sequence with names, fresh/strapped rules if present, the definition of a move, the precision target, badges.
- **Undo, Redo, Hint, Restart.** Undo restores the full state, including bell budget, bell and order progress. Redo is cleared by any new action. Restart starts a fresh attempt with the full budget and never re-grants rewards.
- **Save and resume.** The attempt (moves, redo stack, hint use) is saved with the page's **content hash**. A saved attempt whose hash no longer matches the shipped page is set aside with a message, never loaded against different rules.
- **Planning markers**: not included. The board is small and every order is visible; markers were judged not worth the small-screen clutter (revisit after playtests).

## Hints (three stages)
1. **The idea**: a conceptual nudge written for that page.
2. **The bottleneck**: a more specific explanation, plus live facts for the current position (bells left, next in sequence, free counter spaces).
3. **One verified move**, highlighted:
   - If the player is still on the shipped witness, its next action (proven by replay).
   - Otherwise, a bounded search from the exact current position (150k nodes, worker thread; the UI never blocks): SOLVED gives its first action; UNSOLVABLE says the position can't be finished and offers to undo back to the last point on the proven solution, undo or restart; TIMEOUT says the search couldn't decide and offers the witness checkpoint.
   - It never suggests a random legal move, and never shows the full answer.

Opening any stage forfeits the optional no-hint badge for that completion; everyone can still finish. There are no paid hints, ads or energy.

**"Why this works"** after completion: the page's explanation, plus an honest line saying whether the player's sequence matched the reference solution or was a different valid route.

## Rewards (no tokens)
| Reward | Rule | Ledger |
|---|---|---|
| Stamp | first completion of a page | `data.ledger.done` |
| No-hint badge | a completion with no hint stage opened | `data.ledger.nohint` |
| Precision badge | completion in ≤ the proven minimum moves (e03: 9, e09: 11) | `data.ledger.precision` |
| Midnight Lantern | a café extra (hangs by the window) when all 13 pages are stamped | `grants["ledger:collection"]`, `restoration.extras.lamp` |

Improving a badge later never re-grants the stamp. Rewards are saved in the same atomic write as everything else.

## Save compatibility
No schema bump was needed (still schema 4): the new `data.ledger` block is additive and filled with defaults by `GameData.sanitize`. A schema-4 v3 save loads unchanged, with no migration and no backup file written (tested). All earlier migrations (v1/v2 → 4, with backups) are untouched.

## Solver audit and changes
- **Search key** (`PuzzleState.key`) now includes `rings_used`, because the remaining budget affects future legality. The sequence's progress is derived from the queue and tickets, which were already in the key.
- **Ring handling** (v3) still applies: rings are actions, never two in a row, cycles are cut by `_onpath`, and dead states are recorded separately for "just rang". With a budget, rings only increase `rings_used`, so there are no new cycles.
- **Sequence legality** is computed by simulating the cascade on a copy (`Rules._apply_routed`), so the solver, hints, UI and validator all share one rule.
- **TIMEOUT is never treated as UNSOLVABLE.** Proofs require UNSOLVABLE from exhaustive search; build fails otherwise.
- **Cross-check**: on 100+ tiny random boards with budgets and sequences, the optimised solver agrees with a plain exhaustive reference search (`test_solver_matches_reference_on_tiny_boards`).
- `Solver.VERSION = "4.0-ledger"` is recorded in every proof.

## Measuring difficulty honestly
See `docs/EXPERT_PUZZLE_PROOFS.md`. Proven: witness replay, minimum rings, dead ends at each step (exhaustive), choice points, first actions that survive. Designer estimates: the 1–5 difficulty column. Human-tested: **none yet**. The old random-playout metric isn't used, because it never rings a bell.
