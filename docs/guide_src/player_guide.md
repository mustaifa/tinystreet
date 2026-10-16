# Tiny Street: Sort & Restore — Player Guide

<!-- subtitle: The complete guide to every mode, screen and rule · game version <!-- version --> · spoiler-free -->
<!-- cover: screenshots/v5/home_done.jpg, screenshots/v5/game_mid.jpg, screenshots/v5/ledger_play.jpg -->

This guide describes **Tiny Street: Sort & Restore, version <!-- version -->** (the "UI polish" build). Every screenshot was captured from this version of the game. The wording in **bold** matches the buttons and labels you see on screen.

The main guide is **spoiler-free**: it explains rules and screens, never the answer to a particular puzzle. Complete, verified walkthroughs are kept in a separate file, `TINY_STREET_SOLUTIONS_APPENDIX.md`. Appendix A at the end lists every level and page in the game, generated from the game's own data.

<!-- pagebreak -->

# 1. Install, update and start

## Installing or updating on Android

The game is delivered as an Android app file (APK) while it is being tested.

1. Copy the APK to your phone (or download it there).
2. Open it from your file manager. If Android asks, allow your file manager to install unknown apps.
3. Tap **Install** (or **Update** if an earlier Tiny Street build is already installed).

> **Important: update, don't uninstall.** Installing a new build over an older one keeps your progress, stars, tokens, café and settings, because every build uses the same app ID and signing key. Uninstalling first deletes your saved progress.

The game works completely **offline**. It asks only for permission to vibrate. There is no account and no login.

## First launch

On your very first launch, Mira (the café owner) says two short lines, and the game takes you straight into **Level 1**, a guided tutorial. Gold rings and short tips show you what to tap. You can skip a story bubble with **Skip** or tap to continue.

## Coming back

Your progress is saved automatically after every move. When you return:

- **Continue** on the Home screen reopens the level you left, exactly where you were.
- If no level is in progress, the same button says **Play** and opens your next new level.
- Expert ledger pages and bakery levels also remember an attempt in progress when you leave them.

<!-- pagebreak -->

# 2. The Home screen

![Home, a new café](screenshots/v5/home_new.jpg)
![Home, partway through](screenshots/v5/home_mid.jpg)
![Home, café restored](screenshots/v5/home_done.jpg)

Home is your café on Tiny Street. The café picture changes with every restoration step you complete, from boarded-up windows to a busy, lit café with neighbours at the tables.

| Element | What it does |
|---|---|
| Token pill (gold coin + number), top left | Your **tokens**, the café's only currency. Earned by playing; spent on restoration. |
| **Journal** chip (open book) | Daily café tasks, awards and your progress. A coral number shows how many rewards are ready to claim. |
| **Shop** chip (+) | Appears only in test builds. It is a clearly labelled *test store* that never charges. Everything in the game is free. |
| **How to play** chip (?) | The rules, with the game's own icons. |
| **Settings** chip (gear) | Sound, comfort options, language and more. |
| The café | Your restoration progress. Neighbours visit once the counter is restored. |
| Next-step card ("Next: …") | The next restoration step, with a bar showing your tokens against its cost. Shows **Ready!** when you can afford it. Tap it to go to **Restore**. |
| Next-door cards | **Mira's Bakery** and **The Midnight Ledger** appear here once you unlock them, with their progress. A coral dot marks something new or ready. |
| **Play** / **Continue** | The main action: your next level, or the one in progress. It shows the level number and chapter. |
| **Levels** tile | The level map. |
| **Restore** tile | Café restoration and decoration. A coral dot means you can afford the next step. |
| **Challenges** tile | The Daily puzzle, challenge cards, Café Rush and the Midnight Ledger. A coral dot means today's Daily is not yet played. |

## Tokens, stars and badges

