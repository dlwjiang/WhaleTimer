# Companion commerce

## Launch recommendation

Start at **US $3.99 per pack** and **$8.99 for the three-pack collection**, paid once. Keep Mochi, Pip, Pebble, the entire timer, and all language support free. The collection saves $2.98 against three separate purchases ($11.97), about 25%. It includes the three named launch packs only; no promise of future content.

This is a launch hypothesis, not a measured profit maximum. The closest useful public benchmark is Focus Friend’s US listing: Base Bean Pack $3.99, Jelly Bean Pack $5.99, Kitt-ney Bean $4.99, and Blue Jello Bean $2.99. Our three characters plus scenes at $3.99 fit that range, but competitors’ prices do not reveal their conversion or profit. [App Store listing, checked November 9, 2026](https://apps.apple.com/us/app/focus-friend-by-hank-green/id6742278016).

The strongest reason to buy should be wanting to spend time with a particular group of companions. A free pose preview makes that choice concrete. No timed countdown sale, mandatory subscription, focus penalties, or language paywall is included. The shared seated idle and happy expressions should be described accurately; these are not full animated characters with conversational AI.

## Find the profitable price

Optimize **net contribution per activated user over a fixed period**, accounting for the mix of single packs and collections, refunds, commission, and acquisition/support costs. Do not optimize buyer count alone. An activated user could be defined as someone who completes their first focus session. Store-view conversion is a useful diagnostic, but can increase while overall revenue declines.

With equal commission, tax treatment and costs, simple single-pack break-even arithmetic gives:

| Price compared with $3.99 | Purchase-volume change needed to match gross revenue |
| --- | --- |
| $2.99 | About 33.4% more buyers |
| $4.99 | Can lose about 20.0% of buyers |

First establish a $3.99 baseline, then test $4.99 while keeping the bundle price and product presentation stable. Test $2.99 if evidence points to price resistance. Compare equivalent acquisition sources, regions and cohorts; sequential price changes can be confounded by seasonality and marketing. Decide the sample size from the observed baseline and a minimum useful effect rather than stopping after a few sales. Measure total proceeds per activated user across *all* pack products, because the bundle changes purchase mix. Monitor refunds and continued focus use alongside proceeds.

There is currently no analytics backend or randomized pricing system. This build does not claim to measure conversion or run an A/B experiment. App Store sales reporting can establish initial sales/refund totals; activation/store-view denominators would need a deliberate measurement implementation before the above metric can be computed.

If eligible and enrolled, Apple’s Small Business Program has a 15% commission. At that rate, the simple pre-tax/refund/cost estimates are $3.39 on a $3.99 pack and $7.64 on an $8.99 collection. Eligibility/enrollment is not assumed; use actual App Store proceeds for decisions. [Apple program terms](https://developer.apple.com/app-store/small-business-program/).

## Product setup

All four are **non-consumable** in-app purchases. Runtime prices always come from `Product.displayPrice`; the local USD prices are test data only. Production prices must be configured in App Store Connect.

| Reference name | Product ID | US base price |
| --- | --- | --- |
| Midnight Café | `app.banke.companions.midnightCafe.v1` | $3.99 |
| Moonlight Academy | `app.banke.companions.moonlightAcademy.v1` | $3.99 |
| Orbital Night Shift | `app.banke.companions.orbitalNightShift.v1` | $3.99 |
| Three-Pack Collection | `app.banke.companions.collection.v1` | $8.99 |

The app checks verified transactions against these exact IDs. A bundle entitlement unlocks all three packs without synthesizing individual transactions. If any individual pack is owned, the bundle offer disappears; Apple does not automatically subtract earlier purchases from this separate collection product. A refund removes only the refunded entitlement. Any independently owned pack remains accessible.

Prices are not hard-coded in the storefront. Missing StoreKit products leave previews available and purchases disabled with a reload action. A pending purchase does not unlock content, and overlapping pending pack/collection purchases are blocked. Ask to Buy denial does not have a corresponding verified transaction update; if a request was declined, relaunch the app before requesting that pack again. No payment state is stored in UserDefaults.

## Before live sales

1. Select the Apple Developer team and the production app’s bundle identifier. Create the matching app record and these four non-consumables in App Store Connect. Complete required agreements, banking/tax setup, product localization, availability, pricing, and review assets.
2. Use the normal **Banke** scheme for signed sandbox/TestFlight testing. Verify actual localized prices, purchase sheets, cancellation, pending approval, restore after reinstall/on another device, refunds, and offline use with previously verified purchases. Local StoreKit success does not validate App Store Connect configuration or signing.
3. Check all twelve characters at real device size, iPad resizing, Duo transitions, large text and VoiceOver. Confirm the same timer deadline survives shop navigation and ownership changes. Names/art remain prototypes pending final brand review.
4. Submit the app and IAPs through App Store review. No live products, account settings, or submissions were created by this implementation.

Local testing: **BankeStoreKit** uses `Companions.storekit`; automated tests set up an `SKTestSession` and run serially. The normal **Banke** Run/Archive path contains no local commerce configuration, no test framework, and no entitlement bypass.

Implementation references: [StoreKit](https://developer.apple.com/documentation/storekit), [current entitlements](https://developer.apple.com/documentation/storekit/transaction/currententitlements), [transaction updates](https://developer.apple.com/documentation/storekit/transaction/updates), [restore synchronization](https://developer.apple.com/documentation/storekit/appstore/sync()), [local StoreKit testing](https://developer.apple.com/documentation/xcode/setting-up-storekit-testing-in-xcode).
