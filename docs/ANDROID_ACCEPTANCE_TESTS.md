# Tiny Street — Android Acceptance Tests

<!-- subtitle: Phone test guide for the gameplay-clarity build · version 0.7.0 (versionCode 7) · results NOT RUN until performed -->

These tests are for a person with an Android phone. They check what desktop automation **cannot**: real touch, real screens and safe areas, real audio and vibration, Android Back, interruptions, and installing over a previous build.

You do **not** need to replay every level. Every level's solvability and every rule are already checked automatically (see "Already covered by automation" at the end). The tests here use a few representative levels for each mechanic and mode.

## Build under test

| Field | Value |
|---|---|
| APK | `build/tinystreet-v7-clarity-debug.apk` |
| Package / version | `com.tinystreet.sortrestore`, 0.7.0, versionCode 7 |
| SHA-256 | see `build/SHA256SUMS.txt` (line for `tinystreet-v7-clarity-debug.apk`) |
| Previous build on the phone | v6 `tinystreet-v6-polish-debug.apk` (0.6.0 / 6), v5 `tinystreet-ui-polish-r2-debug.apk` (0.5.0 / 5) or older; all share the same signing certificate |
| Phone model / Android version | *(fill in)* |
| Screen (size, aspect, notch/punch-hole) | *(fill in)* |
| Navigation (gestures or 3 buttons) | *(fill in)* |
| Tester / date | *(fill in)* |

## How to record results

- **Status**: `PASS`, `FAIL`, `BLOCKED` (could not run) or `NOT RUN`. Everything starts as `NOT RUN`.
- **Actual result**: one short sentence, especially for FAIL.
- **Evidence**: a screenshot or screen-recording file name (Power + Volume-down for a screenshot).
- If anything fails, note the screen, what you tapped, and what you expected.

<!-- pagebreak -->

# A. 15-minute smoke test