| Reward | How you earn it | Used for |
|---|---|---|
| Stars (1–3 per level) | Finishing a level (see *Stars* in section 3). | Each new star earns 1 token (once per star). Your total is on the level map. |
| Tokens | 1 per new star, +1 for a new mastery ribbon, café tasks, awards, challenge cards. | Restoring and decorating the café and the bakery. |
| Mastery ribbon (teal rosette) | Finishing a level with the tidiest possible counter and no hint. | Pride, and 1 token the first time. |
| Ledger stamp and badges | Midnight Ledger pages (section 9). | A collection; they pay no tokens. |

The Daily puzzle, Café Rush and the Midnight Ledger never pay tokens, so you never need them to progress.

<!-- pagebreak -->

# 3. How to play

## The goal

Fill every customer's order using the products in the crates. There is no timer and no move limit in the campaign. Take as long as you like.

![A level in progress](screenshots/v5/game_mid.jpg)
![Pressing and holding a crate](screenshots/v5/game_hold.jpg)

## The puzzle screen, top to bottom

| Part | What it shows |
|---|---|
| **Pause** chip (‖) | Pauses: **Resume**, **Restart**, **Settings**, and **Level map** (campaign) or **Back to café** (other modes). The star rules for the level are listed here too. |
| Title and chapter | The level number and its chapter, e.g. "Level 53 · Two-part orders". |
| **How to play** chip (?) | Opens the rules. (In expert mode this is the **Rules** card, a book icon.) |
| **Orders 1/6** bar | Orders served so far. Each segment is one order; ticked segments are done. |
| **Next:** queue | The next customers waiting and the first thing each will ask for. |
| Order tickets | Up to three customers at once. Each ticket has a **number** (1, 2, 3), the customer's face, the items they want, and one circle per item (filled with a tick when it arrives). A second part, if any, is shown under **then**. |
| **Counter 0 / 3** | The holding counter and its free spaces. |
| Status line | Short messages: why a tap was refused, a hint, or "Counter full — send items straight to orders". |
| Crates | Each crate shows its whole stack. Only the big **front item** at the bottom can be taken. |
| Dock: **Undo**, **Hint**, **Restart** | Tools. Undo and Restart are always free. The coral number on Hint is your free hints left. |

## Tapping a crate

Tap a crate to send its front item where it belongs. Before you tap, the small round **badge** on the front item tells you where it will go:

| Badge | Meaning |
|---|---|
| A **number** (1, 2 or 3) | It goes straight into that order ticket. |
| Three little blocks | It goes to the **counter** to wait. |
| A **clock** | A fresh (hot) item that has nowhere to go yet; it must wait in its crate. |
| A **cross** | Nowhere to go right now. Tapping does nothing. |

**Press and hold** a crate to preview: the item lifts, a dashed line points to its destination, and that ticket or counter space lights up. Let go over the crate (or drag to the destination) to make the move; drag away and let go elsewhere to cancel.

## Where items go

1. An item goes to the **leftmost** order (lowest ticket number) that still needs it.
2. If no order needs it, it waits on the **counter**, if there is space.
3. When an order needs something that is waiting on the counter, it **moves over by itself**.
4. A finished order leaves with a tick, and the next customer in the queue steps up.

Consecutive moves that go straight into orders build a little streak ("Nice!"). Streaks are just for fun; they never change stars.

## Getting stuck

If no front item can go to an order or the counter, you are stuck and the **No moves left** card appears. **Undo (free)** takes back your last move; **Restart** starts again. A full counter is fine as long as some item can still go straight to an order.

> In test builds you may also see **Extra counter space (watch ad)** or **Watch a short ad for a hint**. These use a simulated ad that never contacts an ad network.

## Stars

Every level shows its star rules in the **Pause** card:

- 1 star: complete the level.
- 2 stars: keep your peak counter use at the level's target or less.
- 3 stars: also use at most 1 undo and no extra counter space.

Hints never affect stars. The win card shows your moves, peak counter use and undos, and tells you how to earn more stars.

## Hints, Undo and Restart

- **Hint**: one free hint per attempt. The game works it out from your *current* position and lights up the crate to tap (or the ticket bell to ring). If your position can no longer be finished, it tells you how many moves to undo. Restarting gives you a fresh free hint.
- **Undo**: free and unlimited. It restores everything, including automatic deliveries and the bell.
- **Restart**: free. Starts a new attempt of the same level.

