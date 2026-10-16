# Release Checklist

Legend: ✅ done and verified here · ⚠️ done but unverified or partial · ❌ not done · 🔒 blocked on publisher, account or credentials

## Build & signing
| Item | Status | Notes |
|---|---|---|
| Engine and templates pinned (Godot 4.7.2-stable, SHA-512 verified) | ✅ | |
| targetSdk 36 / minSdk 24 / compileSdk 36 | ✅ | From the APK manifest. Play requires API 36 for new apps and updates since 2026-08-31 (verified 2026-10-15). |
| Debug APK v1 (`build/tinystreet-debug.apk`) | ✅ | **Debug-signed**. Real-device smoke test by the owner: installs and renders (2026-10-16). Kept for comparison. |
| Debug APK v2 (`build/tinystreet-v2-debug.apk`) | ✅ | Debug-signed, 0.2.0 / code 2. Owner reports "the updated Android version works" on a real phone (2026-10-16; exact build not stated). |
| Debug APK v3 (`build/tinystreet-v3-debug.apk`) | ✅ | 0.3.0 / code 3. Owner: "currently works" on their phone (full feedback pending). |
| Debug APK v4 (`build/tinystreet-v4-expert-debug.apk`) | ⚠️ | 0.4.0 / code 4, same key. Built and inspected here; **pending the owner's phone test**. |
| Release AAB (`build/tinystreet-release-unsigned.aab`) | ⚠️ | **Unsigned.** Must be signed with the publisher's upload key. Not store-ready. |
| Upload key / Play App Signing | 🔒 | Create the upload keystore outside the repo and supply it through Godot export credentials or environment variables (`GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `..._USER`, `..._PASSWORD`). Never commit it. |
| Package id final | 🔒 | Placeholder `com.tinystreet.sortrestore`. It can't be changed after the first upload. |
| versionCode bump policy | ✅ | Increment `version/code` in **both** release presets for every upload. `version/name` follows semver. |
| App name / trademark search | 🔒 | |

## Store & policy
| Item | Status |
|---|---|
| Play developer account, app created | 🔒 |
| New personal accounts: closed test with **≥12 testers opted in for 14 continuous days** before production access (verified 2026-10-15) | 🔒 |
| Privacy policy URL (draft in `docs/PRIVACY.md`, needs publisher identity and contact) | 🔒 |
| Data safety form (default build: no data collected or shared) | ❌ (publisher) |
| Content rating (IARC) | ❌ (publisher) |
| Target audience and content (not directed at children; confirm) | ❌ (publisher) |
| Store listing text (`docs/STORE_LISTING.md`) | ⚠️ draft |
| Screenshots ≥1080 px and 1024×500 feature graphic | ⚠️ 720 px screenshots captured from the game; recapture at 1080×1920. No feature graphic yet. |
| Support email | 🔒 |

## Monetisation (only if shipping the `monetization` build)
| Item | Status |
|---|---|
| AdMob account, real App ID and rewarded unit IDs (replace test IDs in `BuildConfig` and the export plugin) | 🔒 |
| UMP messages (GDPR + US states) configured in AdMob | 🔒 |
| Consent flow verified on a device in EEA debug geography | ❌ |
| Rewarded flow verified with test ads on a device with Play services | ❌ |
| Play Billing products created in Play Console (`theme_evening`, non-consumable) | 🔒 |
| Server-side purchase verification and acknowledgement service | 🔒 → `REAL_PURCHASES_ENABLED` stays `false` |
| Data safety form updated for the Google Mobile Ads SDK and Billing | ❌ |
| Ads declaration "Contains ads" | ❌ |

## Quality
| Item | Status |
|---|---|
| Automated tests pass | ✅ (see TEST_REPORT.md) |
| All shipped levels validated (164/164 PASSED, 0 UNVERIFIED, mechanics engaged, bell claims re-proven) | ✅ |
| Human playtest (`docs/PLAYTEST.md`) | ❌ (v1 smoke test only) |
| Real-device test (low-end and modern phones) | ⚠️ v1 on one phone (renders); v2 none |
| Save migration to schema 4 tested on a real install-over-update | ❌ (unit-tested with a full v2 player; pre-migration backup file written) |
| Purchase verification server (required before `REAL_PURCHASES_ENABLED`) | ❌ still not built; real purchases stay disabled |
| Arabic text reviewed by a qualified translator | ❌ |
| Audio and music final pass | ⚠️ (v2: longer original synthesised loop + 16 SFX; still synthetic) |
| Café tasks / Daily use the device clock (documented, not secure) | ✅ documented |
| Godot licence text bundled in the app | ❌ (Credits names Godot; add the full licence page) |

## Rollback / versioning
- Every Play upload is immutable per versionCode. To roll back, upload the previous good build with a **higher** versionCode. Tag each release in git (`git tag v0.1.0-internal.1`).
- Save schema migrations are forward-only (`SaveStore.migrate`). **Caveat:** `GameData.sanitize` keeps only the keys the running build knows, so an older build that re-saves will drop newer keys. Keep schema changes additive, and avoid rollbacks across schema bumps where possible.
- Use staged rollouts (internal → closed → production at 5–20%) and halt the rollout in Play Console if crash rates rise.
