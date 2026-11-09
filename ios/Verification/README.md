# Verification record

Environment: Xcode 27.1, iOS 27.1 SDK, Apple Swift 6.4; checked 2026-11-09. No web development or preview server was started.

The current interaction, localization and voice work is tracked in [MIGRATION.md](MIGRATION.md). It records **19 core and 16 hosted passing tests**, the complete **768-recording** bundle, **64/64** encoded countdown checks, nine UI localizations, simulator gesture/locale checks, and an unsigned device Release build. The latest follow-up also verifies mouth-anchored floating speech and Tick & Kin branding in all nine languages (151 translation keys). Open [voices.html](voices.html) directly for offline listening review. See the audit for the remaining hardware/native-speaker checks and the one unreproduced live text-size simulator crash. The sections below retain earlier verification history; their test counts and feature descriptions describe those earlier revisions.

## Release simplification — journal removed

- Removed the book icon, journal sheet, session list, daily/lifetime statistics, and progress card. Updated reset/settings copy and product documentation.
- Removed historical session recording/storage. The current timer, optional intention, companion, settings, and four-session break-cycle count remain. Old saved state decodes without its obsolete records field, preserving the active/paused timer and cycle position.
- All **14** core/catalog tests pass, including legacy-save compatibility, exactly-once completion across relaunch, and the four-session long-break cycle. Simulator Debug build succeeds.
- No development/preview server was started. Visual spot check for the user: rebuild and Run, confirm the header now has only sound/settings beside the brand, and check the start-over explanation. Earlier screenshots below predate removal and still show the book icon.
- The StoreKit suite and device Release build results below are from the preceding companion-pack change; they were not rerun for this removal.

## Earlier automated checks

- Simulator Debug build succeeds, including compiled images, notification sound, and privacy manifest.
- Unsigned physical-device Release build succeeds. The built Info.plist contains the correct Chinese display name and both iPhone/iPad device families; signing and App Store distribution are not configured.
- Ten Swift core tests pass: deadline completion after late wake, exactly-once credit across relaunch, paused restoration, backward-clock handling, four-session long-break cycle, switching companions without changing the deadline, resetting without unearned credit, pause at the completion boundary, invalid data/settings recovery, skipped long-break cycle reset, and completion-day attribution (several assertions share tests).

## Initial functionality checks (before the visual revision)

- iPhone Duo simulator: selected Pip, started a session, unfolded, partially folded, and closed the device. The selected companion and running deadline survived.
- Paused a session, terminated and relaunched the app: restored Pip and the same paused remaining time.
- Edited session durations while paused: the existing session kept its duration. Reset applied the new one-minute preset.
- Outer-display inspection caught an off-screen primary action. Compact scene/panel spacing was corrected and rechecked; Pause and Start over fit at standard text size.

- Backgrounded a one-minute focus session with notifications authorized. The system displayed “A little progress, together” on the simulator lock screen. Opening it showed Pip’s happy pose, one completed focus session and one minute, and “Start short break.” Starting the break selected Pip’s rest pose. The journal count stayed at one through the break.
- Inspected iPhone 17 and iPad Pro 11-inch simulator rendering. Both load the bundled character and controls; iPad uses the wider two-column layout.
- Inspected Duo book and tabletop arrangements: actual folding changes the layout into side-by-side or above/below regions. Timer state persists through the change.
- Tested the largest accessibility text size on iPhone. This exposed a wrapping companion selector; buttons and secondary actions now stack vertically at accessibility sizes. Rebuilt and visually rechecked the selector. Scrolling remains available for the expanded content.
- The first project-generator build escaped the Chinese display name incorrectly. The generator now preserves Unicode; the final built Info.plist was inspected to confirm `伴刻`.

## Visual revision — web design alignment