![Pause card with star rules](screenshots/v5/pause.jpg)
![No moves left](screenshots/v5/lost.jpg)
![Level complete](screenshots/v5/win.jpg)

## Finishing a level

The win card lands your stars one by one, then shows three stats (**moves**, **peak counter**, **undos**), any tokens and ribbon you earned, one tip, and your next café step. **Next level** is the main action; **Restore the café** appears when you can afford the next step; **Replay** and **Café** sit side by side underneath.

<!-- pagebreak -->

# 4. Mechanics

The campaign introduces one new idea at a time. Each first appearance has a short tutorial tip, and its level carries a gold **NEW** tag on the level map until you clear it.

## The bell

![The bell lesson](screenshots/v5/game_p01.jpg)

Every order ticket has a small **bell**. Tap a ticket to ring its bell: that customer is now **served first**, from the crates and from the counter, even if another ticket is further left. The ticket turns gold and its bell is filled in.

- Tap the same ticket again to stop the bell, or ring another ticket to move it.
- The bell stops by itself when that order is served.
- Ringing is not a move in the campaign, and **Undo** takes it back.
- The crate badges update the moment you ring, so you can see the effect before tapping a crate.

The bell is introduced in the chapter **Ring the bell** (level 9). The eight levels of *Opening up* before it don't have a bell.

## Fresh (hot) items

![Fresh items](screenshots/v5/game_f01.jpg)

Items with **steam** and a dashed coral ring are fresh. They must go straight into an order and can never wait on the counter. If no order needs one yet, it stays in its crate (its badge shows a clock) and blocks the items behind it.

## Paper bags

![Paper bags](screenshots/v5/game_b01.jpg)

A **paper bag** with a "?" hides its item until it reaches the front of the crate. The rules always know what is inside; you find out when it is unwrapped.

## Strapped crates

![A strapped crate](screenshots/v5/game_k01.jpg)

A crate with **straps** and a padlock tag stays shut until the number of orders on its tag has been served. You can see what is inside, but you can't take anything until it opens.

## Two-part orders and special orders

![Two-part orders](screenshots/v5/game_x05.jpg)

