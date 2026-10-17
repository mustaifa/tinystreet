# Tiny Street design system (v5, 0.5.0)

**Direction: "an inviting miniature café street."** Warm cream ground, rich espresso text, teal for primary actions, restrained coral and gold accents, tactile keys with a soft shadow, and a café shop front as the centrepiece. Expert mode (the Midnight Ledger) has its own night palette: midnight blue with warm lantern gold.

Everything lives in code, so there is one source of truth:

| Layer | File |
|---|---|
| Tokens (colour, type, spacing, radii, motion) and the shared `Theme` | `game/src/ui/style.gd` |
| Components (buttons, chips, pills, tags, progress, rows, headers, switch, segmented control, badges) | `game/src/ui/ui.gd` |
| Icon set (vector, one stroke style) | `game/src/ui/glyph.gd` |
| Dialogs (light and night) | `game/src/ui/dialog.gd` |
| Screen backgrounds (café / night / bakery) | `game/src/ui/screen_backdrop.gd` |
| Shop front frame around the café and bakery | `game/src/ui/storefront.gd` |
| Level key (campaign map and bakery) | `game/src/ui/level_cell.gd` |
| Board setting behind puzzles (café / night / bakery) | `game/src/board/backdrop.gd` |

Screens choose a theme **variation** by name (`"WarmButton"`, `"NightCard"`, …) and never build their own colours. A screen can set `var screen_mode := "night"` (or `"bakery"`) to switch the full-bleed background.


> **v6:** colour tokens are now `static var`s that an art skin can override, and products, board furniture, characters, icons, backgrounds and sounds can all come from a skin. See `docs/ART_PIPELINE.md`.

## Colour tokens

| Token | Hex | Use |
|---|---|---|
| `CREAM` | `#fbf4e8` | Screen background |
| `CREAM_DEEP` | `#f2e5d0` | Empty tracks, recessed areas |
| `LINEN` | `#f7eddc` | Soft panels, stat chips |
| `PAPER` | `#fffaf3` | Cards, dialogs, secondary keys |
| `PAPER_EDGE` | `#eadcc6` | Hairline borders on paper |
| `INK` | `#3a2a22` | Primary text (12.6:1 on cream) |
| `INK_SOFT` | `#6b584c` | Secondary text (6.1:1 on cream) |
| `INK_FAINT` | `#9c8a7c` | Decorative only (locked numbers), never body text |
| `TEAL` / `TEAL_DARK` / `TEAL_EDGE` | `#1f7a72` / `#165a54` / `#0f4540` | Primary actions, "done", current level |
| `TEAL_SOFT` | `#d3ebe6` | Done/owned backgrounds |
| `TERRACOTTA` (coral) / `CORAL_EDGE` | `#c95f3f` / `#94412a` | Restoration and warm calls to action, notification dots |
| `TERRA_SOFT` | `#f6dccf` | Preview bar, "ready" highlights |
| `GOLD` / `GOLD_EDGE` / `GOLD_SOFT` | `#e3a83a` / `#a8761b` / `#f8e8c4` | Stars, tokens, claim, hints |
| `WARN` | `#cf7a22` | Counter almost full |
| `DANGER` | `#b8442c` | Destructive (Reset progress) |
| `NIGHT` / `NIGHT_2` / `NIGHT_3` / `NIGHT_LINE` | `#161e36` / `#1f2a49` / `#2b3860` / `#3e4c7a` | Ledger grounds, cards, keys, borders |
| `MOON` / `MOON_SOFT` | `#f3efe4` / `#bcc3dc` | Text on night (13:1 and 7.4:1) |
| `LANTERN` / `LANTERN_EDGE` | `#f2b84b` / `#b07c1e` | Ledger primary keys, highlights, stamps |
| `PARCHMENT` | `#f6eedb` | Ledger page cards |
| `ROSE` / `ROSE_SOFT` | `#e7a3a8` / `#f8e1df` | Bakery accents |

**Semantic states** never rely on colour alone: every state also has a shape or word (tick, padlock, crossed bell, "On"/"Off" inside switches, "Done"/"Owned"/"Ready!" tags, ticket numbers on crate badges).

## Typography

Nunito (OFL) at three weights cut from the variable font (600 regular, 800 bold, 900 black), with Noto Sans Arabic as fallback. Sizes are at the 720-px-wide design base; **Larger text** scales them by 1.15.

| Role | Size | Weight | Variation |
|---|---|---|---|
| Display (boot title) | 52 | 900 | `DisplayLabel` |
| Screen title | 42 (auto-shrinks to fit, min 28) | 900 | `TitleLabel` / `NightTitle` |
| Heading | 33 | 800 | `HeaderLabel` / `NightHeader` |
| Body | 29 | 600 | `Label` / `NightLabel` |
| Strong body (list titles) | 29 | 800 | `StrongLabel` |
| Small | 25 | 600 | `SoftLabel` / `NightSoft` |
| Caption | 21 | 800 | `CaptionLabel` / `NightCaption` |

## Spacing, sizes, radii

- Spacing steps: 8, 12, 16, 24, 32 px. Screens use 12–18 between blocks; cards pad 20–24.
- Touch targets: **88 px** minimum (≈ 48 dp). Chips are 88 px round; dock tools 84 px with captions; level keys 116 px tall.
- Radii: 14 (tags), 24 (keys, panels), 28 (cards), 32 (dialogs, hero); pills are fully round.
- Shadows: warm `SHADOW` (`rgba(59,36,20,0.16)`), 12 px blur, 5 px down; night cards use a darker, neutral shadow.

## Components

