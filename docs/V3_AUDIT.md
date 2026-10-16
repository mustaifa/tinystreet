# Tiny Street v3: audit and plan

Written 2026-10-16, before any v3 code.

## Runtime evidence so far
| Build | Evidence |
|---|---|
| v1 0.1.0 (`build/tinystreet-debug.apk`) | Owner smoke test on a real phone: installs and renders; "feels very basic". |
| "Updated Android version" (owner report, 2026-10-16) | **User-reported runtime check: it works on a real phone.** The exact build wasn't stated. The latest available was `build/tinystreet-v2-debug.apk` (0.2.0, SHA-256 `f2177a1f…87f8`, commit `4bef623`), but this isn't confirmed. Feedback: wants deeper gameplay, a livelier world, stronger progression and better presentation. |

Signing: v1 and v2 are signed with the same Godot debug key (cert SHA-256 `62fa12828ad217be61c751322a58f2ce10988c3fccc11b1c704b7259a6281b2e`, `~/.local/share/godot/keystores/debug.keystore`), which is still present. v3 can update in place.

## Feature audit (v2 as committed)
| Feature | Implemented | Playable evidence | Gap or improvement |
|---|---|---|---|
| Customer order queue, next request visible | Yes (v1 queue, v2 next-customers row with faces and first request) | QA shots; 84/84 levels won via input | Routing is always the leftmost ticket. The player can *see* the queue but can't *act* on it. **The main depth gap.** |
| Counter (temporary storage) | Yes, 3–4 slots | All levels | Fine. A separate "serving tray" would duplicate it. |
| Recipe / multi-item orders | Yes (stages hold 1–2 products; two-stage orders from #41) | Validated levels | No longer "special" occasions. |
| Fresh items | Yes (v2) | QA `v2`: refusal + reason; f01–f06 | Good; keep. |
| Paper bags | Yes (v2) | b01–b06, QA shots | Good; keep. |
| Delivery locks | Yes (v2) | k01 solved via taps in QA | Good; keep (this is option D). |
| Hints | Yes: real solver from the current state, "undo N" | QA `rewards` | Must learn any new mechanic. |
| Undo / restart | Yes: full-state snapshots | Tests | Any new state must be in `PuzzleState`. |
| Stars / mastery | ★ clear, ★★ peak counter ≤ solver min + 1, ★★★ + ≤1 undo | Tests | No separate mastery record. Move targets would be meaningless: every solution takes exactly one tap per item. |
| Restoration choices | Yes: 8 steps, 7 categories, extras, preview of next step | QA `cafe` screenshots | Choices apply instantly (no preview/confirm); no coherent themes; the café is static except for steam, cat and confetti. |
| Characters and dialogue | Yes: Mira, Theo, Basil; 17 beats; Journal replay | QA shots, `test_v2_meta` | No beat for the first customer served or for special orders. |
| Objectives and achievements | Yes: 3 daily tasks, 19 awards, ledger | `test_v2_meta`, QA `v2` | Fine; small tweaks only. |
| Optional challenges | Daily (streak) + Café Rush | QA `v2` | No curated challenge collection with goals and one-time rewards. The streak resets, which is mildly punitive. |
| Audio/visual feedback | Yes: badges, drag, particles, streaks, 16 SFX, 87 s music | QA shots | Restoration celebration fine. The café lacks life. |
| Save migration | Yes: schema 3, v1/v2 → v3 tested | `test_v2_meta` | No pre-migration backup file. |
| Android artifacts | v2 debug APK (0.2.0 / code 2) | apksigner OK; owner says "works" | AAB and monetisation APKs are still v1. |
| Second destination | Teaser text only | — | Not playable (correctly). |

## v3 decisions
1. **New mechanic: the Bell (priority ticket).** Tap a ticket to ring its bell: that customer is served first, both from crates and from the counter. It clears when that order is delivered. This turns the visible queue (option A) into a *decision*: which customer to finish first changes who arrives next, when strapped crates open, and whether fresh items can go. It extends the existing rules and solver (a pin action) instead of adding a new inventory system. Levels from p01 on allow it.
2. **Special orders.** Occasional 3-part catering orders in longer levels, with a banner, a story beat, and a one-time café reward.
3. Keep **fresh / bags / locks** (option D already exists as locks). **No serving tray**: it would duplicate the counter.
4. **Mastery ribbon** per level: peak counter at or below the solver-proven minimum, with no hint. Tracked separately from first clear; pays 1 token once.
5. **v3 slice**: 12 curated levels (p01–p12) as a new chapter "Ring the bell" right after the tutorials, so returning players meet it next.
6. **Café alive**: walk-in customers who queue, get served and leave; door, plants and lights move; the cast reacts to milestones. Decor gets preview/confirm and coherent themes.
7. **Challenges**: 12 curated challenge cards with goals and one-time rewards. The Daily switches from a streak to a non-punitive "days played".
8. **Expansion**: only if 1–7 are solid. Mira's Bakery: own art, short restoration arc, a level set where pastries come "hot from the oven", an intro beat, and an unlock tied to the slice.
