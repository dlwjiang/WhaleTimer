# Tick & Kin 1.0 — submission handoff

Prepared November 12, 2026. The owner confirmed that **nothing is configured in App Store Connect yet**. Local preparation is not a live submission. No agreements were accepted, banking details entered, products created, or build uploaded by this work.

## 1. Establish the seller and payment account

- Enroll in the Apple Developer Program if you have not already, using the intended individual or organization. The existing website identifies the publisher as **Wei Jiang**; ensure the enrollment and public legal identity agree.
- In App Store Connect → Business, accept the Paid Apps Agreement, complete the tax forms Apple presents for your account, and enter a bank account for payouts. This is needed for the optional purchases even though the app download is free. Use your own account details, not credentials shared in chat.
- Complete identity/business verification requested by Apple. For EU distribution, assess and declare trader status; a commercial app sold for profit is a strong reason to review the trader requirements. Trader contact details are displayed publicly.
- Consider the Small Business Program if eligible; the reduced commission is not automatic.

Apple references: [enrollment](https://developer.apple.com/programs/enroll/), [paid purchase setup](https://developer.apple.com/help/app-review/before-submitting-for-review/configure-in-app-purchases), [payments](https://developer.apple.com/help/app-store-connect/getting-paid/overview-of-receiving-payments/), [tax forms](https://developer.apple.com/help/app-store-connect/manage-tax-information/provide-tax-information/), [EU trader requirements](https://developer.apple.com/help/app-store-connect/manage-compliance-information/manage-european-union-digital-services-act-trader-requirements/), [Small Business Program](https://developer.apple.com/app-store/small-business-program/).

## 2. Create the app record

| Field | Prepared value |
| --- | --- |
| Platform | iOS; universal iPhone/iPad app |
| Name / primary language | Tick & Kin / English (U.S.) |
| Bundle ID | `app.banke.timer` — register this exact explicit identifier |
| SKU | `tick-and-kin-ios` (internal suggestion) |
| Version / build | 1.0 / 1 |
| Download price | Free |
| Primary category | Productivity |
| Secondary category | Utilities (optional) |
| Copyright | `2026 Wei Jiang` |
| Minimum OS | iOS / iPadOS 17.0; Duo-specific layout uses 27.1 APIs |
| Support | `https://tick-and-kin.theory-a.com/support/` |
| Privacy | `https://tick-and-kin.theory-a.com/privacy/` |
| Marketing | `https://tick-and-kin.theory-a.com/` |
| Contact email | `support@theory-a.com` |

If Apple rejects the bundle identifier as unavailable, change it consistently in the generator, project, app record and purchase identifiers before registering products. Do not improvise different purchase IDs in the dashboard.

Paste the localized fields from `metadata/app-store.json` or the nine individual `.txt` files. Names/subtitles are within 30 characters, promotional text within 170, keywords within 100, descriptions within 4,000. These are editorial drafts; name reservation and native-speaker marketing review remain unverified. No “What's New” field is necessary for the first version.

Complete the age-rating questionnaire from actual content: no user-generated content, messaging, unrestricted embedded web browser, gambling, ads, sexual content or violence. Cute artwork does not make this a Kids Category submission. Let App Store Connect calculate the rating. No medical claims are made. Do not claim accessibility badges without completing the relevant physical-device evaluation.

Select territories deliberately. Chinese-language support does not itself establish eligibility for distribution in mainland China; check the permits/filing fields Apple presents before selecting that storefront. [Apple's regional compliance guidance](https://developer.apple.com/help/app-store-connect/manage-compliance-information/view-china-mainland-compliance-information/).

## 3. Create all four non-consumable purchases

| Reference name | Exact product ID | Proposed US price |
| --- | --- | --- |
| Midnight Café | `app.banke.companions.midnightCafe.v1` | $3.99 |
| Moonlight Academy | `app.banke.companions.moonlightAcademy.v1` | $3.99 |
| Orbital Night Shift | `app.banke.companions.orbitalNightShift.v1` | $3.99 |
| Three-Pack Collection | `app.banke.companions.collection.v1` | $8.99 |

These are **one-time purchases**, not subscriptions or consumables. Each pack adds three companions; the collection contains these three launch packs only. The current configuration does not promise Family Sharing. Decide that explicitly before enabling it in App Store Connect. Local prices do not create production prices; choose the corresponding price points and regional availability in the dashboard.

`metadata/in-app-purchases.json` contains all nine localizations. Use the actual purchase-control captures under `iap-review/` for review. Notes: Settings → Companion packs → the named pack → purchase button. The collection is at the bottom of the packs page and appears only when no paid pack is owned. Restore is on the packs page. No account or login is needed.

Attach all four purchases to the **first app-version review submission**. Verify the product statuses and availability before TestFlight. [First-purchase review guidance](https://developer.apple.com/help/app-store-connect/manage-submissions-to-app-review/submit-an-in-app-purchase/).

## 4. Upload assets

Use the PNGs in `store-upload/en/`; these contain actual native app captures with headline framing. The unframed app-window captures are in `screenshots/`. Do not upload contact sheets or the generated desk photographs into screenshot slots.

| Display | Prepared capture dimensions |
| --- | --- |
| iPhone medium | 1206 × 2622 |
| iPhone large | 1320 × 2868 |
| iPad 13-inch | 2064 × 2752 |
| Duo outer | 1398 × 2034 |
| Duo inner landscape | 2853 × 2007 |
| Duo inner tabletop | 2007 × 2853 |

The required baseline is medium iPhone plus 13-inch iPad for this universal app. Duo has its own slots; Apple states that submitting Duo screenshots enables its product-page Duo badge. Optional smaller iPad slots can use App Store Connect's scaling. Upload the English set for the primary listing; localized screenshot text can be added later, while the prepared listing text covers all nine languages. The screenshots contain no transparency. [Current screenshot specifications](https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications).

The app icon is embedded in the build; `marketing/app-icon-1024.png` is a convenient copy. There is no required separate “search header”: search presentation uses the app icon, metadata and eligible listing media. `marketing/launch-header.png`, `social-preview.png` and `launch-square.png` are promotional compositions. The two desk scenes are AI-generated visualizations, not photographs of a physical device or evidence of Apple endorsement. See `marketing/PROVENANCE.md`.

If Apple requests editorial artwork after a featuring nomination, use that request's specific templates. These general headers are not claimed to meet every editorial placement template. [Apple artwork guidance](https://developer.apple.com/app-store/asset-best-practices/).

## 5. Sign, TestFlight, then submit

1. Open `ios/Banke.xcodeproj`, select **Banke** and your Apple Developer team under Signing & Capabilities. Use the normal Banke scheme, not BankeStoreKit. No production purchase bypass is present.
2. Select a generic/connected iOS device, Product → Archive, then distribute through App Store Connect. The local unsigned archive is only build evidence; it cannot be uploaded as a signed production release. Increase build number for subsequent uploads of this version.
3. In TestFlight, test one real iPhone and one iPad; include Duo hardware if available. Use the short checklist below. Do not submit while purchase products remain unavailable.
4. Supply the App Review contact's name and reachable phone number in the private review fields. Use `metadata/review-notes.txt`. No demo credentials are necessary.
5. Complete privacy, content rights, export compliance, age rating and availability fields. Select the processed build and all four IAPs. Choose manual release so you can coordinate the website and announcement after approval.
6. After approval, add the real App Store URL to `marketing/site.config.mjs`, rebuild/deploy the website, then release the app. App Review approval and featuring are separate decisions.

### One short owner spot-check

- Run a one-minute focus session; pause/resume, lock the phone, return after completion, and start a break. Enable reminders and confirm the notification. Repeat once with both break toggles off.
- Listen to one chosen voice on the actual speaker and headphones; sample another language. Confirm muted/silent-mode behavior and that your music is not interrupted.
- On Duo, fold/unfold during a running session. Check shelf alignment, timer controls and the current deadline. On iPad, rotate once and try large text. With VoiceOver, reach the timer, Settings and purchase/restore controls.
- In TestFlight/sandbox, buy one pack, restore after reinstall, cancel a purchase, and verify the collection flow from a clean tester. Confirm real localized prices. Do not use live charges for QA.
- Observe a 25-minute session on hardware for heat/battery behavior, with keep-awake on and off. Simulator CPU/RAM observations cannot establish battery life.

Only these focused hardware checks remain; repeating every companion on every device is not required for this handoff.