- Restored the web hourglass mark, paper/background paintings, central companion composition, glass dock, blue/warm character palettes and split-flap clock.
- Redrew both original companions as pixel sprites; checked all eight extracted poses visually. The first scene layout clipped the characters; fixed its background sizing and re-inspected the whole character, including feet and hat.
- Simulator Debug and unsigned device Release builds pass after the revision. All ten existing timer tests pass.
- Started focus on iPhone, switched Mochi to Pip during countdown, and paused. The timer continued correctly, the companion pose changed, and the clock/control palette followed the selected character. Opened and dismissed the optional intention editor.
- Inspected the iPhone, centered iPad, and Duo tabletop compositions. Largest accessibility text stacks the two timer actions; the view requires scrolling at that size. Physical-device scrolling/VoiceOver remains part of the spot check below.
- On the Duo outer display, both actions fit at normal text size. The simulator retained its landscape app orientation after a physical rotation until relaunch; recheck live rotation on hardware. The saved outer screenshot is after relaunch, with the same companion/session restored.
- Screenshots from the visual revision: [iPhone / Mochi](iphone.png), [iPhone / Pip](iphone-pip.png), [iPad](ipad.png), [Duo tabletop](duo-tabletop.png), [Duo outer screen](duo-outer.png). They illustrate layouts, not physical-device display color or sound quality.

Native material approximates the web glass; its custom optical refraction shader is not ported. The four sprite poses are not a full frame-by-frame animation set.

## Paid companion packs

- Added six original pixel companions with 24 extracted poses, three painted scenes, and three clock/control palettes. Inspected all six contact sheets; extraction reports no empty or clipped cells.
- All **13** standalone Swift tests pass (the original ten timer tests plus catalog access boundaries, bundle overlap prevention, and paid-character persistence).
- All **7** hosted StoreKit tests pass using **BankeStoreKit** on iPhone 17 / iOS 27.0. These use Apple’s local StoreKit service, not mocked entitlement flags: localized product loading and expected USD prices; individual purchase and restore into a new store; collection access; refund with selected-character fallback and unchanged running deadline; deferred approval through transaction updates; failed/cancelled purchases; invalid verification; store/restore failures preserving existing access.
- The initial test run used the normal App Store scheme and could not exercise local purchases. Corrected the test setup to use the explicit StoreKit configuration; the full suite then passed. The normal Banke scheme remains for production product lookup, while BankeStoreKit owns the hosted test action and local purchase preview.
- Simulator Debug and unsigned physical-device Release builds succeed. AppIntents metadata extraction emits its expected no-AppIntents warning. Signing/live App Store setup remains unverified.
- On iPhone 17e, opened the shop while a timer ran, viewed $3.99 individual/$8.99 collection prices, changed the café preview to Focus, and completed the native **Xcode test purchase** sheet (explicitly no charge). Both Jun and Bean unlocked; the café card showed Owned and the collection offer disappeared. Selected Jun and returned to the timer: the same countdown continued with Jun’s focus pose and café clock colors.
- Screenshots: [storefront](companions-shop.png), [Jun while focusing](companion-jun.png). These show local test products, not published App Store listings.
- No development or preview server was used. Translations are not implemented by this change; the English interface and all future language support remain outside companion purchase gates.

Before live sales, use the production scheme with configured App Store Connect products for signed sandbox/TestFlight purchase/restore/refund and offline tests. Local StoreKit tests do not prove live storefront setup or Apple Account behavior. See [commerce setup](../Commerce/README.md).

## Physical-device spot check before release

1. Open the Xcode project, select your team, and Run on your phone/iPad/Duo. In settings choose **Quick try** and reset if a session is already in progress.
2. Enable session reminders, start focus, and lock the device. At the deadline, check the notification and optional chime. Repeat with sound disabled, and with notification permission denied. iOS Focus settings can silence delivery.
3. Fold/unfold during a running session, during pause, and while settings are open. Try book, tabletop, and outer-screen landscape. The timer must continue without a new session or duplicate break-cycle credit; faces and controls should stay out of the fold.
4. On iPad, resize the window and use split view. Try a hardware keyboard, VoiceOver, large text, and Reduce Motion. All actions must remain reachable by scrolling.
5. Listen to the short chime and inspect Mochi/Pip at actual display size. The simulator cannot establish perceived audio quality or physical hinge ergonomics.
