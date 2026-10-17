# Delivery Logic — Three-Minute Smoke Test and QA Access (0.8.0)

Works on the Android APK, an Appetize session (fits the free 3-minute limit)
or the Web build in a desktop browser. Use a **fresh install** (or a private
browser window for the web build).

## Three minutes (player build)
| Time | Do | Expect |
|---|---|---|
| 0:00 | Launch | Two short lines from Mira, then **Puzzle 1 · First Push** with a coach tip. |
| 0:15 | Swipe up into the wall (or press ↑) | The courier bumps, "A wall is in the way." Pushes and Steps stay **0**. |
| 0:20 | Solve: → ↓ → → ↑ → ↓ | After the last push: **Puzzle Solved!** with **3 pushes · 4 steps**, **Completion reward +3**, "Fewest pushes! 3 is the proven minimum", "Solved without hints". Token pill shows 3. |
| 0:40 | Tap **Next Puzzle** | **Puzzle 2 · Matching Pads**. |
| 0:45 | Push the right crate straight up twice (onto the coffee pad) | Coach: "That's the wrong pad, so it doesn't count." Delivered stays **0/2**. |
| 1:00 | Tap **Restart**, then: ← ↑ ↑ ← ↑ → → ↓ ↓ ↓ → ↑ → ↑ ← ← ↓ ← ↑ | Puzzle Solved! (8 pushes), +3. |
| 1:30 | Next → **Puzzle 3**: ↑ ↑ → ↑ (the last one pushes the crate onto the top wall) | **Route blocked** card: "This coffee crate is stuck where it can never reach a coffee pad." The board stays visible. |
| 1:45 | Tap **Undo** on the card | Card disappears, Pushes back to 0. |
| 2:00 | Tap **Hint**, then **More help**, **Show one push**, Close | Idea, then strategy with "Shortest finish from here: 5 pushes", then a gold arrow on the crate. |
| 2:20 | Tap **Restart**, then ↑ ↑ ↑ ↑ → ↓ ↓ ← ↓ → → → | Solved; **no** "without hints" badge (a hint was used in this attempt). |
| 2:40 | Home (pause ‖ → Back to café) | Coins show 9; Play says **Puzzle 4**. Close the app fully and reopen: still 9 coins, Puzzle 4. |

The sequences are the solver's shortest-push solutions, replayed through the
rules by the test suite. Swipes, arrow buttons and arrow keys are equivalent.

## Seeing more puzzles without a phone
* **Web build** (`build/web/index.html`): the same game in a desktop browser.
  It is a single-threaded build, so any static web host or
  `python3 -m http.server` works; no special headers (COOP/COEP) are needed.
  Arrow keys or WASD move; Z undoes; Y redoes. Progress is kept in the
  browser's site storage.
* **QA build** (`build/web-qa/index.html`): identical, plus every puzzle is
  open from the **Puzzles** list ("QA build: every puzzle is open"). It is a
  separate export with the custom feature `qa`; the player APK and the
  player web build don't have it, so progression can't be bypassed there
  (checked by `tests/test_delivery_meta.gd: test_unlock_rules`).
* **Recordings** in `docs/recordings/`: `win_next.mp4`, `deadcell_undo.mp4`,
  `search_proof_restart.mp4` (real play captured with Godot's movie writer).
* **Desktop QA journeys** (developers): `--qa=dl_journey` and friends; see
  `game/src/app/qa_delivery.gd`. Command-line only, so unreachable on a phone.

## If something looks wrong
Note the puzzle number, what you pressed, what you expected and what you
saw. A screenshot of the Route blocked card or result card helps most.