Run these first, in order, on a phone that already has your v3 or v4 progress.

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| S-01 | v3/v4 installed with progress. Note your token count and highest level first. | Install the new APK **over** the old one (don't uninstall). | Android shows **Update**/**Install**; installation succeeds without "App not installed" or a signature conflict. | | NOT RUN | |
| S-02 | S-01 done | Open the game. | No crash. Home shows the same token count, the same café restoration, and **Continue**/**Play** with the right level. A loading screen briefly shows the cup logo. | | NOT RUN | |
| S-03 | S-02 | Look at Home without tapping for 10 s. | Café shop front with awning; next-step card; Play button pulses gently a few times and stops; nothing flashes. All text readable; nothing cut off at the top (notch) or bottom (gesture bar). | | NOT RUN | |
| S-04 | S-02 | Tap **Play/Continue**, play 3–4 moves. | The level opens with a short fade. Tapping a crate moves its front item to the right ticket or the counter, with a sound and a short vibration (if on). | | NOT RUN | |
| S-05 | In a level | Press and hold a crate, drag away, release elsewhere. Then press and hold, release on the crate. | Hold: item lifts, dashed line to its destination. Drag away: move cancelled. Release on crate: move made. | | NOT RUN | |
| S-06 | In a level | Tap **Undo**, then **Hint**, then **Restart**. | Undo reverses the last move. Hint shows "Thinking…" then lights a crate or ticket. Restart starts over. The Hint badge count goes from 1 to nothing after use. | | NOT RUN | |
| S-07 | In a level | Press Android **Back**. Then **Back** again. | First Back opens **Paused**; second Back closes it and you're still in the level. | | NOT RUN | |
| S-08 | In a level | Finish the level. | Within about a second: **Level complete!**, stars land, the score counts up, one breakdown line, tokens earned, then **Next level** (only primary), **Replay** and **Café**. No story popup covers it. Nothing is cut off and the card doesn't need scrolling. | | NOT RUN | |
| S-09 | Home | Open **Levels**. Tap a padlocked level. | Current level is teal with a play mark; completed levels show stars; locked ones are faint with a padlock. Tapping a locked level shows "Clear level N first to open this one." | | NOT RUN | |
| S-10 | Home | Open **Restore**. Tap **Preview**, then **Hide preview**. If affordable, tap **Restore · N** once. | Preview shows the next step in the café (PREVIEW label); hide returns it. Buying spends tokens once, celebrates, and shows the **Choose the …** picker. | | NOT RUN | |
| S-11 | Bell lesson (level 9) cleared | Open **Challenges** → **Open the ledger** → open **One Bell**. | Night-blue ledger with stamps and page cards. The page shows the strip (**Bells**, **Moves**, **Serve order**). | | NOT RUN | |
| S-12 | Anywhere | Settings → turn **Reduce motion** on, go back to Home, then turn it off again. | With it on: no screen slide, no pulsing; everything still works. | | NOT RUN | |
| S-13 | Anywhere | Swipe home (background) for 10 s, reopen. | Same screen and state as before. | | NOT RUN | |

## A2. v7 gameplay loop (score, result, failure)

Use a **fresh install** for G-01 to G-03 (uninstall first, or use a second phone); the others work on any save.

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| G-01 | Fresh install | Open the game; tap through Mira's welcome. | Level 1 opens directly. Under the title: "Opening up · Goal: serve all 2 orders". The strip reads **Orders 0/2 · Score 0 · Counter 0/3**. | | NOT RUN | |
| G-02 | G-01 | Follow the glowing crate. | Each delivery shows a "+10" pop-up and the Score rolls up; a finished order shows "+25". | | NOT RUN | |
| G-03 | G-02 | Make the last delivery; immediately tap a crate, Undo and Restart several times. | **Level complete!** still appears (taps are ignored once won). Tokens shown (+3 or +4). Then tap **Next level**: Mira's "first customer" line appears **after** the card, then Level 2 opens. | | NOT RUN | |
| G-04 | Level 2 | Fill all 4 counter spaces with items no order wants yet. | The Counter readout says **FULL 4/4** and the status line says only items an order needs can move. The game is **not** over while any crate's badge shows a ticket number. | | NOT RUN | |
| G-05 | Level 4 (Theo's level) | Tap items that no order needs until the counter fills and nothing fits. | **No moves left** with a reason (e.g. "The counter is full (3 of 3)…"). **Retry level** is the big button; **Undo last move** is below. No tokens are paid. | | NOT RUN | |
| G-06 | G-05 | Tap **Retry level**. | The card closes; the level restarts with Score 0, Counter 0/3, and crates respond to taps. | | NOT RUN | |
| G-07 | Any level, mid-way | Note the Score. Tap **Undo** twice, then redo the same two moves. | The Score drops with each undo and returns to exactly the noted value, never higher. **Restart** sets it to 0. | | NOT RUN | |
| G-08 | A cleared level | Replay it and finish with a higher score, then again with a lower one. | First: **New best!** Second: "Best N". Replays with the same stars pay no tokens ("No new stars, so no new tokens"). | | NOT RUN | |
| G-09 | After G-03 | Swipe the app away (close it) and reopen. | Level 1 still cleared with its stars and tokens; Home's Play/Continue points to the right level. | | NOT RUN | |
| G-10 | Settings | Switch the language to Arabic; play one level to the result and one to a loss. | Strip, result and failure cards are in Arabic and right-to-left; numbers stay readable; nothing overlaps. | | NOT RUN | |

<!-- pagebreak -->

# B. Detailed regression checklist

## B1. Install, update and saved data

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B1-01 | Old build with progress | Update over it (S-01). | Same stars per level on the map, same café, same extras, same bakery and ledger progress. | | NOT RUN | |
| B1-02 | Old build with non-default settings (e.g. music 30%, Arabic, larger text) | Update, open Settings. | All settings kept. | | NOT RUN | |
| B1-03 | A level left mid-way in the old build | Update, tap **Continue**. | That level opens at the same position. | | NOT RUN | |
| B1-04 | A ledger page left mid-way in v4 | Update, open that page. | Attempt resumes (same moves). (If the page changed, a message says the attempt was set aside.) | | NOT RUN | |
| B1-05 | Optional, spare phone only | Fresh install (no old build). | Mira's two lines, then Level 1 with tutorial tips. | | NOT RUN | |
| B1-06 | Any | Settings → **Reset progress** → **Cancel**. | Nothing erased. (Do not confirm on your main phone.) | | NOT RUN | |

## B2. First launch and returning player

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B2-01 | Fresh install (spare phone) | Play levels 1–3 following the tips. | Gold ring shows what to tap; tip text sits above the crates, never covering them. | | NOT RUN | |
| B2-02 | Returning player | Close the app from the recent-apps list mid-level; reopen. | **Continue** returns to the same move. | | NOT RUN | |
| B2-03 | Home | Check the next-step card. | Shows "Next: …", a bar, "N / M" or **Ready!**; tapping opens Restore. | | NOT RUN | |

## B3. Every screen and navigation path

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B3-01 | Home | Tap each top chip: Journal, (Shop), How to play, Settings; Back after each. | Each opens; Back returns to Home. | | NOT RUN | |
| B3-02 | Home | Tap each tile: Levels, Restore, Challenges; Back after each. | Each opens with its header; Back returns Home. | | NOT RUN | |
| B3-03 | Bakery/Ledger unlocked | Tap each next-door card on Home. | Opens Mira's Bakery / The Midnight Ledger. | | NOT RUN | |
| B3-04 | In a level | Pause → **Level map**. | Level map opens; Back goes Home; **Continue** resumes the level. | | NOT RUN | |
| B3-05 | In a level | Pause → **Settings**, change a setting, Back. | Returns to the level map path without losing the level (Continue resumes it). | | NOT RUN | |
| B3-06 | Win card | Tap **Café**; then **Replay** on another win; then **Next level**. | Each goes where it says, once. | | NOT RUN | |
| B3-07 | Home | Press Back on Home. | **Leave the café?** with **Stay**/**Leave**. Stay keeps you in the game. | | NOT RUN | |
| B3-08 | Journal | Switch **Tasks**, **Awards**, **Progress**. | Each tab shows; the active tab is teal. | | NOT RUN | |
| B3-09 | Settings | Open **How to play**, **Credits & licences**, **Privacy & support**. | Each opens and scrolls; Back returns to Settings. | | NOT RUN | |

## B4. Representative levels for every mechanic

Use **Levels** to open each one (replay is fine).

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B4-01 | Level 2 | Play it. | Counter use: items with no order wait on the counter; "Counter n / m" updates; amber text when one space is left. | | NOT RUN | |
| B4-02 | Level 7 (fresh) | Tap a fresh (steaming) item that no order needs. | Refused with a shake and "Fresh items can't wait on the counter…"; badge shows a clock. | | NOT RUN | |
| B4-03 | Level 9 (bell) | Ring a ticket, then tap a crate. | Ticket turns gold; the item goes to the rung ticket; ringing again stops it; Undo takes back a ring. | | NOT RUN | |
| B4-04 | A level with paper bags (e.g. level 34) | Bring a bag to the front. | It unwraps with a small pop and its item is revealed. | | NOT RUN | |
| B4-05 | A level with a strapped crate (e.g. level 70) | Tap the strapped crate early; then serve orders. | Refused with "This crate is strapped shut…"; opens with a flash after the tagged number of orders. | | NOT RUN | |
| B4-06 | A two-part order level (e.g. level 53) | Complete part 1 of a two-part order. | Part 2 (under **then**) becomes active; the ticket shows 2/2. | | NOT RUN | |
| B4-07 | A special-order level (level 14 or 20) | Play it through. | Gold-framed SPECIAL ORDER ticket; story beat and one-time reward on the first win only. | | NOT RUN | |
| B4-08 | Get stuck on purpose | Fill the counter until no move works. | **No moves left** card with **Undo (free)** and **Restart** (test builds also show a simulated ad option). | | NOT RUN | |

## B5. Midnight Ledger: bell budgets and order sequences

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B5-01 | Ledger open | Open **One Bell**; tap the book icon. | Rule card lists the rules with icons, including the bell budget. | | NOT RUN | |
| B5-02 | One Bell | Ring once; try to ring a second time. | Strip shows one bell crossed out; second ring refused with "No bell rings left on this page." | | NOT RUN | |
| B5-03 | The Last Shall Be First | Try to serve the last-listed customer first. | Refused with "Not yet: the ledger says … must be served first."; the strip's next face has a gold ring. | | NOT RUN | |
| B5-04 | Any puzzle | Open hint stage 1, then 2, then 3. | Stage chips show **1 Idea**, **2 Bottleneck**, **3 Move**; stage 2 shows live facts; stage 3 highlights one move and says it is verified. | | NOT RUN | |
| B5-05 | Make a wrong move that can't be finished | Open hint stage 3 (or get stuck). | **Stuck** card offers **Undo N move(s) to a solvable point**; using it returns to a solvable position. | | NOT RUN | |
| B5-06 | Any page | Undo, then **Redo**; then make a different move. | Redo re-applies; after a new move Redo is greyed out. | | NOT RUN | |
| B5-07 | The Precise Hand | Finish in 9 moves. | Page solved card: stamp lands; precision badge row earned. | | NOT RUN | |
| B5-08 | A finished page | Tap **Why this works**. | Explanation plus "You found exactly…" or "Your route was different…". | | NOT RUN | |
| B5-09 | Mid-page | Pause → **Back to café**; reopen the page. | Attempt restored (same moves). | | NOT RUN | |

## B6. Hints, undo, redo, restart and resume (campaign)

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B6-01 | Any level | Use the free hint; tap Hint again. | Second tap offers a simulated ad (test build) or explains the free hint is used. | | NOT RUN | |
| B6-02 | Any level | Undo 5 times quickly, then Restart. | Each undo reverses exactly one move; no duplicated or lost items. | | NOT RUN | |
| B6-03 | Any level, mid-way | Force-stop the app (Settings → Apps → Force stop); reopen; Continue. | Same position. | | NOT RUN | |

## B7. Rewards and duplicate-tap prevention

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B7-01 | A task ready in the Journal | Double-tap **Claim** fast. | Tokens increase once; the task shows **Claimed**. | | NOT RUN | |
| B7-02 | Enough tokens for a step | Double-tap **Restore · N** fast. | Tokens spent once; one step restored. | | NOT RUN | |
| B7-03 | Win card | Double-tap **Next level** fast. | Opens the next level once (not two levels ahead). | | NOT RUN | |
| B7-04 | Any screen | Tap a navigation tile twice quickly. | One screen opens; Back returns once to Home. | | NOT RUN | |
| B7-05 | A completed level | Replay it with the same stars. | No new tokens ("No new stars, so no new tokens…"). | | NOT RUN | |

## B8. Restoration previews, purchases and persistence

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B8-01 | Restore, a décor category open | Tap a different option. | Café shows it; coral **Previewing** bar with **Keep** and **Revert**. | | NOT RUN | |
| B8-02 | B8-01 | Tap **Revert**. | Café back exactly as before; nothing saved. | | NOT RUN | |
| B8-03 | B8-01 again | Tap **Keep**; close and reopen the app. | The kept option is still shown. | | NOT RUN | |
| B8-04 | Previewing | Press Android Back. | Preview reverted; you stay on Restore. | | NOT RUN | |
| B8-05 | Enough tokens | **Buy · N** an extra; toggle **Shown**/**Hidden**. | Extra appears/disappears in the café; state kept after restart. | | NOT RUN | |
| B8-06 | Not enough tokens | Look at the step card. | **Restore · N** greyed; "N more token(s) needed…" shown. | | NOT RUN | |

## B9. Background, closing, offline

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B9-01 | Mid-level, during the fly-to-ticket animation | Press Home immediately; reopen. | No stuck item; state consistent. | | NOT RUN | |
| B9-02 | Mid-level | Lock the screen for 1 minute; unlock. | Same state; music resumes if on. | | NOT RUN | |
| B9-03 | Airplane mode on | Play a level, restore a step, open Daily. | Everything works offline. | | NOT RUN | |
| B9-04 | Mid-level | Receive a call or alarm (or open the notification shade). | Game pauses sensibly and resumes without lost moves. | | NOT RUN | |

## B10. Sound, music, haptics and motion

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B10-01 | Settings | Music slider to 0, then 100%. | Music silent, then audible; percentage label updates. | | NOT RUN | |
| B10-02 | Settings | Sound effects to 0; tap buttons and crates. | No effects; music unaffected. | | NOT RUN | |
| B10-03 | Settings | **Vibration** off; make moves. | No vibration. On: short taps. | | NOT RUN | |
| B10-04 | **Reduce motion** on | Open screens, win a level, restore a step. | No slides, pulses, flying items or confetti; results appear in place; nothing missing. | | NOT RUN | |
| B10-05 | **Larger text** on | Visit Home, a level, Restore, Ledger. | Text larger; nothing clipped or overlapping; buttons still fit. | | NOT RUN | |

## B11. Screen size, safe areas, readability and touch

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B11-01 | Phone with notch/punch-hole | Visit every main screen. | No text or button under the camera cut-out or the gesture bar. | | NOT RUN | |
| B11-02 | Any | Tap small targets: chips, level cells, switch, dock tools. | Each responds on the first tap; no accidental neighbouring taps. | | NOT RUN | |
| B11-03 | Any | Read body text at arm's length. | Comfortable without zooming. | | NOT RUN | |
| B11-04 | Any | Check states without relying on colour: switch On/Off word, ticked/padlocked options, crossed bells. | Every state also has a word or shape. | | NOT RUN | |
| B11-05 | Rotate the phone | Try landscape. | Game stays in portrait. | | NOT RUN | |

## B12. Arabic / right-to-left

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| B12-01 | Settings → Language → the Arabic option (right-hand button) | Visit Home, Levels, a level, Restore, Ledger, Settings. | Layout mirrored (back arrow on the right, text right-aligned); Arabic letters joined correctly; numbers readable. | | NOT RUN | |
| B12-02 | Arabic | Play a level. | Crate badges, tickets and dock work the same; Undo arrow points the right way. | | NOT RUN | |
| B12-03 | Arabic | Note awkward or wrong wording. | *Arabic text is a draft awaiting review by a qualified translator; record notes, don't mark the language approved.* | | NOT RUN | |

<!-- pagebreak -->

# C. Optional extended playtesting

These are about feel, not correctness. Write short notes rather than PASS/FAIL.

| ID | Preconditions | Steps | Expected result | Actual result | Status | Evidence |
|---|---|---|---|---|---|---|
| C-01 | Any | Play 20 minutes of campaign in a row. | Notes: does the new look feel inviting? Anything tiring, noisy or distracting? | | NOT RUN | |
| C-02 | Home | Within 5 s of opening Home, say what to do next. | The Play/Continue action and next café step are obvious. | | NOT RUN | |
| C-03 | Ledger | Play two puzzles with the hint stages (see `docs/EXPERT_PLAYTEST.md`). | Answer the six ledger questions there. | | NOT RUN | |
| C-04 | Restore | Decorate a full theme, then revert part of it. | Confirm/cancel/keep/revert never surprised you. | | NOT RUN | |
| C-05 | Bakery | Play the bakery levels and restore a bakery step. | The bakery feels like part of the same street. | | NOT RUN | |
| C-06 | Any | Hand the phone to someone new for 5 minutes, without explaining. | Notes: where did they hesitate or tap the wrong thing? | | NOT RUN | |

# Already covered by automation

So you don't have to replay everything, these ran on the desktop build (Linux, Godot 4.7.2, software rendering) for version 0.7.0. See `TEST_REPORT.md` for exact numbers.

- 148 unit and rule tests (rules, solver, score and undo/redo/restart, saves and the schema 4 → 5 migration, rewards, ledger constraints, scripts compile).
- Level validator: every shipped level (campaign, bakery, daily pool) replayed and solver-verified.
- All 96 campaign levels won through simulated taps on the real UI.
- **New-player journey through real taps only**: first win → result → next level, a genuine loss on level 4 → Retry, undo/restart score checks, stray taps around the result, replay, close/reopen, and the last level → finale. Run in English, Arabic, and at 720×1080 with large text and reduced motion.
- Scripted UI flows: mechanics, restore, bakery, ledger, navigation and Back, rewards, rapid tapping, layouts, and English/Arabic screenshots of every screen.

Not covered by automation (and why these phone tests exist): real touch accuracy, real fonts and display density, safe areas reported by real hardware, audio/vibration output, Android Back hardware/gestures, interruptions, and installing over an earlier build.
