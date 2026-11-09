# Tick & Kin for iPhone, iPad, and iPhone Duo

A native, offline SwiftUI companion Pomodoro app inspired by the web timer. The free starter set is **Mochi**, a cream desk cat, and **Pip**, a botanical apprentice. This is an independent iOS target; the web app is unchanged.

## Localized app names

The app header follows the language selected inside the app. The Home Screen/Siri display name follows iOS’s language selection for the app. Both are generated from `Localization/app-names.json`; the compiled `InfoPlist.strings` and `Localizable.strings` agree in all nine locales. The Xcode project/scheme names, bundle identifiers and saved-data keys remain internal `Banke` identifiers.

| Language | App name | Naming intent |
| --- | --- | --- |
| English | Tick & Kin | Time and close companionship |
| Japanese | ときのとも | A companion for your time; soft hiragana |
| Korean | 째깍친구 | A ticking-clock friend |
| Simplified Chinese | 伴刻 | Companionship in each moment |
| Traditional Chinese | 伴刻 | Companionship in each moment |
| Spanish | Tiempo y Compañía | Time and company |
| Brazilian Portuguese | Tempo & Companhia | Time and company |
| French | Temps Complice | Time shared with a trusted companion |
| German | Taktfreunde | Friends sharing a rhythm |

English was selected by the user; the other names adapt the warm time-and-companionship idea instead of transliterating Chinese or translating “kin” literally. Public search checks were preliminary, not name reservations or trademark clearance. Native-language editorial review remains part of the broader localization release review.

## Visual direction

The native screen now follows the web composition: a large central pixel companion on a painted platform, the original hourglass brand mark, translucent header and control dock, circular carousel arrows, and a mechanical split-flap clock. The paper texture and the two free background paintings are reused from `public/backgrounds/`; the mark is reused from `public/brand/`. The blue and warm scholarly material colors follow `src/character-theme.css`, and the buttons follow `src/timer-action.css`. Native translucent materials approximate the web glass treatment; the web refraction shader is not ported.

Mochi and Pip have new pixel-art pose sheets. Swipe horizontally or use the arrows to switch companion and palette. The main scene stays focused on the companion and clock; there is no task or intention input. Screenshots are in `Verification/`.

The clock bundles the web's Manrope Bold font under its SIL Open Font License, with no runtime download. Its blue, brown and lavender faces use the web's four gradient stops, separator ink, matte paper treatment, seam beneath the lettering, and 240/280 ms flip timing. The café and orbital palettes extend the same material recipe. After rebuilding, visually check Pip against the warm web clock, Mochi's blue face, and a premium face while paused and flipping; browser and native text/compositing can still differ slightly.

## Run

Open `Banke.xcodeproj` in **Xcode 27.1 or newer**, select the **Banke** scheme and an iPhone, iPad, or iPhone Duo simulator, and Run. Deployment target is iOS 17; Duo APIs are availability-gated to iOS 27.1. For a physical device, select your signing team and a bundle identifier you own under Signing & Capabilities. No third-party Swift packages, backend, credentials, or development server are required.

```sh
# From the repository root:
swift test --package-path ios
xcodebuild -project ios/Banke.xcodeproj -scheme Banke \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath /tmp/banke-derived CODE_SIGNING_ALLOWED=NO build
```

`Scripts/make_project.py` deterministically rebuilds the project file, copies the extracted sprites into the asset catalog, and renders the web play/pause clicks and two-strike completion bell through `make_effects.py`. Run it after adding Swift files. It uses only Python’s standard library. The checked-in project and resources can be built directly without running this script.

## Free functionality

- 25-minute focus, 5-minute short break, 15-minute long break; editable durations and Gentle / Classic / Deep / one-minute Quick try presets.
- Short and long breaks can be enabled independently. Long breaks replace the fourth short break when enabled; with long breaks off, short breaks continue after every focus session. With both off, the next phase is focus. Active/paused sessions keep their remaining time; each next session still starts explicitly.
- Pause, resume, slide-to-reset (88% threshold, accessible confirmation), break skipping, and a long break after four completed focus sessions. Each next phase starts explicitly.
- Timestamp-based timekeeping and persisted active/paused sessions. Returning late completes one session, preserves its original completion deadline, and waits for the next action. UI polling never counts time.
- The release stays centered on the timer and companion: no intention input, journal, daily statistics, or lifetime progress screen. Legacy saved intentions are ignored and dropped on the next save.
- Two permanently free companions with four original poses each: idle, focus, rest, happy. Drag-linked cylinder rotation, scene blending, tap-to-greet, floating mouth-anchored speech and speaking reactions. Outlined phrases pop in and fade away without a subtitle panel; countdown digits are larger. Reduce Motion removes spatial rotation, breathing and hinge effects.
- Opt-in local notifications, optional bundled completion chime, and keep-awake while timing. Pause/reset cancels pending reminders; a unique notification ID also cancels a stale asynchronous scheduling operation safely.
- No login, ads, analytics, runtime generation, or AI service. Optional companions use Apple in-app purchases. Local settings/current-session state use UserDefaults; the privacy manifest declares this access.

