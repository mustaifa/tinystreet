# Implementation Plan & Status

| Stage | Scope | Status |
|---|---|---|
| **A. Environment & architecture** | Inspect the workspace (empty repo). Verify the stack (Godot 4.7.2, plugin maintenance and licences, Play target API 36). Lock the rules and the data format. | ✅ |
| **B. Core loop** | Rules, solver, validator, session with full undo; 10 levels; tutorial; win/loss; restart; save; real-input playthrough of levels 1–10 | ✅ |
| **C. Full content** | 60 campaign + 60 daily levels (generated, validated, fixed). Café restoration (5 milestones, 4 cosmetic categories). Daily challenge. EN/AR with RTL. | ✅ (Arabic review and human playtest pending) |
| **D. Services** | Ads (disabled / simulated / AdMob test), billing (disabled / simulated / Play, real purchases off), entitlements, reward broker, analytics (local), UMP consent adapter, opt-in monetisation export plugin | ⚠️ Code complete. AdMob, UMP and Play Billing are **unverified on a device**. |
| **E. Polish & verification** | Vector art + baked textures, synthesised audio, animations, reduced motion, large text, safe areas; lifecycle, rapid-tap, corruption and migration tests; exported-build inspection; emulator run | ⚠️ See TEST_REPORT. No real device was available. |
| **F. Packaging & handover** | Debug APK, unsigned AAB, monetisation test APK, checksums, docs | ✅ (signing 🔒) |

## v2 milestones (2026-10-16; plan and diagnosis in `docs/V2_PLAN.md`)
| Milestone | Scope | Status |
|---|---|---|
| **A. Core feel** | Destination badges, lift + guide line, drag or tap, sparkles, delivery burst with customer reaction, streaks, orders bar and next-customer row, finish sequence, café backdrop, new sounds and music | ✅ (desktop QA; not yet on a phone) |
| **B. Mechanics** | Fresh items, paper bags, delivery locks in `rules.gd`; solver, validator (engagement check), generator; 24 new levels + 4 respiked; tutorials f01/b01/k01 and a two-stage coach | ✅ 144/144 levels validated |
| **C. Restoration** | Interior café, 8 steps, 7 decor categories, extras, preview, star tokens with ledger, save schema 3 migration | ✅ |
| **D. Personality and return** | Cast and story beats, Journal (tasks, awards, progress, story replay), Challenges (Daily + Café Rush) | ✅ |
| **E. Integration** | Tests, QA scenarios, screenshots EN/AR, docs, `build/tinystreet-v2-debug.apk` | see SESSION_HANDOVER / TEST_REPORT |

## Architecture
```
            ┌──────────── presentation (src/screens, src/board, src/ui) ────────────┐
            │   view = f(PuzzleSession.state) + transient effects                   │
            └──────────────┬───────────────────────────────┬────────────────────────┘
                           │ taps                           │ events (pick/to_tray/...)
     ┌─────────────────────▼─────────────────┐   ┌──────────▼───────────────────────┐
     │ core (pure RefCounted, no Nodes)      │   │ meta: Progression, Restoration,   │
     │ Rules · PuzzleState · PuzzleSession   │   │ Wallet (ledger), Tasks, Achieve-  │
     │ Solver · LevelValidator · Scoring     │   │ ments, Meta, Story, Customers,    │
     │ LevelDef (fresh/bag/lock markers)     │   │ RushRun, GameData, SaveStore v3   │
     └───────────────────────────────────────┘   └──────────┬───────────────────────┘
                                                             │
     ┌──────────────── App autoload (DI via ServiceFactory + BuildConfig) ─────────┐
     │ AdService ← Simulated / AdMob · BillingService ← Simulated / PlayBilling    │
     │ RewardBroker (idempotent) · Entitlements · Analytics · ConsentService (UMP) │
     └─────────────────────────────────────────────────────────────────────────────┘
```

## Next tasks (priority order)
1. Phone playtest of v2 with `docs/PLAYTEST.md` (migration over v1, first 15 minutes, the three mechanics). Then tune the level curve, token pace and star thresholds from real data.
2. Test on more real devices (low-end and mid-range): frame timing with confetti and café animation, memory, haptics, cutouts, back button.
3. Qualified Arabic review.
4. Publisher setup: package id, upload key, privacy policy URL, Play listing, data safety.
5. Optional monetisation: verify AdMob test ads and UMP on a device; build the purchase verification server; then enable `REAL_PURCHASES_ENABLED`.
6. Art and audio pass (café detail, music), and a 1024×500 feature graphic.
