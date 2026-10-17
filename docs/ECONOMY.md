# Economy (v3, 0.3.0)

There is **one currency: tokens.** No energy, no timers, no real-money tokens. Real purchases stay disabled (`REAL_PURCHASES_ENABLED = false`, no verification server). Every reward is paid through the grant ledger (`data.grants`, a key per reward), saved in the same atomic write as the balance, so it can't be paid twice.

## Sources
| Source | Amount | First time vs replay | Ledger key |
|---|---|---|---|
| Stars, campaign (96 levels) and bakery (8) | 1 token per star (max 3) | First clear pays the stars earned. A replay pays **only newly earned stars**; repeating a 3★ pays 0. | `star:<level>:<n>` |
| Mastery ribbon (per level) | 1 | Once per level, when peak counter ≤ the solver-proven minimum and no hint was used. Optional. | `mastery:<level>` |
| Special orders (p06, p12, m08) | Café extra or unlock (no tokens) | Once | `special:<level>` |
| Café tasks (3 per local day) | 2–3 each | Once per date and task (device clock; documented limitation) | `task:<date>:<id>` |
| Achievements (19) | 2–5 each, 59 total | Once each | `ach:<id>` |
| Challenge cards (12) | 2–5 each, 43 total | Once each; replays pay nothing | `challenge:<id>` |
| Daily puzzle, Café Rush | 0 | Count toward tasks and achievements only | — |

Typical first-clear income: **about 2.3 tokens per level**. This was measured in QA: playing the recorded solutions for the first 42 levels earned 96 tokens. Recorded solutions aren't star-optimal, so careful players earn more.

## Sinks
| Sink | Costs | Total |
|---|---|---|
| Café restoration (8 steps) | 3 / 6 / 10 / 14 / 18 / 22 / 26 / 30 | 129 |
| Café extras (bought) | clock 10, cake stand 12, gramophone 15, cat 18 | 55 |
| Café extras (earned, free) | photo wall (award), chalkboard (p06), bread basket (m08) | 0 |
| Mira's Bakery (4 steps) | 6 / 10 / 14 / 18 | 48 |
| Décor choices and themes | free once the step is owned; switching is free | 0 |

## When things unlock (first clears only, ~2.3 tokens/level, no tasks or awards)
Cumulative tokens count café spending only. Bakery steps (48 in total) are parallel, optional spending: every 16 tokens spent there delays the next café step by about 7 levels.

| Unlock | Cumulative café tokens | ≈ campaign position |
|---|---|---|
| Café 1: Sweep & scrub | 3 | after level 1 (3★ tutorial) |
| Café 2: Paint the walls | 9 | ~4 |
| Café 3: New floor | 19 | ~8 |
| **Bell slice starts** | — | 9 |
| Café 4: Counter (customers start walking in) | 33 | ~14 |
| **Chalkboard** (special order p06) | — | 14 |
| **Mira's Bakery opens** (special order p12) | — | 20 |
| Café 5: Lights | 51 | ~22 |
| Café 6: Seating | 73 | ~32 |
| Café 7: Plants | 99 | ~43 |
| Café 8: Grand opening | 129 | ~56 |
| + bakery complete (+48) | 177 | ~77 |
| + all café extras (+55) | 232 | ~100 (campaign + bakery = 104 levels) |

Tasks, awards, mastery and challenge cards (about 104 + 59 + 43 tokens available) move every row earlier. No stretch between unlocks is longer than about 11 levels, and the slice (#9–#20) contains two café steps, a free extra and the bakery key.

The main progression never needs perfect play. 129 ≤ 96 × 2, so a 2-star average is enough for the whole café (a test enforces this). Mastery, tasks, awards and challenges are optional accelerators.
