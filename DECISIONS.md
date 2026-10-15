# Decisions

Routine decisions made autonomously, with reasons. Newest last.

| # | Decision | Reason |
|---|---|---|
| D1 | **Engine: Godot 4.7.2-stable + GDScript**, Compatibility (GLES3) renderer | Latest stable (2026-08-18). Its Android template targets API 36, which matches Play's requirement since 2026-08-31. Maintained billing plugin (3.3.0, Billing Library 9.1.0, MIT) and AdMob plugin (Poing v5.1.0, MIT, tested through 4.7.2, includes UMP consent). GLES3 gives the widest device support for 2D. No blocker found, so no engine switch. |
| D2 | Godot project lives in `game/`; docs, tools and build output at the repo root | Keeps engine files separate from release paperwork. `build/` is git-ignored. |
| D3 | All art is **vector-drawn in code** (`ProductArt`, `CafeView`, `Glyph`) and baked to textures at boot | No specialist art tools were available. Gives fully original, resolution-independent, licence-clean assets. Baking avoids per-frame polygon triangulation. |
| D4 | All audio is **synthesised by `tools/make_audio.py`** | Original and reproducible, with no licensing risk. Quality is functional placeholder level (see Known issues). |
| D5 | Fonts: Nunito + Noto Sans Arabic (OFL 1.1), variable weights | Warm, rounded Latin face with a high-quality Arabic fallback in one font chain. |
| D6 | Routing priority = **lowest tray number** (leftmost in LTR, rightmost in RTL) | Simplest rule to explain and preview. Press-and-hold shows the destination. |
| D7 | Counter items are **not tappable**. They only leave automatically. | Keeps one interaction (tap a crate) and a clear mental model. |
| D8 | Loss = no legal move (not "counter full") | Required by the brief. Dead-end positions that still have moves are detected by the hint system instead ("undo N moves"). |
| D9 | Unlimited free undo; undo count still affects ★★★ (≤1 undo) | The brief requires at least one free undo. Making undo unlimited and free removes frustration while stars reward clean play. |
| D10 | Stars: ★ complete, ★★ peak counter ≤ solver minimum + 1, ★★★ plus ≤1 undo and no continue | Measurable and transparent. Thresholds come from solver analysis and need playtest tuning. |
| D11 | Hints: 1 free per attempt, more via optional rewarded ad. Hints never cost stars. | The brief forbids silent star reduction. Hints stay useful offline. |
| D12 | Tokens: 1 per first clear. Milestone costs sum to exactly 60. | The final restoration lands with the final level. There's no grind and nothing to buy. |
| D13 | Daily challenge: local calendar date, separate 60-level pool, no tokens | Deterministic and offline. Time-based rewards carry no economic value because clocks can be changed. |
| D14 | Share = copy text to clipboard | Godot has no Android share-sheet API without another plugin. The clipboard is a graceful, permission-free fallback. |
| D15 | Level generator is an **authoring aid**; shipped levels are fixed JSON with recorded solutions | Required by the brief. The generator is deterministic (seeded per level id). |
| D16 | Solver: DFS + transposition table + node budget. TIMEOUT is never a verdict. | Required. Shipped levels solve in under 400 nodes. |
| D17 | Service adapters with a **Disabled** base class. **Simulated** variants exist only in debug builds and are labelled on screen. | The campaign stays fully playable with no ads and no billing. No fake purchase path can ship in a release build. |
| D18 | AdMob and Play Billing AARs are added **only** to export presets with the custom feature `monetization`, through `addons/tinystreet_monetization` | The default release AAB contains no ad SDK, no AD_ID permission and no billing permission. That keeps the privacy footprint minimal until the publisher sets up AdMob, UMP and a verification server. |
| D19 | `REAL_PURCHASES_ENABLED = false` | Secure purchase verification needs a server calling the Play Developer API. None exists, and embedding keys in the app is forbidden. |
| D20 | **No starter bundle** | A consumable bundle of tokens or hints would either sell progression (which contradicts "no purchase needed") or add little value. Only one non-consumable cosmetic theme is offered. |
| D21 | Interstitials not implemented (interface returns disabled) | Disabled by default per the brief. The ad-removal product isn't relevant. |
| D22 | Analytics: local in-memory dev logger only; nothing transmitted | No production provider was selected. Avoiding one keeps the data-safety form minimal. The adapter has a single `_send` hook for later. |
| D23 | `inference_on_variant` GDScript warning set to *warn* (Godot 4.7 default is error) | A rarely hit code path with an untyped `:=` would otherwise fail compilation at runtime on a device. Typed declarations are still used where flagged. |
| D24 | Package id `com.tinystreet.sortrestore` | Placeholder. The publisher must confirm before the first Play upload because it can't be changed afterwards. |
| D25 | Arabic strings drafted without qualified review | No reviewer was available. Marked in Settings and docs as awaiting review. |
| D26 | Saves: JSON envelope with SHA-256 of the payload; tmp → bak → main rename sequence | Detects corruption and survives interrupted writes. It doesn't claim tamper-proofing. |
| D27 | In-progress puzzle saved as a **move list** and replayed on load | Compact and exact. Rebuilds the full undo history through the deterministic rules. |
| D28 | NDK removed from the local SDK after the first Gradle build | Disk space in the codespace was needed for the emulator. Godot's Gradle build uses prebuilt engine libraries, so the NDK only affects optional symbol stripping. |
