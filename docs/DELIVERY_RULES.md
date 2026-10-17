# Tiny Street: Delivery Logic — Rule Specification

*Working title for the v8 core game. Authoritative implementation:
`game/src/core/delivery_rules.gd` (`DeliveryRules`). Gameplay, solver, hints,
deadlock detection, tests and the level tools all call that module; no other
file re-implements a rule.*

## 1. Board

A level is a rectangular grid of `W × H` cells (`W·H ≤ 255`). Every cell has
one static type:

| Type | Map char | Courier may enter | Crate may enter | Drawn as |
|---|---|---|---|---|
| Void | ` ` (space) | no | no | nothing (outside the storeroom) |
| Wall | `#` | no | no | brick/shelf wall |
| Floor | `.` | yes | yes | floor tile |
| Destination | `a` `b` `c` `d` | yes | yes | floor tile with a symbol pad |

A destination is a floor cell that also carries a **symbol**. Destinations
never move, never block anything, and stay visible (as a tab at the crate's
corner and a coloured ring) when something stands on them.

## 2. Objects

* **Courier** (`@`): exactly one, on a floor cell.
* **Crates** (`A` `B` `C` `D`): one or more, each with a symbol. Map chars
  `1`–`4` place crate `A`–`D` already standing on its matching destination
  `a`–`d`. At most one object (courier or crate) per cell.

Symbols (shape **and** colour, never colour alone):

| Symbol | Crate / destination | Product art | Colour |
|---|---|---|---|
| `A` / `a` | coffee | cup | roasted brown |
| `B` / `b` | croissant | crescent | golden |
| `C` / `c` | strawberry | berry | red |
| `D` / `d` | tea | tin | teal |

For each symbol, the number of crates equals the number of destinations
(validated for every shipped level). Crates of the same symbol are
interchangeable.

## 3. Actions

### 3.1 Step / push (one direction: up, right, down, left)

Let `t` be the cell next to the courier in that direction.

1. `t` is outside the grid, void or wall → **invalid**.
2. `t` is floor with no crate → the courier moves to `t`. **steps + 1.**
3. `t` holds a crate. Let `u` be the cell beyond it in the same direction.
   * `u` is floor with no crate → the crate moves to `u`, the courier to `t`.
     **pushes + 1.**
   * otherwise (wall, void, outside, or another crate) → **invalid**.

There is no pulling, no pushing two crates at once, and no diagonal movement.
An invalid action changes nothing: courier, crates, counters, history and
redo list are exactly as before. The UI shows a short refusal (shake, sound,
haptic if enabled).

### 3.2 Walk to a cell (tap-to-walk, optional)

Tapping a crate-free floor cell that the courier can reach through crate-free
floor makes the courier walk a shortest such path (ties broken by the fixed
direction order up, right, down, left). Each cell walked is one step. A walk
**never pushes a crate**. An unreachable, occupied or non-floor target is
invalid (no change). A walk is one undo unit.

### 3.3 Undo, redo, restart

* **Undo** reverts the last action (a step, a push, or a whole tap-walk) and
  restores courier, crates, steps and pushes exactly. Unlimited and free.
* **Redo** re-applies undone actions in order; any new action clears the redo
  list.
* **Restart** returns to the level's start state with steps = pushes = 0.
  The restart is itself recorded in the history, so Undo can take an
  accidental restart back. Hints used in the attempt stay recorded (see §6).

Undo, redo and restart never pay currency or score.

## 4. Winning

The level is **solved** as soon as every destination holds a crate of its own
symbol (equivalently, with equal counts: every crate stands on a matching
destination). The check runs after every push. Once solved, further input is
ignored and the result card appears.

* A crate on a **wrong** destination is allowed, can be pushed off again, and
  does **not** satisfy that destination.
* Crates stay on the board after delivery and remain pushable.

## 5. Blocked positions (deadlocks)

A position is **proven unsolvable** only when one of these is established:

| Code | Condition (sound) | Player-facing reason |
|---|---|---|
| `DEAD_CELL` | A crate stands on a cell from which no destination of its symbol can be reached even if every other crate vanished (computed per symbol by reverse "pull" search from that symbol's destinations over the walls only). A corner without a matching destination is the commonest case. | "This *coffee* crate is stuck where it can never reach a *coffee* destination." |
| `FROZEN` | A crate can never move again (blocked on both axes by walls, dead cells, or other crates that are themselves frozen) and is not on a destination of its symbol. | "These crates are jammed together and can't move, and a crate among them isn't on its destination." |
| `EXHAUSTIVE` | The solver explored **every** reachable position from here (within its budget) and none is solved. | "Every possible sequence of pushes from here was checked: the deliveries can no longer all be completed." |

If the solver hits its budget, the result is **UNKNOWN** and nothing is
claimed. "The courier can still walk" is never treated as "still solvable".

When a position is proven unsolvable the game shows a non-modal **Route
blocked** card with the specific reason, highlights the crate(s) involved
where known, and offers **Undo** (primary) and **Restart**. The board stays
visible and playable; no reward is paid and nothing unlocks.

## 6. Hints (opt-in, recomputed from the current position)

1. **Nudge** — an authored, level-specific idea (no positions named).
2. **Strategy** — computed: which crate the solver moves next, and whether it
   must first move *away* from its destination or wait for another crate.
3. **Next push** — one valid push on a shortest-push solution from here
   (arrow on the crate). Never the whole solution.

In a proven-unsolvable position the hint says how many actions to undo to get
back to a solvable one (if found within budget). Any move, undo, redo,
restart or leaving the screen cancels a pending hint. Using a hint only
removes the optional **unassisted** badge for that attempt.

## 7. Results and rewards

* **First clear** of a level pays its completion reward (restoration tokens)
  once, ever (ledger key `dl:clear:<id>`).
* **Personal best** pushes (and steps at that push count) are recorded.
* **Fewest-pushes medal**: awarded only if the attempt's pushes equal the
  level's minimum push count, which is **proved** by exhaustive breadth-first
  search over push positions and re-checked by the test suite.
* **Unassisted badge**: solved in an attempt with no hint.
* Medals and badges are records only; they pay nothing.
* Undo, replay, reopening the result and app restarts cannot pay twice.

## 8. Input mapping (touch first)

* **Swipe** on the board (≥ 40 px, dominant axis) = one step/push.
* **D-pad** buttons under the board = one step/push each.
* **Tap** a floor cell = walk there (§3.2). Tapping a crate does nothing.
* Keyboard arrows / WASD on desktop and web.
* One gesture = at most one action. Input is ignored while the result card is
  coming up. A new input during an animation snaps the animation to its end
  first, so state and picture never diverge.
* The board is never mirrored in Arabic (RTL): up/right/down/left keep their
  spatial meaning; only the surrounding UI mirrors.
