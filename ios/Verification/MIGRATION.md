# Web → iOS release parity audit

Checked November 9, 2026. Scope: the existing native Pomodoro focus/short-break/long-break workflow, explicitly confirmed by the user, with the web app's interactions and audio. The journal is removed. Languages and voice-language support are free for every owned companion.

## What migrated

| Web experience | Native implementation and evidence |
| --- | --- |
| Drag-linked character rotation, scene blend, arrows, cancel/snap | `CompanionScene` uses the web's 120° orbit, 54° portrait turn and 280 ms settling. iPhone 17e checks confirmed swipe/wrap, short-drag cancellation without greeting, and tap-to-greet. Core tests cover direction, thresholds, vertical-scroll rejection and flicks. Reduce Motion replaces spatial movement with a fade. |
| Slide to start over | `SlideToReset` accepts a handle drag released past 88%; aborted drags return. A partial iPhone drag preserved paused 19:45; a full drag reset to ready 25:00. VoiceOver and keyboard have a confirmation equivalent. |
| Weighted play/pause clicks and two-strike bell | `make_effects.py` renders the original `src/audio.js` recipes as bundled PCM. Master mute and separate voice/effect controls also apply to previews. Notifications use the same bell. |
| Voices and countdowns | 768 offline AAC recordings: 12 cues × 8 original companions × 8 spoken languages. Opening 3–2–1/go holds the full focus duration until finished. An interrupted opening replays on resume; ordinary pause/resume and breaks start directly. Last-five-second cues skip stale numbers after delayed ticks. Pause, resume, reset, greeting and both completion cues are localized. |
| Playback and cancellation | Speech and effects use independent channels. Audio-session activation and player preparation run off the UI actor. Generation tokens prevent cancelled/queued sounds from reappearing. Hosted tests exercise actual recorded playback, concurrent effects, cancellation and bundle lookup. Caption-only mute and localized device-speech fallback are implemented. |
| Captions and companion reactions | Speech now floats beside each pose’s mouth as cream-outlined, themed lettering, with a spring entrance, larger countdown numbers and a short upward fade. It moves in the same transformed space as the avatar during swipes and disappears without leaving a subtitle panel. Layout measures wrapping text before clamping it to the scene; accessibility sizes can use the full width. Reduce Motion uses a fade. Captions remain associated with their original speaker across selection changes. Native artwork uses four poses and breathing, with a happy speaking reaction. **The web's character-specific mouth overlays and amplitude-driven lip sync are not ported.** |
| Web visual direction | Hourglass mark, paper texture, painted scenes, themed controls, glass dock and mechanical flip digits are retained. Native materials approximate the glass appearance; the custom web refraction shader is not ported. |
| Timer/settings persistence | Timestamp-based sessions, editable durations, optional intention and four-focus long-break cycle remain. Language/companion changes preserve a running deadline. Interrupted opening state restores paused. Old mute settings and saves containing obsolete journal fields migrate. |
| Localization | 150 keys × 9 written locales cover UI, captions, notifications, accessibility and purchase copy. Four StoreKit products have all nine localizations and an unpublished App Store Connect copy draft. No language purchase exists. |

Written locales: English, Japanese, Korean, Simplified Chinese, Traditional Chinese, Spanish, Brazilian Portuguese, French and German. Both Chinese writing systems use Mandarin recordings. Original synthetic voice profiles do not use real-person reference recordings or the web's branded voices.

The web's extra-time/repeating overtime-warning workflow is intentionally excluded in favor of the requested Pomodoro breaks. Developer asset/glass-tuning tools are not release screens. Voice previews are available in Settings and the pack storefront.

## Verification

- **19 core tests passed**, covering timer lifecycle, exactly-once completion, legacy storage, locale resolution, carousel/reset geometry and opening-countdown preparation. Log: `/tmp/banke-core-final.log`.
- **16 hosted tests passed without skips**: seven StoreKit cases and nine release-experience cases, including real audio playback, the complete bundled library, all compiled localizations, cancellation and rapid Dynamic Type changes across completion. Log: `/tmp/banke-hosted-complete.log`.
- **Unsigned physical-device Release build succeeded** with the production Banke scheme and complete audio bundle. Log: `/tmp/banke-device-release-final.log`. This is not a signed archive or TestFlight deployment.
- **768/768 recordings pass the strict resource/decode check**, including AAC format, mono 24 kHz, file sizes and duration limits. All source scripts and cached transcript hashes match the actual bundled files. Log: `/tmp/banke-resources-complete.log`.
- **64/64 encoded five-to-one countdowns pass local recognition**, with no missing or flagged sequence. Digits fit below 0.9 seconds. Log: `/tmp/banke-countdowns-complete.log`; detailed results: `encoded-countdowns.json`.
- Source performances, deterministic retakes and four source-hash-bound split corrections are recorded in `Design/Voices/`, `voice-retakes.json` and `voice-transcripts.json`. These are machine diagnostics, not native-speaker approval. Atlas's Japanese greeting was simplified to `ここで、ゆっくり学ぼう。` after repeated unclear takes; the caption and intended recording now agree.
- Open [voices.html](voices.html) directly to audition all recordings without a server. The page shows script/transcript differences for listening review. Some differences are spelling/homophones or expressive interjections; the raw diagnostics remain available.
- Earlier Google media-perception reports cover representative greetings and flagged lines. They are model observations, not human review. A later upload was rejected by automatic approval review for lack of explicit authorization; no retry/alternate upload occurred, and subsequent checks stayed local.
- No web development or preview server was started.

