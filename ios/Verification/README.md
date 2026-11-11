# Verification record

Duo refinements, 2026-11-11: removed speaking-mouth overlays, metering and mouth-only assets at the user’s request; floating text and poke reactions remain. Seated Atlas is 30% smaller; Mochi, Pebble, Bean and Maple are 26% smaller, scaled about their ledge contact point. Original platform artwork moves Pebble, Wisp and Comet down and Pip left. Fully open Duo uses the inactive physical division to retain the same scene and layout as partially folded. Visual spot check: compare partial/full opening, check the five seated sizes and the four platform placements. Simulator build and three focused native tests pass (poke response, companion/text-size changes, timer fit). Prior records below describe earlier revisions.

Layered Duo update, 2026-11-10: twelve transparent idle/poked sheets and six shared room backgrounds are bundled; Bean's paws were regenerated and inspected. Characters use the same cylinder motion as the full-page layout; rooms crossfade only when their identity changes. The timer has one fixed lower-pane position across companions, and the header and timer use native Liquid Glass where supported. The header now distinguishes the visible control row from the larger native exclusion area (observed Duo region: 144 × 82 points), using a compact 52-point bar. Tent mode places companion and timer side by side and shares the status-row header.

Validation for this update: **30 core tests**, **5 focused native tests**, a successful simulator build, and resource/decode checks for **1,248 voice clips**, **160 translation keys × 9 languages**, and all layered images. The new 96 poke responses use the existing synthetic voice identities; proposed cuter replacement identities remain staged for the user's assessment. Local transcription flags remain visible in [voices.html](voices.html), including spelling/interjection differences and recordings needing listening review. No external media service was used. Poke mouth landmarks were corrected separately for idle and surprised expressions after simulator inspection. The unified full-canvas layout was inspected in folded portrait/landscape, shallow landscape and fully open portrait on the isolated Tick Kin Duo QA simulator. It includes all safe-area edges and avoids the hinge and native controls on either side. Recorded Luna-to-Atlas frames retain the same room while the character moves; final animation smoothness and aesthetic assessment was requested from the user. Atlas sizing now prevents its source frame extending above the screen. Final build and all 30 core tests pass; five focused native tests pass. Screenshots: [folded landscape](duo-folded-landscape.png), [tabletop](duo-tabletop-final.png), [shallow landscape](duo-shallow-landscape.png), [fully open](duo-fully-open.png). See [work status](../Design/DuoLayers/work.json) and [asset provenance](../Design/DuoLayers/manifest.json). The entries below describe earlier revisions.

Environment: Xcode 27.1, iOS 27.1 SDK, Apple Swift 6.4; checked 2026-11-09. No web development or preview server was started.

User voice assessment, 2026-11-10: revise **Mochi, Pebble, Luna, Jun, Bean, Maple and Comet**; preserve **Pip, Atlas, Wisp, Nova and Orbit**. The [A/B audition page](../Design/Voices/StyleReview/compare.html) now offers a companion selector and English/Mandarin greeting, pause and resume comparisons for those seven (42 proposed clips). The earlier Atlas/Nova drafts are excluded. All bundled voices remain unchanged pending the user’s listening assessment of the proposed identities. The incomplete broader staged generation is development material only and is not in the app bundle.

Companion-name header and voice audition follow-up, 2026-11-10: the header subtitle now shows the selected companion name, with a larger readable font, updating through the shared study store. Simulator build succeeds. **All 1,152 bundled voice files remain unchanged** while the user manually identifies voices to revise. Five proposed identities (Mochi, Jun, Luna, Atlas, Nova) have 30 English/Mandarin pilot cues with local transcript diagnostics and audio-format checks; additional staged retakes are incomplete and not integrated. Compare the pilots in [the local A/B page](../Design/Voices/StyleReview/compare.html). Voice generation now detects stale references and fingerprints their actual audio; separate staging/output paths keep auditions outside the app bundle. External media review was blocked by approval review; the user chose manual assessment, and no samples were uploaded.

Duo completion follow-up, 2026-11-10: all **12 companions** now have dedicated full-width scene artwork. Added Jun, Bean, Luna, Atlas, Nova and Orbit, with measured ledge and speech anchors. Removed the tabletop upper-left name/dot panel and enlarged the timer using the lower pane width and available height. **26 core tests and 1 hosted Duo artwork/text-size test pass**, and release resource validation checks every Duo scene. Build succeeds. Sources and exact built-in generation prompts: [paid scene manifest](../Design/DuoConcepts/paid-scenes.json). Final in-app visual spot check remains with the user: run BankeStoreKit with `-preview-tabletop`, select a locally purchased character, and check the enlarged clock, ledge alignment, speech, and absence of the corner panel. Earlier screenshots below predate these changes.

Header and carousel follow-up, 2026-11-10: the Duo header shares the top row with the native status controls, with a reserved right-hand lane and occlusion avoidance. Narrow screens and accessibility text fall back below the status area. The main carousel, arrows and dots use only available companions; locked companions and pack browsing remain in Settings. Removed the main-screen pack promotion. All 26 core tests and the 2 focused Duo view tests pass; resource validation passes. Inspected the native [raised-header screenshot](duo-raised-header.png), including the three free companion dots. Installed the updated simulator build with `-preview-tabletop`.

Earlier expansion check, 2026-11-10: the catalog contained **12 companions** (3 free and 3 in each paid pack), **48 poses**, **6 Duo scenes**, **1,152 voice clips**, and **159 translation keys in 9 languages**. The expansion adds Pebble, Maple, Wisp and Comet. Existing product IDs and prices are unchanged, so pack owners receive the added companion automatically.

**24 core tests, 7 local StoreKit tests, and 15 hosted experience tests pass.** Three focused Duo tests also pass, covering the entire voice bundle and live companion/text-size changes. The Duo art fills behind the glass header and status area; its ledge bottom is registered to the fold. A native simulator screenshot was inspected for that placement. The initial fixed-delay text-size test was too tight on a busy simulator; it now waits for the running state, and passed on both iPhone and Duo. This changes test synchronization, not the app’s countdown.

All **1,152 clips pass the full resource/decode check** and match the final simulator bundle. All **96 encoded countdowns** pass recognition in order and fit their beats. The 384 added clips have current transcript hashes; two remaining automatic flags are Japanese kanji spelling and Chinese homophones. Native-speaker listening and acting review remains necessary. Open [voices.html](voices.html) directly to audition all recordings without a server. Detailed inventory, retakes and checks: [companion-expansion.json](companion-expansion.json). Artwork sources, prompts and hashes: [asset manifest](../Design/companion-expansion.json).

For a visual spot check, run **BankeStoreKit** with `-preview-tabletop`. Select Pebble for the free river scene; preview or locally purchase the packs to select Maple, Wisp and Comet. Check the top header, ledge/fold alignment, floating speech and timer controls at your preferred text size. Scenes remain static illustrations with live controls and speech.

[MIGRATION.md](MIGRATION.md) retains earlier interaction and language audits. The sections below are verification history; their counts and feature descriptions describe those earlier revisions.

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
