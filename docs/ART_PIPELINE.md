# Art, Sound & Colour Pipeline (skins)

*Since v6 (0.6.0). Code: `game/src/ui/art_skin.gd` (`ArtSkin`). Tests: `game/tests/test_skin.gd`.*

Every image, sound and UI colour in the game can be replaced **without touching code**. You drop files into a skin folder and list them in that folder's `skin.json`. Any key a skin leaves out falls back to the built-in art (vector drawings in code, or the original sound files). So you can replace one picture today and the rest later.

## How it works

```
game/skins/<skin_id>/skin.json      shipped with the app (res://)
user://skins/<skin_id>/skin.json    side-loaded / downloaded later (wins over res://)
```

- At boot, `App.boot()` calls `ArtSkin.load_skin(BuildConfig.skin_id(settings))`. The default is `default`; `settings.skin` selects another; `--skin=<id>` on the command line previews one.
- A skin can **`extend`** another and override only some keys, e.g. a winter theme that changes four products and two colours. Chains are resolved base first, up to 4 deep.
- Drawing code asks `ArtSkin.draw_fit()`, `draw_rect()` (nine-patch) or `draw_cover()` first; when that returns `false`, it draws the built-in art.
- Problems never crash the game: a missing file, a bad colour or an unknown key is collected in `ArtSkin.errors`, printed as a warning at boot, and the built-in art is used.

## `skin.json`

```json
{
  "name": "Winter on Tiny Street",
  "extends": "default",
  "colors": { "TEAL": "#2a6f97", "GOLD": "#e8c15a" },
  "images": {
    "product.coffee": "products/cocoa.png",
    "board.counter": { "file": "board/counter.png", "margins": [44, 40, 44, 40] },
    "board.crate":   { "file": "board/crate.png", "margins": [28, 28, 28, 28], "tile": true },
    "icon.coin":     { "file": "icons/coin.svg", "tint": false },
    "icon.gear":     { "file": "icons/gear.svg", "tint": true }
  },
  "sounds": {
    "sfx.deliver": "sfx/sleigh_bell.ogg",
    "sfx.tap": { "file": "sfx/tap.ogg", "volume_db": -4 },
    "music.cafe": "music/winter_loop.ogg"
  }
}
```

| Field | Meaning |
|---|---|
| `images.<key>` | A path relative to the skin folder (or `res://…` / `user://…`), or an object: `file`, plus optional `margins` `[left, top, right, bottom]` in **design pixels** (makes it a nine-patch), `tile` (tile the middle vertically, e.g. crate slats), `scale` (extra size factor, default 1), `tint` (`true` for white line icons that should take the UI colour) |
| `sounds.<key>` | A path, or `{ "file", "volume_db" }` to balance loudness between packs |
| `colors.<TOKEN>` | Overrides a `Style` colour token (list below). Derived tokens such as `SUCCESS` (= `TEAL`) are separate tokens: override them too if needed |

**Formats.** Images: SVG (preferred for flat art; imported at 2× for sharp phones), PNG or WebP (export at 2× the design size). Sounds: OGG (preferred), WAV, MP3. New files under `res://` are imported automatically with mipmaps and 2× SVG scale (project `importer_defaults`). Nine-patch margins stay in design pixels whatever the import scale: `ArtSkin.density()` reads it from the `.import` file.

## Keys

### Products (square, transparent, ~85% of the box, soft ground shadow included). Design size 256 px
`product.coffee` · `product.tea` · `product.croissant` · `product.cupcake` · `product.strawberry` · `product.chocolate` · `product.bag` (the hidden "paper bag" item)

Each product must keep a **distinct silhouette** (cup, tin, crescent, cupcake, basket, box), because colour is never the only cue.

### Board
| Key | Kind | Default design size | Used by |
|---|---|---|---|
| `board.crate` | nine-patch, `tile` | 160×152, margins 28 | the crate behind the stack (`CrateView`) |
| `board.crate_front` | nine-patch | 200×168, margins 36 | the box holding the selectable front item |
| `board.counter` | nine-patch | 400×128, margins 44/40 | the holding counter bar (`CounterView`) |
| `board.slot` | square | 128 | one counter slot |

