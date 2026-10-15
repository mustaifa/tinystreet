# Implementation Plan & Status

| Stage | Scope | Status |
|---|---|---|
| **A. Environment & architecture** | Inspect the workspace (empty repo). Verify the stack (Godot 4.7.2, plugin maintenance and licences, Play target API 36). Lock the rules and the data format. | ✅ |
| **B. Core loop** | Rules, solver, validator, session with full undo; 10 levels; tutorial; win/loss; restart; save; real-input playthrough of levels 1–10 | ✅ |
| **C. Full content** | 60 campaign + 60 daily levels (generated, validated, fixed). Café restoration (5 milestones, 4 cosmetic categories). Daily challenge. EN/AR with RTL. | ✅ (Arabic review and human playtest pending) |
| **D. Services** | Ads (disabled / simulated / AdMob test), billing (disabled / simulated / Play, real purchases off), entitlements, reward broker, analytics (local), UMP consent adapter, opt-in monetisation export plugin | ⚠️ Code complete. AdMob, UMP and Play Billing are **unverified on a device**. |
| **E. Polish & verification** | Vector art + baked textures, synthesised audio, animations, reduced motion, large text, safe areas; lifecycle, rapid-tap, corruption and migration tests; exported-build inspection; emulator run | ⚠️ See TEST_REPORT. No real device was available. |
| **F. Packaging & handover** | Debug APK, unsigned AAB, monetisation test APK, checksums, docs | ✅ (signing 🔒) |

## Architecture
```
            ┌──────────── presentation (src/screens, src/board, src/ui) ────────────┐
            │   view = f(PuzzleSession.state) + transient effects                   │
            └──────────────┬───────────────────────────────┬────────────────────────┘
                           │ taps                           │ events (pick/to_tray/...)
     ┌─────────────────────▼─────────────────┐   ┌──────────▼───────────────────────┐
     │ core (pure RefCounted, no Nodes)      │   │ meta: Progression, Restoration,   │
     │ Rules · PuzzleState · PuzzleSession   │   │ GameData, SaveStore (atomic,      │
     │ Solver · LevelValidator · Scoring     │   │ checksummed, migrations)          │
     └───────────────────────────────────────┘   └──────────┬───────────────────────┘
                                                             │
     ┌──────────────── App autoload (DI via ServiceFactory + BuildConfig) ─────────┐
     │ AdService ← Simulated / AdMob · BillingService ← Simulated / PlayBilling    │
     │ RewardBroker (idempotent) · Entitlements · Analytics · ConsentService (UMP) │
     └─────────────────────────────────────────────────────────────────────────────┘
```

## Next tasks (priority order)
1. Human playtest with `docs/PLAYTEST.md`, then tune the curve spikes (c025, c034, c048, c057) and the star thresholds.
2. Test on a real device (low-end and mid-range): frame timing, memory, haptics, cutouts, back button.
3. Qualified Arabic review.
4. Publisher setup: package id, upload key, privacy policy URL, Play listing, data safety.
5. Optional monetisation: verify AdMob test ads and UMP on a device; build the purchase verification server; then enable `REAL_PURCHASES_ENABLED`.
6. Art and audio pass (café detail, music), and a 1024×500 feature graphic.