The UI, captions, notifications and purchase copy have translations for English, Japanese, Korean, Simplified Chinese, Traditional Chinese, Spanish, Brazilian Portuguese, French and German. Settings can follow the device or select a language explicitly; all languages are free. Translation and voice performance still need native-speaker release review. The web app’s branded character art and voices are not bundled. This is a Pomodoro workflow with explicit breaks, rather than the web timer’s focus → wrap-up → scolding/overtime workflow.

## Phone, pad, and Duo

Layout follows current window geometry, not device model names or `UIScreen.main`. All four orientations are supported. Narrow/resized windows use a scrollable compact scene and timer; wider windows keep the web app’s centered companion-over-dock composition with a capped content width. The header remains inside the system safe area.

On iOS 27.1, actual active `.division` reserved regions select `ArrangementView(.split)`. The system places the two regions around the fold in book and tabletop poses. Each pane scrolls independently, and the companion adapts to its allocated region height. `onHingeChange` gently changes the room’s light; it never drives timekeeping, starts a session, or grants progress. A single app-owned store survives inner/outer display transitions.

The outer screen keeps the primary timer action visible at normal text size. Unfolding reveals a wider study corner; folding preserves the selected companion, phase, and deadline. In a tabletop pose the intended interaction is a companion above and stable controls below; in a book pose they sit on opposite pages.

**Both displays simultaneously:** Apple’s documented `CameraCaptureAccessory` requires an active camera session and is intended for camera apps. We do not turn on a camera to obtain an outer-screen pet. This version follows the active display. A future Live Activity could give the timer a separate glanceable system presentation; it is not implemented here.

Apple references consulted:

