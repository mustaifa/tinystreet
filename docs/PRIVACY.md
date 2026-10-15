# Privacy & Data Inventory (factual, per build)

*Last verified against the build manifests on 2026-10-15. This is a draft for the publisher and is not legal advice.*

## 1. Data inventory

### Default build (`Android Debug APK` / `Android Release AAB` presets). This is the build intended for the first release.
| Item | Behaviour |
|---|---|
| Permissions (from the APK manifest) | `android.permission.VIBRATE` only. No INTERNET permission. |
| Network | None. The app makes no network requests. |
| Third-party SDKs | None. Godot Engine only. |
| Stored on device | `user://save.json` (+ `.bak`/`.tmp`): progress, stars, tokens, café choices, settings, language, tutorial flags, in-progress puzzle moves, daily completion dates, the cached purchase entitlement flag, and handled reward/purchase reference hashes (never raw tokens). |
| Analytics | Local in-memory event buffer for development only (`Analytics`). **Not stored, not transmitted.** |
| Identifiers | None collected. No advertising ID, no device ID, no account. |
| Clipboard | Written only when the player taps "Share result". The text contains date, stars and moves. |

**Play Data safety form (default build):** no data collected and no data shared. A privacy policy URL is still **required** (see section 3).

### Monetisation test build (`Android Monetization Test APK`, custom feature `monetization`)
Adds Google Mobile Ads SDK 1.4.0 (through the Poing plugin) and Play Billing Library 9.1.0. Permissions observed in the manifest: INTERNET, ACCESS_NETWORK_STATE, AD_ID (`android.permission.AD_ID` and `com.google.android.gms.permission.AD_ID`), READ_BASIC_PHONE_STATE, `com.android.vending.BILLING`, WAKE_LOCK, FOREGROUND_SERVICE. Uses Google's **test** App ID and test rewarded unit only.

If this configuration is released, the Data safety form must declare the data that Google's SDKs collect: device or other identifiers (the advertising ID), app interactions and diagnostics for advertising, and purchase history through Play Billing. Use Google's current SDK data-disclosure guidance and the Google Play SDK Index. **Not yet done. This is a release blocker for any ads build.**

## 2. Consent flow
- Default build: no ad or analytics SDK and no off-device data, so no consent prompt is needed. Gameplay is fully offline.
- Monetisation build: `ConsentService` runs Google's **User Messaging Platform** before any ad request: update consent info, show the form if required, then initialise ads only if `canRequestAds`. A "Privacy choices" entry appears in Settings and Privacy when UMP reports that privacy options are required. **Unverified on a device.** It also requires the publisher to create GDPR (EEA/UK/CH) and US-states messages in the AdMob console. Official guidance confirmed 2026-10-15: a Google-certified, TCF-integrated CMP is required for personalised ads in the EEA and UK (since 2024-01-16) and Switzerland (since 2024-07-31). UMP supports the US states message (GPP).
- Declining consent never blocks gameplay. Rewarded ads are optional, and the campaign is completable without them.
- The game isn't directed at children. If the publisher's audience settings change, `tag_for_under_age_of_consent` must be set in UMP **and** on ad requests.

## 3. Privacy policy draft (fill in the bracketed items; these are release blockers)

> **Tiny Street: Sort & Restore: Privacy Policy**
> Publisher: **[LEGAL NAME, ADDRESS]**. Contact: **[SUPPORT EMAIL]**. Effective: **[DATE]**.
>
> *What we collect:* This version of the game doesn't collect, transmit or share personal data. Your progress and settings are stored only on your device, and uninstalling the game deletes them.
>
> *Permissions:* Vibration, for optional haptic feedback.
>
> *Sharing results:* If you tap "Share result", a short text (date, stars, moves) is copied to your clipboard. You decide where to paste it.
>
> *Children:* The game isn't directed at children under 13 **[confirm target audience in Play Console]**.
>
> *Changes:* If a future version adds advertising or purchases, we'll update this policy and ask for consent where required before any data is processed.
>
> *Contact:* **[SUPPORT EMAIL]**

For an ads or purchases build, add sections on Google AdMob (advertising ID, consent and how to change choices through the in-app "Privacy choices"), Google Play Billing, and a data-retention statement.

## 4. Logging rules (enforced in code)
- `Analytics` removes the keys `token`, `purchase_token`, `email`, `device_id` and `name` from every event.
- Purchases are referenced by `sha256(token)[:16]`. Raw tokens are never stored or logged.
- `Analytics` has unit tests (`test_analytics_dedupe_and_scrub`, `test_purchase_ref_never_contains_raw_token`).
