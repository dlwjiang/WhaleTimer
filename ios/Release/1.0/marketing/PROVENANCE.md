# Marketing asset provenance

Prepared November 12, 2026. No external publication was performed.

| File | Source / intended use |
| --- | --- |
| `app-icon-1024.png` | Exact copy of the shipping AppIcon asset. |
| `launch-header.png` | 2400×1200 brand header composed locally from native app UI and typography. |
| `social-preview.png` | 1200×630 social-link preview, same composition family. |
| `launch-square.png` | 1080×1080 square launch card. |
| `duo-desk-morning.png` | Generated promotional visualization: Mochi, oak desk, morning light and matcha. |
| `duo-desk-evening.png` | Generated promotional visualization: Luna, walnut reading desk and lamplight. Luna requires the optional Moonlight Academy pack. |

The two desk scenes were made with the native image-generation tool using the actual `screenshots/duo-tabletop/01-mochi-focus.png` and `06-luna-focus.png` as references. Brief: a slim foldable phone in an approximately 105-degree tabletop pose, upper companion scene and lower timer, faithful source art, natural materials, realistic light, no endorsement badges or added hardware branding. Morning composition places the device on the right; evening composition places it on the left. These are illustrative device mockups, not verified product photography. Screen details and hardware proportions can differ from an actual iPhone Duo.

Original generated files remain at:

- `/Users/davidjiang/.codex/generated_images/01a1bef4-202f-7771-a228-b955dc86fb16/exec-035bb29a-0dc9-407d-ba44-53569c06ee73.png`
- `/Users/davidjiang/.codex/generated_images/01a1bef4-202f-7771-a228-b955dc86fb16/exec-2bb26d24-9c2f-45bc-bacb-2359b8bf929b.png`

Native screenshots were captured by the opt-in `ReleaseExperienceTests.testReleaseScreenshots` using production SwiftUI views, real simulator window sizes and verified local StoreKit purchases. Isolated test preferences keep the user's timer untouched. They show English UI, a ready 25-minute session, and sound muted for capture. They omit system chrome because they capture the app's window. No character or control was synthesized into those captures.

The screenshot cards preserve the whole app image, scale it proportionately and add a headline on a warm paper background. `ios/Scripts/make_release_artwork.swift` reproduces the cards and headers locally; it needs no network or preview server. Premium screenshot captions explicitly identify paid content. `store-upload/en/` is the upload set; `screenshots/` is the native source set. `iap-review/` contains the real purchase-control captures and is for App Review, not customer-facing price advertising.

The package manifest records file dimensions and SHA-256 hashes. No changes were made to the app's existing character art or selected voices for this asset set.