- [Prepare an app for iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)
- [Adaptive layouts, reserved regions, and arrangements](https://developer.apple.com/videos/play/tech-talks/111463/)
- [Hinge changes and multi-display scene accessories](https://developer.apple.com/videos/play/tech-talks/111464/)
- [Local notification scheduling](https://developer.apple.com/documentation/usernotifications/scheduling-a-notification-locally-from-your-app)

## Assets

`Design/` contains the exact generation prompts, original sheets, extracted poses, extraction manifests, and contact sheets. The original companions, app icon, six paid companion sheets, and three paid background paintings were made with the built-in image generator. Paid characters use the free originals as style references, without the prior branded characters. The transparent sprites in `Banke/Assets.xcassets` are the runtime copies. The clicks and two-strike bell are rendered from `src/audio.js` recipes by `Scripts/make_effects.py`; no external recording is used.

The runtime sprites are the eight `*-pixel/` extractions; their source sheets and exact prompts are saved alongside the first illustrated versions. The built-in image generator redrew the original characters, and the extraction utility produced matching transparent canvases. Mochi has clean extraction flags. Pip’s happy cell has an edge-alpha flag; visual inspection of the source and extracted sprite shows the hat, sprout and boots intact. The four poses are discrete states with subtle breathing, not frame-by-frame character animation. Art and names remain production prototypes, not trademark/name clearance.

## Verification

See `Verification/README.md` for the actual checks and remaining physical-device spot checks. Automated tests cover the timer core; a successful build alone is not a claim that all hardware behavior is verified.

## Companion packs

Mochi and Pip, all timer features, and language support remain free. All nine UI language options and their matching voice languages are included without an extra charge. Traditional and Simplified Chinese share Mandarin recordings with separate written captions.

| Pack | Companions | Scene | Suggested US price |
| --- | --- | --- | --- |
| Midnight Café | Jun, the barista; Bean, the café cat | Warm café after hours | $3.99 once |
| Moonlight Academy | Luna, the scholar; Atlas, the owl | Moonlit library | $3.99 once |
| Orbital Night Shift | Nova, the astronaut; Orbit, the robot | Orbital study room | $3.99 once |
| Three-Pack Collection | All six above | All three above | $8.99 once |

Each character has idle, focus, rest, and happy poses. Each pack includes matching clock/control colors. **Meet more companions** and Settings → **Companion packs** open the storefront. Preview all four poses and the companion voice before purchasing; previews do not change the active timer or unlock selection. All eight companions appear in the main carousel and Settings selector. Unowned companions use muted artwork and lock labels; browsing them does not change the active companion or timer. Tap a locked portrait or “View pack” to open the packs menu at its matching pack. Owned companions remain directly selectable. The collection is hidden after any individual purchase to avoid overlapping charges. It includes these three packs, not future packs.

StoreKit 2 supplies localized prices and verified non-consumable entitlements. The app listens for external approval/refund updates, restores purchases explicitly, and refreshes access on foreground. Revoking the selected character returns to Mochi without resetting the timer. Existing verified StoreKit entitlements work offline; buying and restoring need the App Store. No local saved Boolean unlocks content.

### Try purchases without money

Select **BankeStoreKit** in Xcode and Run. This scheme uses `Commerce/Companions.storekit` and local test transactions; it does not charge an Apple Account. Use Xcode’s StoreKit transaction manager to clear, refund, or approve purchases while checking UI behavior. The normal **Banke** scheme uses real App Store product lookup and intentionally shows unavailable purchase buttons until products are configured there. Neither the local configuration nor StoreKitTest is bundled in a normal app archive.

```sh
xcodebuild -project ios/Banke.xcodeproj -scheme BankeStoreKit \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  -parallel-testing-enabled NO CODE_SIGNING_ALLOWED=NO test
```

`PurchaseTests/` runs against Apple’s local StoreKit service. `Tests/` remains a standalone Swift package for the timer/catalog core. See [pricing and release setup](Commerce/README.md) for product IDs, rationale, and the remaining App Store Connect work.

Distribution signing, live App Store product configuration, App Store submission, native-speaker release review, cloud sync, widgets, and Live Activities remain outside this implementation.

## Voices and localization workflow

`Localization/*.tsv`, `Localization/voice-lines.json` and `Localization/app-names.json` are the editable translation sources. Run `python3 ios/Scripts/make_localizations.py` from the repository root to rebuild the String Catalog, then `python3 ios/Scripts/make_commerce_localizations.py` to rebuild the local StoreKit copy and the unpublished App Store Connect copy draft. No language unlock product exists. Prices always follow the Apple Account storefront.

`Scripts/generate_voices.py` uses the locally installed VoxCPM2 model and original synthetic character descriptions in `Design/Voices/profiles.json`. It creates eight distinct reference voices, then offline AAC cues for each character in eight spoken language directories (Traditional Chinese aliases Mandarin). All 768 clips are bundled (12 cues × 8 companions × 8 spoken languages), about 11 MB in total. Generation is resumable; `Banke/Audio/Voices/manifest.json` records each script, duration, seed and content hash. Targeted retakes use `--characters`, `--languages`, `--only` and `--retake`; pronunciation/instruction overrides live in `Design/Voices/pronunciations.json`. A Japanese greeting was localized more simply for clear delivery, with its caption changed to match the intended script.

A fresh focus starts after its spoken 3–2–1/go cues; breaks and ordinary pause/resume start directly. An interrupted opening replays its countdown on resume. Pause/reset/backgrounding cancel unfinished starts. The last five seconds have one cue per displayed second; delayed ticks skip stale numbers. Master mute and separate voice/effect controls apply to previews too; captions remain visible while muted. Foreground completion uses the bell and phase-specific speech. Background reminders use the same bell through iOS notifications.

`Scripts/verify_voices.py` uses local Whisper to flag transcript mismatches. It is a diagnostic, not proof of native accent, acting quality or naturalness. Full countdown performances are recognized, split at word boundaries, then checked again as the actual encoded five-to-one sequence. `Scripts/repair_countdowns.py` applies documented boundary corrections only when the source WAV hashes match. All 64 encoded countdowns pass, and all 768 clips decode in the resource check. Native-speaker review remains a release check. The current four-pose artwork uses a happy speaking reaction, **not the web character-specific mouth overlays/lip sync**. See `Verification/MIGRATION.md` for the explicit parity audit and remaining checks.


Open [the offline voice audition page](Verification/voices.html) directly in a browser to listen to all 768 recordings. It reads neighboring bundled files and needs no server or network. Choose a companion and spoken language, then play any cue. Transcript differences are shown for listening review, including ordinary Japanese spelling and Chinese homophone differences.

```sh
# Standard-library resource checker; --decode also requires ffmpeg/ffprobe.
python3 ios/Scripts/verify_release_resources.py --decode
# Refresh the local audition page after generation/transcript checks.
python3 ios/Scripts/make_voice_audition.py
```

The synthesis tools require the already installed local VoxCPM2 model, MLX Audio, NumPy and SoundFile. Transcript/countdown checks use the cached faster-whisper small model and zhconv. These are development tools; none runs inside the app. Audio-session activation and player preparation run off the UI actor, while effects and speech have independent cancellation.