| Component | API | Notes |
|---|---|---|
| Key button | `UI.button(text, cb, variation, min_h)` | Variations: `""` (teal primary), `SecondaryButton` (paper), `WarmButton` (coral), `GoldButton`, `TileButton`, `GhostButton`, `NightButton`, `LanternButton`. Tactile: a 6 px darker bottom edge; pressed keys sink 4 px. Disabled keys fade towards the ground. |
| Icon + text button | `UI.icon_text_button(glyph, text, cb, variation, h, sub)` | With `sub`, the icon sits in a light medallion (hero buttons: Play, Bake). |
| Chip | `UI.chip(glyph, cb, variation, size, badge)` | Round 88 px icon key (`ChipButton`, `NightChip`); optional count badge. |
| Badge / dot | `UI.badge(control, n)` | Coral bubble with a count, or a dot for `n < 0`. |
| Pill | `UI.pill(glyph, text)` | Token and star totals in headers. |
| Tag | `UI.tag(text, bg, fg)` | "NEW", "Ready!", "Done", "Owned", "Stamped". |
| Progress | `UI.progress(v, goal, colour)` / `UI.progress_row` | Rounded bar with highlight; mirrors in RTL. |
| Medallion | `UI.medallion(glyph, bg, fg, size)` | Circle with an icon; list-row and card leaders. |
| Section / row | `UI.section(text, glyph)` / `UI.row(leader, title, sub, trailing)` | Consistent list layout. |
| Header | `UI.header(title, on_back, trailing, night)` | Back chip, auto-fitting title, optional pill. |
| Segmented control | `UI.segmented(options, current, on_pick)` | Journal tabs, language picker. |
| Switch | `UI.switch(value, on_change)` | Track + knob with the word On/Off inside. |
| Dialog | `Dialog.make(title, text, buttons, extra, icon, night)` | Icon medallion, scroll-capped body (never runs off-screen), two secondary actions share a row under the primary. |
| Cards | `UI.card(child, variation)` | `CardPanel`, `SoftPanel`, `HeroPanel`, `TealPanel`, `WarmPanel`, `NightCard`, `ParchmentCard`. |
| Gameplay HUD (v7) | `game_screen.gd` `_Hud` | One paper strip with three equal readouts (Orders n/N with a segmented bar, Score in teal that rolls up and pops, Counter used/size with one pip per space, turning amber at one space left and terracotta "FULL" when full), then the "Next:" queue. Columns mirror in RTL. |
| Result card (v7) | `WinPanel.create(...)` | Title "Level complete!", level name, stars, score (display size, counts up), one breakdown caption, tokens actually paid, the next café step with an inline Warm "Restore" key when affordable, then **one** primary (Next / finale) and a secondary pair (Replay · Café). |
| Failure card (v7) | `game_screen._show_lost` | "No moves left", the cause in one sentence, a soft tip line; primary **Retry level**, secondary **Undo last move**. |

## Icons

`Glyph` draws every icon as vectors in one style: rounded strokes at about 7.5% of the icon size, filled shapes only for solid objects (coin, star, bell, lock body, play). Directional icons (back, next, chevron, undo, redo) mirror in RTL; the play triangle does not (media convention). Product icons (`"p_croissant"` etc.) reuse the game's full-colour product art. Icons inside disabled buttons dim automatically.

Set: back, next, chevron, undo, redo, restart, hint, pause, gear, help, info, star, star_empty, lock, check, close, plus, play, share, coin, book/journal, trophy, timer, eye, ribbon, bell, bell_line, brush, map, levels, cup, moon, lantern, stamp, target, music, sound, vibrate, motion, text, globe, calendar, bolt, door, spark, counter, crate, tap, reset, shield, heart, cake, flag, and `p_<product>`.

## Motion

| Token | Seconds | Use |
|---|---|---|
| `M_FAST` | 0.10 | Press feedback (key sinks and scales to 0.965) |
| `M_BASE` | 0.18 | Screen transition (fade + 18 px rise), dialog pop, switch, toast |
| `M_SLOW` | 0.32 | Celebrations, stamp landing |

Easing: ease-out cubic for movement, back-out for pops, sine for gentle emphasis. Emphasis loops are **limited** (Play button breathes 3 times, the current level pulses 4 times) and never flash. **Reduce motion** removes transitions, pulses, item flights and confetti (a brief still glow replaces bursts).

Interaction safety: every UI key ignores a second press within 350 ms and any press during a screen transition, so double taps never trigger an action twice. Gameplay taps snap running animations to their end before applying the next move, so the view always matches the game state. Result and failure cards are scheduled with a scene-tree timer, not an effect tween, so that snapping can never cancel them (v7 fix). Point pop-ups (+10 / +5 / +25) float from where the points were earned and are ordinary effects.

## Night (Midnight Ledger) and bakery treatments

- **Night**: `screen_mode = "night"` switches the background to a midnight gradient with faint stars and a lantern glow; the board wallpaper becomes a dark blue lattice with a walnut counter. Cards are `NightCard`/`ParchmentCard`, primary keys `LanternButton`, dialogs pass `night = true`. Gameplay objects (crates, tickets, products) are identical to the café, so rules read the same.
- **Bakery**: `screen_mode = "bakery"` tints the ground rose; the shop front awning is rose; the bakery primary action is coral.

## Assets and provenance

All artwork is original and drawn in code with Godot's 2D drawing API (no bitmaps except the launcher icon, which is rendered from the same vector art). No image-generation tool was available or used for v5. Fonts: Nunito and Noto Sans Arabic (SIL Open Font License 1.1, files in `game/assets/fonts`). See `THIRD_PARTY_NOTICES.md`. v5 adds no new binary assets, so the APK size is unchanged apart from code.