### Characters (square portrait, head and shoulders). Design size 256 px
`character.<who>` or, per mood, `character.<who>.neutral` / `.happy` / `.waiting`.
`who` ∈ `mira`, `theo`, `basil`, `n0` … `n5` (neighbour customers).

### Backgrounds (portrait; drawn "cover": scaled to fill, centre cropped). Design size 1080×1920
- Puzzle screen: `bg.<mode>.wall` (above the crates) and `bg.<mode>.floor` (the counter top the crates stand on). `mode` ∈ `cafe`, `night` (Midnight Ledger), `bakery`.
- Menu screens: `bg.<mode>.screen`.

Keep backgrounds low in contrast. Tickets, products and text must stay readable on them (`test_ui.gd` checks text contrast against the theme colours, not against images, so review by eye).

### Icons (square). Design size 96 px
`icon.<kind>` for any of: back, chevron_back, next, chevron, undo, redo, restart, hint, pause, gear, help, info, star, star_empty, lock, check, close, plus, play, share, coin, book, journal, trophy, timer, eye, ribbon, bell, bell_line, paint, brush, map, levels, cup, croissant, moon, lantern, stamp, target, music, sound, vibrate, motion, text, globe, calendar, bolt, door, home, spark, counter, crate, tap, reset, trash, shield, heart, cake, flag.
Draw directional icons (back, next, undo, redo, chevron) for left-to-right; they are mirrored automatically in Arabic.

### Sounds
`sfx.<name>` for: tap, place, counter, invalid, stage, deliver, win, star, lose, restore, undo, warn, combo, coin, bag, unlock, bell. Plus `music.cafe` (looped).

### Colour tokens (`Style`)
CREAM, CREAM_DEEP, LINEN, PAPER, PAPER_EDGE, INK, INK_SOFT, INK_FAINT, TEAL, TEAL_DARK, TEAL_EDGE, TEAL_SOFT, TERRACOTTA, CORAL_EDGE, TERRA_SOFT, GOLD, GOLD_EDGE, GOLD_SOFT, WOOD, WOOD_DARK, WOOD_LIGHT, SUCCESS, WARN, DANGER, LOCKED, SHADOW, NIGHT, NIGHT_2, NIGHT_3, NIGHT_LINE, MOON, MOON_SOFT, LANTERN, LANTERN_EDGE, PARCHMENT, PARCHMENT_EDGE, ROSE, ROSE_SOFT.
After changing text or background colours, run the tests: `test_ui.gd:test_text_contrast` must still pass.

### Not yet skinnable (still drawn in code)
The café interior and its restoration steps (`cafe_view.gd`), the bakery interior (`bakery_view.gd`), the shop-front frame (`storefront.gd`), level keys (`level_cell.gd`), the Midnight Ledger illustration, and the order-ticket paper. These are the next candidates. Follow the same pattern: add a key, try `ArtSkin` first, keep the code art as the fallback.

## Workflow for a new art drop

1. Put the files in `game/skins/default/` (to replace the default art) or in a new `game/skins/<id>/` with `"extends": "default"`.
2. Add the keys to `skin.json`.
3. Import: `godot --headless --path game --import`.
4. Contact sheet: `godot --headless --path game -s res://tools/skin_sheet.gd -- <id> /tmp/sheet.png 200`. Check that nothing reports `FAILED`.
5. See it in the game: `xvfb-run -a godot --path game --rendering-driver opengl3 --resolution 720x1280 -- --skin=<id> --qa=tour --qa-out=DIR`.
6. Run the tests. `test_skin.gd` checks that the default skin is complete and that every listed file loads.
7. **Record provenance** in `THIRD_PARTY_NOTICES.md` (author, source URL, licence) and keep a `LICENSE.txt` in the folder for any third-party pack. Only use assets you own or that are CC0 / licensed for commercial use.

## Free sources that fit the style (all checked for commercial use)
- **Kenney** (kenney.nl): CC0 sound packs, already used for the sound effects. Their 2D packs are generic, so match the style before using any.
- Commissioned or AI-assisted art should be delivered as layered source + 2× PNG/SVG per key above, with written confirmation of commercial rights.

## Selling themes later
A purchasable or seasonal theme is just another skin folder that `extends` the default. To ship one, add the folder, gate `settings.skin` on an entitlement, and offer it in the Shop. No drawing code changes are needed.