Some customers order in **two parts**. The second part is shown under **then** and begins as soon as the first part is complete; the ticket shows "1/2" or "2/2". A few longer levels include a **SPECIAL ORDER**: a three-part order from one of the regulars, with a gold frame and a one-time reward (for example a chalkboard menu for the café, or opening Mira's Bakery).

## Ovens (Mira's Bakery)

In the bakery, some crates are **ovens**: they open after the number of orders on their tag, and the hot pastries inside must go straight to a ticket.

<!-- pagebreak -->

# 5. The level map and progression

![The level map](screenshots/v5/levels_mid.jpg)

The campaign has **96 levels in 7 chapters**: *Opening up*, *Ring the bell*, *Morning rush*, *Busy counter*, *Two-part orders*, *Delivery day* and *Head barista*. Levels open one after another: clear a level to open the next.

Open the map with **Levels** on Home. The star pill at the top shows your total stars.

| On the map | Meaning |
|---|---|
| Chapter card | Chapter number, name, "N of M cleared", stars earned, and a progress bar. Tap the chapter header to show or hide its levels. |
| Teal level with a play mark | The **current** level: the next one to play. It gently pulses a few times when the map opens. |
| Paper level with three stars | A **completed** level; gold stars are earned, outlines are not. |
| Teal rosette in the corner | **Mastery** earned on that level. |
| Gold **NEW** tag | The level introduces a new mechanic. |
| Small gold bell | The bell lesson or a level with a special order. |
| Faint level with a padlock | **Locked**. Tap it to see which level to clear first. |
| Locked chapter | Shows "Opens after level N". |

Finished chapters fold to one line to keep the map short; the chapter you are playing is open. The **Play level N** button at the bottom always takes you to your next level. You can replay any completed level to improve its stars; extra stars still earn tokens (once each).

## Mastery

The win card tells you the mastery target, for example "Mastery: finish with the counter never above 1 and no hint." Mastery is optional; nothing requires it.

<!-- pagebreak -->

# 6. Restoring and decorating the café

![Restore](screenshots/v5/restore.jpg)
![Choosing a look](screenshots/v5/restore_choice.jpg)

Open **Restore** from Home (or tap the next-step card). Your token total is in the top-right pill.

## Restoration steps

The café has **8 steps**, bought in order: *Sweep & scrub*, *Paint the walls*, *Lay a new floor*, *Counter & espresso machine*, *Hang the lights*, *Tables & chairs*, *Plants & window box*, and *New sign & grand opening*. The step card shows "Step N of 8", a row of dots (done steps teal, the next one ringed), what the step does, and a bar of your tokens against the cost.

- **Restore · N** (with a coin) spends N tokens and completes the step. The café celebrates. If you can't afford it yet, the button is greyed and the card says how many more tokens you need.
- **Preview** shows the café *with* the next step done, without spending anything. **Hide preview** turns it off. A "PREVIEW" label appears on the café while you are previewing.

## Choosing a look

Most steps unlock a decoration choice (wall colour, floor, counter, lights, seating, plants, sign). Right after buying a step, the **Choose the …** card appears with the options under it.

- Tap an option to see it in the café. Nothing is saved yet: a coral bar appears saying **Previewing** "Not saved until you keep it".
- **Keep** saves your choice. **Revert** puts the café back exactly as it was. The Android Back button also reverts a preview.
- Each option shows a colour swatch where it has one. A tick marks the option shown now; a padlock marks options you can't use yet, with the reason (for example an award to earn, or the test store).

Switching between options you own is always free, and you can change them any time later in **Decor (change any time)**.

**Themes (preview, then keep)** apply a coordinated look (Classic, Garden, Parisian, Harbour) over every step you have restored. They preview first, like single options.

## Extras

**Extras** are optional café details: *Wall clock*, *Cake stand*, *Gramophone*, *Pip the café cat*, *Photo wall*, *Chalkboard menu*, *Bread basket* and the *Midnight Lantern*. Each has **Preview** and, when it can be bought, **Buy · N**. Some extras are rewards instead: from an award, a special order, the bakery, or (the Midnight Lantern) from stamping every Midnight Ledger page. Owned extras show **Owned** and a **Shown** / **Hidden** switch.

<!-- pagebreak -->

# 7. Challenges, the Daily puzzle and Café Rush

![Challenges](screenshots/v5/challenges.jpg)
![Challenge cards](screenshots/v5/challenges_cards.jpg)

Open **Challenges** from Home.

## Daily

A new puzzle every day at midnight on your phone's clock. Everyone on the same app version gets the same puzzle on the same date. The card shows the date, how many **Days played** (it never resets), and either **Play today's puzzle** or, once done, your stars and moves with **Share result** (copies a short result, with no personal data, to paste anywhere) and **Play again (for fun)**. The Daily awards no tokens.

## The Midnight Ledger card

Shows your stamps and **Open the ledger**. Before it opens it says which level unlocks it.

## Challenge cards

Twelve cards, each a puzzle from the Daily pool with **one goal**: finish, finish with 3 stars, finish without a hint, finish without undo, or keep the counter at or below a number. Each card shows its goal with an icon and its reward ("+3"). Meeting the goal pays the reward once and marks the card **Done**; you can replay any card at any time. The cards open after the bell lesson.

## Café Rush

Three puzzles back to back. The clock only counts up and there is no way to fail; it's just your personal best. **Start the Rush** begins a run with three random puzzles from the Daily pool.

<!-- pagebreak -->

# 8. Mira's Bakery

![Mira's Bakery](screenshots/v5/bakery.jpg)
![A bakery level](screenshots/v5/bakery_game.jpg)

Serving Mira's special order (in the *Ring the bell* chapter) opens **Mira's Bakery** next door. It appears as a card on Home.

- **Bake level N** plays the next bakery level. Bakery levels use the campaign rules plus **ovens**, and they earn stars and tokens like campaign levels.
- The bakery has its own **4 restoration steps** (*Light the ovens*, *Bread shelves*, *Striped awning*, *Bakery sign & opening*) with **Restore · N**, and decoration choices for **Shelves**, **Awning** and **Sign emblem** (switch freely between what you own).
- The 8 bakery levels are listed at the bottom with the same states as the level map.

<!-- pagebreak -->

# 9. The Midnight Ledger (expert mode)

![The ledger](screenshots/v5/ledger_list.jpg)
![A ledger page](screenshots/v5/ledger_play.jpg)
![The rule card](screenshots/v5/ledger_rules.jpg)

After closing time, the café owner finds a ledger of unusually difficult orders. The Midnight Ledger is an **optional** collection of 13 expert puzzles: small boards, every order visible, explicit rules and no timers. It opens after the bell lesson. It pays **no tokens**, and nothing else in the game depends on it.

The difficulty labels for these pages are provisional: they are the designer's estimates until people have played them.

## Lessons, puzzles and the final page

| Group | Pages | Opens |
|---|---|---|
| **Lessons** | 3 | One after another. |
| **Puzzles** | 9 | All at once, after the three lessons. |
| **The final page** | 1 | After any six puzzles. |

Each page card shows its number, name, the idea it explores, and, once finished, **Stamped** plus any badges. Locked pages say what opens them.

## The two expert rules

Ledger pages use every café rule, plus one or both of these:

- **Bell budget**: you may ring bells at most N times on this page. Every ring counts, including ringing again to stop a bell. When the budget is used up the bells are crossed out, and tapping a ticket says "No bell rings left on this page."
- **Order sequence**: some customers must be served in a set order. Any tap whose result would serve one of them too early (including the automatic deliveries it would trigger) is refused with "Not yet: the ledger says … must be served first." Other customers can be served at any time.

## The ledger strip

Under the order bar, a midnight-blue strip shows:

| Section | Meaning |
|---|---|
| **Bells** | One bell per ring allowed; used rings are crossed out. "∞" means unlimited. |
| **Moves** | Your move count. Where a precision badge is offered, the target is shown as "/ 9". |
| **Serve order** | The sequence as faces, in order. Served customers get a tick; the next one has a gold ring. "any order" means this page has no sequence. |

A **move** is one crate tap or one bell ring in your final sequence. Undone moves don't count.

The **Rules** chip (book icon) opens the page's rule card at any time.

## Hints in three stages

![Hint stage 2](screenshots/v5/ledger_hint2.jpg)

Tap **Hint** for help in stages: **1 Idea** (a nudge about the key idea), **2 Bottleneck** (a more specific explanation plus live facts: bells left, who is next in the sequence, free counter spaces), and **3 Move** (one verified next move, highlighted on the board). A move is only shown when it is proven to lead to a solution. It never guesses, and it never shows the whole answer. Opening any stage means no no-hint badge for that finish, but you can always finish the page.

## Undo, Redo, Restart and recovery

The ledger dock adds **Redo** (re-applies an undone move; any new move clears it). If you reach a position that can no longer be finished, the **Stuck** card offers **Undo N move(s) to a solvable point** (back to the last position on a proven solution), **Undo (free)** and **Restart**. If the quick search can't decide, it says so honestly instead of guessing.

## Stamps, badges and the Midnight Lantern

![Page solved](screenshots/v5/ledger_won.jpg)
![Why this works](screenshots/v5/ledger_why.jpg)

- **Stamp**: for finishing a page the first time.
- **No-hint badge**: for finishing without opening any hint stage.
- **Precision badge**: on the two pages that offer one, for finishing in the proven minimum number of moves.
- **Midnight Lantern**: a café extra for stamping every page.

Each reward is given once; replays never change them. After finishing, **Why this works** explains the page's idea and tells you honestly whether your route matched the ledger's reference solution or was a different valid one.

Leaving a page keeps your attempt (moves, redo and hints used). If a page is updated in a later version, an old saved attempt is set aside with a message rather than loaded against different rules.

<!-- pagebreak -->

# 10. Journal, settings and saving

## Journal

![Journal tasks](screenshots/v5/journal_tasks.jpg)
![Awards](screenshots/v5/journal_awards.jpg)
![Progress](screenshots/v5/journal_progress.jpg)

Open the **Journal** chip on Home. Three tabs:

- **Tasks**: three small café tasks a day (any puzzle counts). Each shows progress and its reward; **Claim** pays it once. Tasks change at midnight on your phone's clock.
- **Awards**: the achievement collection, with progress bars for locked ones and **Claim** for earned ones.
- **Progress**: chapter-by-chapter progress and stars, café steps, extras, awards, Daily days, challenge cards, ledger stamps, your best Rush time, and **story replays** of scenes you have already seen.

## Settings

![Settings](screenshots/v5/settings.jpg)

| Setting | Effect |
|---|---|
| **Music**, **Sound effects** | Volume sliders (0–100%). |
| **Vibration** | Short taps of vibration on moves and rewards. |
| **Reduce motion** | Removes movement: no screen slides, pulses, flying items or confetti; things appear in place instead. |
| **Larger text** | Makes every text about 15% larger. |
| **Language** | English or Arabic (right-to-left layout). The Arabic text is a draft awaiting review by a qualified translator. |
| **More** | **How to play**, **Credits & licences**, **Privacy & support**. |
| **Reset progress** | Erases levels, stars, tokens and café restoration on this device after a confirmation. Settings and purchases are kept. |

## Saving and resuming

- The game saves after every move and every reward, and again when you leave or switch apps.
- Closing the app, a phone call or the screen turning off never loses more than the move you were making.
- Rewards are recorded so they can be paid only once: replaying, reloading or double-tapping never duplicates tokens.
- If the save file is ever damaged, the game restores a backup copy and tells you.

## The Android Back button

| Where | Back does |
|---|---|
| A card or dialog | Closes it (the level-complete card waits for a choice). |
| A story scene | Skips it. |
| Playing a level | Opens **Pause**. |
| Previewing in Restore | **Revert**s the preview. |
| Any other screen | Goes back one screen. |
| Home | Asks **Leave the café?** with **Stay** and **Leave**. |

<!-- pagebreak -->

# 11. Common mistakes and troubleshooting

| Problem | What's happening and what to do |
|---|---|
| "Tapping a crate does nothing." | Check the badge on its front item. A cross means it has nowhere to go; a clock means it is fresh and must wait; a strapped crate opens later. The status line explains every refusal. |
| "The item went to the wrong order." | Items always go to the **leftmost** order that needs them. Ring the bell on the ticket you want served first. Press and hold to preview before you let go. |
| "My counter keeps filling up." | Send items straight to orders where you can, and leave space for items you'll need soon. The counter caption turns amber when one space is left. |
| "I'm stuck." | **Undo** is free and unlimited. **Hint** tells you how many moves to undo if your position can't be finished. |
| "Not yet: the ledger says … must be served first." | An expert-page sequence. Serve the customer named first, or ring a bell to redirect the cascade (if bells are left). |
| "I can't ring the bell." | The bell isn't available in the first tutorial levels, and expert pages may have a bell budget that is used up. |
| "I can't afford the next restoration step." | Earn tokens: new stars (replay levels for more), mastery, café tasks, awards and challenge cards. |
| "I picked a colour by mistake." | Choices only preview until you tap **Keep**. Owned options can be switched any time for free. |
| "My ledger attempt disappeared." | The page was updated in a new version, so the old attempt was set aside. Start the page again. |
| "The Daily changed." | It follows your phone's date. Changing the clock changes the puzzle. |
| "Things move too much." / "Text is too small." | Turn on **Reduce motion** or **Larger text** in Settings. |
| "I lost my progress after reinstalling." | Uninstalling deletes local progress. Always install new builds *over* the old one. |

<!-- version-footer -->
This guide describes version <!-- version -->. Generated level data: Appendix A. Spoilers: the separate Solutions Appendix.

<!-- appendix -->
