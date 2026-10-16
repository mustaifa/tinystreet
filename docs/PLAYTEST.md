# Physical-phone playtest (v2)

Automated checks prove that levels are solvable and that the code behaves as specified. **They don't prove the game is fun, fair, readable or well paced.** v1 had one smoke test on a real phone (it installed and rendered; "feels very basic"). v2 has had **none**.

APK: `build/tinystreet-v2-debug.apk` (checksum in `build/SHA256SUMS.txt`). v1 is kept as `build/tinystreet-debug.apk` for comparison.

## Install
1. Uninstall nothing. Install v2 **over** v1 to test save migration: `adb install -r --no-incremental build/tinystreet-v2-debug.apk`, or open the APK on the phone.
2. Note what v1 showed before updating (levels cleared, tokens, café stage). After the update, nothing should be lost.
3. For a clean first-time run, clear app data (Settings → Apps → Tiny Street → Storage → Clear) *after* the migration check.

## 10–15 minute guided session (owner)
| Min | Do | Watch for / answer |
|---|---|---|
| 0–1 | Launch fresh. Read Mira's welcome. | Does it feel quick? Is "Skip" obvious? Is the text readable? |
| 1–3 | Levels 1–3 (tutorials). Try **press-and-hold**, then a **drag** to the ticket, then a drag away and let go. | Do the destination badges make sense before tapping? Does dragging feel natural or fussy? |
| 3–4 | Win level 1 with 3★ → **Restore the café** → Sweep & scrub. | Is the first reward satisfying? Is the change in the café obvious? |
| 4–7 | Levels 4–6. Watch the **orders bar** and **next customers** row. Try for a **streak** of 3+. | Do the streak words feel good or noisy? Is the next-customer row useful or clutter? |
| 7–9 | **Level 7 (fresh coffee)**. Tap the steaming coffee before any order needs it. | Is the refusal clear (clock badge, message)? Did the mechanic feel like a discovery or a trap? |
| 9–11 | Back to Home → Restore → paint the walls, pick a colour, try **Preview**. Change the colour again. | Do choices feel meaningful? Does Preview make the next step tempting? |
| 11–13 | Journal → Tasks/Awards → claim one. Challenges → start **Café Rush**, finish or quit. | Is the Journal discoverable (badge)? Does Rush feel optional and fun? |
| 13–15 | Settings: music/sound sliders, vibration, reduce motion. Background the app mid-animation and return. Rotate or lock the screen. | Independent volumes? Haptics present and pleasant? Anything stuck after resuming? |

## Specific questions for your next session
1. **Feel**: compared to v1, does tapping now feel responsive and rewarding? Is anything *too* busy (particles, words, sounds)?
2. **Badges**: did you read the badge before tapping? Did the clock ("must wait") and cross badges make sense without explanation?
3. **Drag**: did you use drag at all? Did any drag trigger a move you didn't intend?
4. **Fresh items (level 7 onward)**: interesting choice or annoying blocker? Did you ever get stuck by a fresh item and not understand why?
5. **Paper bags (level 22)**: did hidden items make you think ahead, or feel unfair? Did you want to "peek"?
6. **Locks (level 58)**: reach it if you can. Is the countdown tag readable? Did you plan around it?
7. **Restoration**: did you look forward to the next step? Which step felt best or worst? Is the token pace right (about one step every 4–10 levels)?
8. **Characters**: do Mira, Theo and Basil add warmth, or interrupt? Were the lines too long?
9. **Difficulty**: record retries on levels 7, 10, 22, 25, 34 (old c025), 45 (old c034), 62 (old c048), 77 (old c057), and any level with 3+ restarts.
10. **Readability**: at arm's length, can you tell products, bags and fresh items apart? Try the phone's greyscale mode.
11. **Layout**: any clipped text or buttons (top notch, bottom gesture bar), especially on the game screen with 3 order tickets?
12. **Performance**: any stutter on the confetti or the café screen? Does the phone get warm in 15 minutes?
13. **Arabic** (if you can): RTL order of tickets and the next-customer row; wording that sounds unnatural.
14. **Migration**: after installing over v1, were your cleared levels, stars and café progress intact? Was your token balance at least what it was?

## Observer checklist (for wider tests: 8–12 adults, mixed devices)
| # | Check | Pass criteria |
|---|---|---|
| 1 | Time to first tap | < 15 s including the welcome |
| 2 | Understands "front item only" | No repeated taps on queued items |
| 3 | Reads destination badges | Predicts where an item goes by level 5 |
| 4 | First restoration | Happens within the first 3 minutes |
| 5 | Fresh items | Player explains the rule after level 8 |
| 6 | Paper bags | No "unfair" complaint at b01–b03 |
| 7 | Locks | Player waits for or plans around a lock by k02 |
| 8 | Uses undo after a mistake | Finds undo without help |
| 9 | Loss dialog understood | Can say why they were stuck |
| 10 | Level duration | Most levels take 1–3 min |
| 11 | Restoration motivation | Visits Restore unprompted; reacts to steps |
| 12 | Story | Lines read, not skipped in annoyance (note Skip use) |
| 13 | One-handed play | All gameplay controls reachable with the thumb |
| 14 | Back button | Android back behaves as expected everywhere |
| 15 | Long session | 30+ min: fatigue, battery, heat, frame drops |

Record the device model, Android version, levels reached, time played, stars and tokens, then file findings against level ids (`docs/LEVEL_REPORT.md` lists play order).
