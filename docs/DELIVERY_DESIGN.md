# Tiny Street: Delivery Logic — Design Notes (v8, 0.8.0)

*"Delivery Logic" is an internal working title, not a trademark claim.*
Rules: [`DELIVERY_RULES.md`](DELIVERY_RULES.md). Per-level analysis:
[`DELIVERY_LEVEL_REPORT.md`](DELIVERY_LEVEL_REPORT.md) (generated).

## 1. Why the core was rebuilt

**Owner feedback:** the game "feels like clicking highlighted items rather
than solving puzzles"; a substantial gameplay rebuild was authorised.

**External evidence (an Appetize test of 0.5.0, reported to us, not re-run
here):** level 1 was playable and paid 3 stars and +4 tokens; Next Level opened
level 2; a story popup preceded the result (fixed in v7); there was no live
score (added in v7, now retired with the mode); level 2 allowed a full counter
while direct deliveries remained; loss/retry was not verified; one session
hit Appetize's 3-minute limit and another returned to the opening screen for
an unestablished reason. Only level 1 and part of level 2 were covered.

**Audit of the retired sorting mode** (from `docs/LEVEL_REPORT.md`, 96
campaign levels; these numbers describe that game only and are not
comparable with Delivery Logic's agents):
* Every solution is exactly one tap per item; the game picks each item's
  destination automatically. The decision is *which crate next*, not *where*.
* Median random-play win rate 34% (mean 42%); 26 levels at 50% or more, 6
  at 100%, 4 at 0% (the bell-required levels). So the content was **not
  uniformly trivial**.
* In 68 of 96 levels the solver's search was nearly linear (positions
  explored ≤ 1.5 × solution length): few positions offered a choice with a
  real consequence, and the hint (a glowing crate) resolved most of the rest.

The rebuild keeps the café, restoration economy, saves, settings, audio,
localisation and UI kit, and replaces the puzzle.

## 2. The game in one paragraph

A courier walks a small storeroom grid and pushes crates (never pulls, never
two at once) onto pads with the matching picture (coffee, croissant,
strawberry, tea). Crates stay movable after delivery; a crate on the wrong pad
doesn't count. Wrong pushes can trap crates for good. Undo, redo and restart
are free. The game proves when a position can no longer be finished and says
why.

### Why this asks for thought
The levels are built so that, in verified ways (see each level's *mistake*
and *claims* in the report):
* the closest delivery is often wrong (pads in dead ends: deep pad first);
* a crate must leave its own pad, or move away from it, and come back;
* a pad or a crate is also a doorway the courier still needs;
* the courier must get to the correct side of a crate before a route closes;
* identical crates must be assigned to the right pads (d15, d20, d24, d25);
* a tempting push causes a dead end that looks harmless (a **silent** trap,
  proved only by exhaustive search).

Hints never draw a path. Tier 3 shows **one** push.

## 3. How the content was made (honest account)

* **Lessons d01–d03 and d04** were designed by hand.
* **d05–d30**: I drew small room skeletons by hand (walls only), then a
  placement-search tool (`game/tools/delivery_gen.gd`) tried random crate,
  pad and courier placements in each and kept those whose complete analysis
  showed traps, silent traps and failed baseline agents. Every kept layout
  was then traced push by push (`tools/delivery_lab.gd --explain`),
  understood, and documented with its insight, a plausible mistake and why it
  fails. Several were edited or rejected on review:
  * d10's walls were trimmed (an unused pocket) so it no longer shares a room
    with d08;
  * d15 and d17: a croissant that sat on its pad and never moved was removed
    (crates must participate);
  * a third room (terrace) collapsed to 2 trap positions without its idle
    crate and was dropped; a level the greedy agent solved 35% of the time
    (porch) was dropped;
  * three order claims (d06, d26, d28) failed verification, were removed, and
    the text now says "in the shortest solution" where order is not forced.
* One level per room in d13–d30, so rooms don't repeat.

Using a search tool to find candidate placements is common practice in this
genre; the layouts are original to this project and were not copied from any
game.

## 4. Quality gates (all 30 levels pass)

`game/tools/delivery_report.gd` fails a level unless:
* schema, bounds (≤ 255 cells), object counts and symbol/pad counts are
  valid; the start is unsolved and not provably dead; ids and layouts are
  unique (layout compared under all 8 rotations/mirrors and symbol
  relabelling; same-wall rooms are reported);
* the solver's solution replays action by action through `DeliveryRules`
  and ends solved; its push count equals the exact minimum from the complete
  position graph (written to `data/delivery/proofs.json`);
* every crate moves in the shortest solution;
* the documented mistake is legal and ends **proved** unsolvable (except the
  d02 wrong-pad lesson, which is meant to be recoverable);
* every claim verifies (push claims: a search forbidding the push finds no
  solution; position claims: no reachable *solvable* position has the
  property, using exact distances);
* non-tutorial: the greedy agent must not always win, nearest-first delivery
  must fail, and at least two positions on the solution path must contain a
  trap.

Results: 30/30 pass; 27 non-tutorial levels have a verified dependency
(the brief asked for at least 6). Tests re-check the same facts
(`tests/test_delivery_levels.gd`).

**These numbers flag weak levels. They do not measure fun or human
difficulty.** A long minimum is not depth, and solvability is not interest.
Human playtesting is still needed.

## 5. Progression

| Chapter | Puzzles | Focus |
|---|---|---|
| First deliveries | 1–3 | lessons: pushing, symbols, walls and Undo |
| Planning ahead | 4–6 | deep pad first; a delivered crate steps aside; don't seal a passage |
| Order and access | 7–9 | closest comes last; open the pocket first; two steps aside |
| Back-room challenges | 10–12 | full delivery order; three-way shuffle; crossroads |
| Shared lanes | 13–18 | single file; doorway pads; identical crates; knots |
| Tight quarters | 19–24 | stairs; one-way doors; shared roads; overshooting a pad |
| Master courier | 25–30 | timed returns; shuttles; gates; long preparation |

Rewards: 3 tokens for each lesson, 4 for 4–12 and 5 for 13–30 (135 in all,
enough for every café step, 129). Paid once per level.

## 6. The retired sorting mode
Removed from the primary Play flow: Play, the puzzle list, Home tiles and the
first-launch route now lead to Delivery Logic; the bakery, Midnight Ledger
and Daily/Challenges entries are hidden from Home. **Nothing was deleted:**
the source, its levels and tests remain, and players' records (stars, best
scores, cleared levels, ledger, daily history, tokens, restoration) stay in
the save untouched. The Journal chip shows only while something there is
still claimable.

## 7. Known limitations
* No human playtest yet; difficulty ordering is by analysis and review only.
* Arabic strings are drafts awaiting a qualified reviewer (as before).
* The exhaustive in-game check has a 60,000-position budget per position;
  every shipped level's whole space is far smaller (max 1,290), so in
  practice it always concludes, but a timeout would simply claim nothing.
* Not run on Android hardware or an emulator in this environment.
