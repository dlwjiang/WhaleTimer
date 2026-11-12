# v1.0 release audit

## Outcome

The focused automated regression checks passed and an unsigned optimized archive was produced. The release is **prepared for owner review and App Store Connect setup**, not yet signed, uploaded, TestFlight-validated or submitted. The owner confirmed there is no App Store Connect record or commerce setup yet.

## Changes made

- Set marketing version to 1.0, retaining build 1 in the project and project generator.
- Added localized Support, Privacy policy and Terms of use links in Settings, in all nine languages. The app previously had no in-app access to the published policy.
- Declared no non-exempt encryption in the app plist, consistent with the inspected use of Apple system services.
- Added an opt-in native screenshot capture helper and made the existing pack detail view accessible to the test target. No test-only ownership bypass or screenshot state is compiled into app behavior.
- Prepared store assets, four purchase review images, nine-language listing copy, legal/privacy handoff, a featuring nomination and two generated desk scenes.

## Regression evidence

| Check | Result / scope |
| --- | --- |
| Core Swift tests | 37 passed; session state, break cycles, restoration, localization and shelf geometry. |
| Native local StoreKit | 7 passed; catalog, individual purchase, collection, restore, refund, pending approval, cancellation/failure and unverified transactions. |
| Native experience | 7 passed; idle invalidations, cancelled preview, offline voice library, background/preparation cancellation, language/companion changes, text-size changes, recorded playback and independent sound effects. |
| Resource integrity and full audio decode | 163 UI keys × 9 languages; 4 products × 9 localizations; all 1,248 voice clips passed format/duration and full decode checks. Checks approved casting hashes and selected-engine routing, not merely filenames. |
| Optimized iOS archive | Successful unsigned Release archive; simulator-only test code excluded. |
| Optimized simulator build | Successful; used for the bounded CPU/RAM observation below. |
| Public URLs | Home, privacy, terms and support all returned HTTP 200. Mail delivery not tested. |
| Store assets | Dimensions, opacity, required files and metadata field limits checked by the package verifier. |

Logs and machine-readable results are in `verification/`. The archive is `/tmp/TickKin-1.0.xcarchive`; rebuild/sign from the normal Banke scheme for upload. The AppIntents metadata extractor emitted its expected “no AppIntents.framework dependency” warning; this app does not implement App Intents.

### Capture failure investigated

On the first run in a fresh 13-inch iPad simulator, the local test purchase did not unlock the collection. The screenshot helper correctly reported a test failure; the incorrectly named premium capture from that run was not exported. The same capture passed on retry, including the verified purchase and Luna selection. The native purchase suite also passed on Duo. This is recorded as a first-run local StoreKit failure, with the exact underlying service cause unresolved. Actual App Store Connect products and TestFlight purchases are still a release gate.

## Performance review

The optimized iOS app bundle is approximately **151 MiB on disk before App Store processing**. This is not a customer download-size estimate. Bundled voice assets total about 32 MiB. Historical artwork remains in the asset catalog; removing it would require a separate resource migration and was not mixed into the release cut.

The idle-ready timer produces **zero observable-state publications across 100 polls**, including the paused preparation state. Audio-session activation and player preparation are off the UI actor; previews and preparation tasks are cancelled on dismissal/background. The timer uses a deadline and saves on transitions instead of writing storage on every tick. No background audio entitlement or recurring server polling is present.

A 21-second `ps` sample of the optimized app on the isolated iPhone 18 Pro simulator showed startup CPU at 96.1% in the first sample, then six samples rounded to 0.0%; resident memory settled from about 318 to 312 MiB. See `verification/idle-performance.json`. This measures one ready scene on a development machine, not animation frame time, sustained running energy, a leak test, launch latency or physical-device battery life. No battery or thermal promise is inferred.

## Remaining release gates

1. Apple Developer seller/account enrollment, signing, agreements, bank/tax verification and territory compliance.
2. App Store Connect app and four products; actual localized prices, availability and TestFlight purchase/restore validation.
3. Owner's short hardware check for notifications, chosen voices, foreground/background timer behavior, folding, rotation, large text, VoiceOver and a normal-length session's heat/battery behavior.
4. Visual approval of screenshot cards and promotional imagery. Listing copy is prepared in nine languages; screenshot headlines are English. Smaller iPad screenshot slots may use Apple's scaling.
5. Owner confirmation of seller identity, reachable support mailbox and source-asset rights. No trademark clearance or legal certification is claimed.

No local preview server was started, and no website deployment, purchase configuration or App Store submission was performed. Concurrent marketing-site analytics changes were left untouched.
