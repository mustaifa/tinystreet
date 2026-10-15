# Human Playtest Kit

Automated checks prove that levels are solvable and that the code behaves as specified. **They don't prove the game is fun, fair, readable or well paced.** Nothing below has been done yet.

## Who and how
- 8–12 adults (mixed: casual puzzle players, café/decoration game fans, 2+ Arabic readers).
- Real phones, including at least one low-end device (≤3 GB RAM, Android 10–12) and one tall 20:9 phone with a camera cutout.
- Use `build/tinystreet-debug.apk`. Watch silently for the first 5 minutes; don't explain the rules.

## Checklist (observer)
| # | Check | Pass criteria |
|---|---|---|
| 1 | Time to first tap | < 10 s, no account or prompts |
| 2 | Understands "front item only" | No repeated taps on queued items |
| 3 | Understands routing priority (L3) | Can predict where an item goes by level 5 |
| 4 | Discovers press-and-hold preview | Note whether it's discovered unaided |
| 5 | Counter warning noticed | Player reacts to the amber "1 space left" |
| 6 | Uses undo after a mistake | Finds undo without help |
| 7 | Loss dialog understood | Can say why they were stuck |
| 8 | Hint usefulness | Hint is followed and helps |
| 9 | Two-stage orders (L31) | "then" row understood without help |
| 10 | Level duration | Most levels take 1–3 min (record times) |
| 11 | Difficulty spikes | Record retries on c025, c034, c048, c057 and any level with 3+ restarts |
| 12 | Restoration motivation | Player visits Restore unprompted; reaction to each milestone |
| 13 | One-handed play | All gameplay controls reachable with the thumb |
| 14 | Readability | Products are distinguishable at arm's length, including in greyscale mode |
| 15 | Arabic | Native reader confirms wording, RTL order, digits and tray-priority explanation |
| 16 | Session length | Long session (30+ min): fatigue, battery, heat, frame drops |
| 17 | Audio | Music/SFX pleasant? Volume balance? |
| 18 | Back button | Android back behaves as expected everywhere |

## Feedback form (player, after the session)
1. In one sentence, what is this game about?
2. Rate 1–5: *fun*, *relaxing*, *too easy ↔ too hard*, *looks good*, *sounds good*.
3. Was there a moment you felt stuck or confused? Where?
4. Did any level feel unfair? Which one, and why?
5. How did you feel about the café restoration? Would you play more to see the next step?
6. Did you understand where each item would go when you tapped?
7. Did you use hints or undo? Were they helpful?
8. Anything that annoyed you?
9. Would you install this from the store? Why or why not?
10. (Arabic readers) Any wording that sounds unnatural or wrong?

Record the device model, Android version, levels reached, time played and stars, then file the findings against level ids.
