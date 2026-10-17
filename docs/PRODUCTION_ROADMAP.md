# Production Roadmap: from polished prototype to a revenue-earning game

*Agreed with the owner on 2026-10-16. Constraints: **use free resources and services for now**, and build everything so that art, prices, ad frequency and content can be changed later **without code changes**.*

Status key: ✅ done · 🔨 in progress · ⬜ not started · 🔒 needs the owner (accounts, money, decisions)

## Phase A: look and feel (v6, 0.6.0)
| Item | Status | Notes |
|---|---|---|
| Skin system: every image, sound and colour swappable by a manifest | ✅ | `ArtSkin`, `docs/ART_PIPELINE.md` |
| New default product and board art (SVG) | ✅ | Hand-written SVGs; an artist pass can replace them key by key |
| Real sound effects (Kenney, CC0) | ✅ | `lose` and the music loop are still synthesised |
| Ticket redesign (one picture per unit), crates sized to contents, bigger items, less text | ✅ | |
| Home Play key, win card coin count-up and trimmed content | ✅ | |
| Skin hooks for characters, icons and backgrounds | ✅ | No default art yet for these keys (built-in drawings in use) |
| Café interior, bakery, shop front and level keys as skinnable art | ⬜ | Next art-pipeline step (see ART_PIPELINE "Not yet skinnable") |
| Free CC0 café music loop | ⬜ | Candidate sources need licence checks; drop it in as `music.cafe` |
| Street-map level select | ⬜ | Replaces the chapter grids |
| Store graphics (icon refresh, 1024×500 feature graphic, 1080×1920 captioned screenshots) | ⬜ | Can be produced from the game's own art |

## Phase B: revenue (free services)
All of these work on free tiers. The only unavoidable cost is the **one-time $25 Google Play developer fee** 🔒.

| Item | Status | Free option |
|---|---|---|
| `config/economy.json` + `config/ads.json`: prices, booster costs, ad frequency, first-interstitial level, all as data | ⬜ | Bundled JSON, later overridable remotely |
| Boosters (shuffle a crate, reveal bags, +1 counter slot), earned in play and with coins | ⬜ | Rules stay in `rules.gd`; the solver and validator must understand them |
| Rewarded ads: continue, double coins, free booster, daily bonus | 🔨 | AdMob (free). The adapter and reward broker already exist; real unit IDs 🔒 |
| Interstitials: from level ~15, at most 1 every 3–4 levels, never mid-level | ⬜ | AdMob; frequency from config |
| **Remove Ads** ($3.99–4.99), starter pack, coin packs, seasonal theme skins | ⬜ | Google Play Billing (free) |
| Purchase verification | ⬜ | **Cloudflare Workers free tier** (100k requests/day) calling the Play Developer API. `REAL_PURCHASES_ENABLED` stays `false` until it is live |
| Gradle Android build so the AdMob and Billing plugins load | ⬜ | Free |
| AdMob account, UMP consent messages, Play Console products | 🔒 | Owner accounts |

## Phase C: measure
| Item | Status | Free option |
|---|---|---|
| Analytics with consent: retention D1/D7, level funnel and fail rate, ad and IAP events | ⬜ | **GameAnalytics** (free) or Firebase Analytics (free); the `Analytics` adapter has a `_send` hook |
| Crash reporting | ⬜ | Sentry free tier (Godot SDK) or Firebase Crashlytics (free) |
| Remote config: ad frequency, prices, level order | ⬜ | Firebase Remote Config (free), or a JSON file on GitHub Pages / Cloudflare |
| CI: tests + level validator + signed AAB on tags | ⬜ | GitHub Actions (free minutes) |
| Split `game_screen.gd` (1,170 lines) into board / HUD / input+hint controllers | ⬜ | |

## Phase D: content and retention
| Item | Status |
|---|---|
| 300+ levels at launch using the existing generator + validator, with a tuned difficulty curve | ⬜ |
| Daily login rewards, weekly themed event, local notifications ("your café misses you") | ⬜ |
| Cloud save + achievements (Google Play Games Services, free) | ⬜ |
| More languages: es, pt-BR, de, fr, ja, ko (the string pipeline already supports this) | ⬜ |

## Phase E: launch
| Item | Status |
|---|---|
| Closed test: 12+ testers for 14 days (Play requirement for new personal accounts) | 🔒 |
| Soft launch in 1–2 countries, tune from analytics | ⬜ |
| Privacy policy URL, data safety form, content rating, final name/trademark check | 🔒 |

## Principles that stay
- No energy, no lives, no timers in the campaign. Undo and restart are always free.
- Ads never interrupt a puzzle. Rewarded ads are always the player's choice.
- Every reward is paid once, through the grant ledger.
- Real purchases stay off until server verification exists.
