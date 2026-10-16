# Physical-phone playtest (v3)

Automated checks prove that levels are solvable and that the code behaves as specified. **They don't prove the game is fun.** v3 (0.3.0) has had **no** Android run yet.

## Install as an update (keeps your progress)
1. **Don't uninstall** the current version. Uninstalling deletes the save.
2. Note where you are now: the level Play shows, tokens, café step, any bakery or story you've seen.
3. Install `build/tinystreet-v3-debug.apk` over it: open the APK on the phone, or run `adb install -r --no-incremental build/tinystreet-v3-debug.apk`. It has the same package (`com.tinystreet.sortrestore`) and the same debug signing key as v1/v2, and a higher versionCode (3), so Android treats it as an update.
4. On first launch the save migrates to schema 4. An untouched copy of your old save is kept on the device as `save.json.schema3.bak`.
5. If Android refuses the install ("package conflicts" or a signature error), stop and report it. Don't uninstall unless you accept losing progress.

## 15-minute session
| Min | Do | Watch for |
|---|---|---|
| 0–1 | Launch. Check your progress, tokens and café survived. Press Play. | Returning players land on **level 9, "Ring the bell"** (the new chapter). |
| 1–3 | Level 9 (bell lesson). Follow the coach; ring ticket 2's bell when it glows. Then undo the ring and try without it. | Is the bell's effect obvious (gold ticket, badges change)? Did undo bring it back? |
| 3–6 | Levels 10–13. Ring bells when two tickets want the same thing. Try the hint once when stuck. | Do you feel you're *choosing*? Does the hint ever say "ring"? |
| 6–8 | Level 14: Theo's **special order** (3 rounds, gold frame). | Memorable? Did the chalkboard appear in the café afterwards? |
| 8–10 | Home: watch the café for 30 s (customers walk in through the side door). Restore → try a **theme**, Revert, then Keep one. Preview an extra. | Does the café feel alive? Is preview/keep/revert clear? |
| 10–12 | Challenges → play one challenge card. | Are the goal and reward clear? Does it say "Goal met"? |
| 12–14 | If you reach level 20 (Mira's tasting day), the bakery opens. Visit it, buy a step, and play Bakery 1 (the oven). | Is the bakery distinct? Is the oven countdown readable? |
| 14–15 | Background the app during an animation, return; change music and effects volume; toggle reduce motion. | Anything stuck? Volumes independent? Customers stop walking with reduce motion? |

## Please answer
1. Which interaction felt most satisfying?
2. Where did you become confused or bored?
3. Did you have a meaningful choice in the puzzles?
4. Did the café upgrades feel worth earning?
5. Did you want to continue to the next level?
6. Did your previous progress survive the update?

Also useful: device model and Android version, levels reached, any level you restarted 3+ times, and anything clipped by the notch or gesture bar.

## Observer checklist (wider tests)
| # | Check | Pass criteria |
|---|---|---|
| 1 | Bell understood | Player explains the bell after level 10 |
| 2 | Bell used deliberately | Rings before tapping in a conflict by level 12 |
| 3 | Special order | Player notices the gold frame and 3 rounds |
| 4 | Café life | Player notices walking customers without prompting |
| 5 | Preview | Player uses Revert at least once without help |
| 6 | Bakery | Reached and recognised as a new place |
| 7 | Undo/hint | Recovers from a stuck position without restarting |
| 8 | Session | 15 min without fatigue; wants to continue |