## Simulator interaction checks and limitations

On iPhone 17e, the carousel and reset gestures above were exercised, along with live English, German and Traditional Chinese changes. German main controls fit and the settings title updates immediately.

On iPad Pro 11-inch, French settings/timer controls fit at normal text size. A running one-minute focus survived portrait-to-landscape rotation, completed with one cycle credit, then its short break started directly and completed. The next focus replayed the opening countdown and completed with two credits. These UI checks used muted captions; the separate hosted playback test exercises audio APIs.

Maximum accessibility text stacks the controls. One rapid Xcode text-size override change near focus completion caused a simulator crash: `precondition failure: setting value during update`, with `ObservationTracking._AccessList.addAccess` and SwiftUI scroll-environment frames. Restarting, jumping directly to maximum size, and repeating the rapid transition during another focus succeeded. The hosted regression also passed while preserving the deadline and one completion credit. **The original one-off crash is not claimed fixed.** Recheck live text-size changes and access to all controls by scrolling on the release device/OS.

Earlier Duo fold/unfold and persistence checks are recorded in [README.md](README.md); they predate the final voice integration. They do not establish physical hinge ergonomics or the new audio behavior through every display transition.

## User spot checks before shipping

1. Open `Banke.xcodeproj`, choose your signing team, and Run on a phone. Select **Quick try**, reset, and check the opening, pause/resume, reset, last-five-second cues and focus → break → focus flow. Listen through both speaker and headphones; check mute, silent switch and interruptions.
2. Enable reminders, start a focus and lock the device. Check deadline notification/chime, then repeat with sound disabled and permission denied. Confirm returning to the app grants only one completion credit.
3. Use the offline audition page with native speakers for all eight spoken languages; review UI wording in all nine written locales. Retain the same character identity while judging clarity, accent and acting.
4. Exercise large text, VoiceOver, external keyboard, Reduce Motion, iPad resizing and Duo transitions. All actions must remain reachable; selection, phase and deadline must survive layout changes.
5. Configure App Store Connect products and use signed sandbox/TestFlight builds for live-store purchase/restore/refund checks. Local StoreKit results do not validate published product configuration.


### Floating speech follow-up — November 9, 2026

Replaced the persistent subtitle/name panel with mouth-anchored speech matching the web direction. All 16 existing hosted tests pass with the change (`/tmp/banke-floating-speech-tests.log`; `Test-BankeStoreKit-2026.11.09_22-03-29-+0800.xcresult`). Resource validation still reports 150 keys × 9 locales and 768 clips. The earlier device Release build above predates this visual follow-up. No development/preview server was started. User visual spot check: tap both free companions, watch the opening/end countdown, swipe while a phrase is visible, and inspect a long French/German line at large text size. Verify the text stays near the speaking face, wraps inside the scene and fully disappears.

The initial localized brand rename was held pending a new name choice. Focus Friends was withdrawn after finding the direct competitor [Focus Friend](https://apps.apple.com/us/app/focus-friend-by-hank-green/id6742278016). Little Company also has existing App Store names; Quiet Company is used by a companion app. The subsequent approved Tick & Kin localization is recorded below.


### Localized Tick & Kin branding — November 9, 2026

Applied the user-selected English name **Tick & Kin** and natural localized titles in all nine written locales; the complete mapping and naming intent are in [the app README](../README.md#localized-app-names). `Localization/app-names.json` generates both the in-app `app.name` and `InfoPlist.xcstrings` names. The header follows the in-app language preference and wraps longer names; the Home Screen/Siri name follows iOS's app-language selection. Notification guidance no longer hardcodes the Chinese name.

All 16 hosted tests passed, including a new assertion in the existing localization test that each compiled in-app title matches both localized bundle-name keys. The unsigned device Release build passed; inspection verified all nine compiled device `InfoPlist.strings` files and the English fallback name. Resource validation passes with 151 translation keys, nine languages and all 768 recordings. Logs: `/tmp/banke-localized-brand-tests.log`, `/tmp/banke-localized-brand-release.log`. These results supersede the earlier build for the floating-speech follow-up. No development/preview server was started. User visual check: switch app languages and inspect the header at normal and large text sizes; check the icon label after selecting the language through iOS.
