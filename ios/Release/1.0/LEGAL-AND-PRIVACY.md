# Legal and privacy handoff

Existing public pages are the canonical customer-facing copy: [privacy](https://tick-and-kin.theory-a.com/privacy/), [terms](https://tick-and-kin.theory-a.com/terms/), [support](https://tick-and-kin.theory-a.com/support/). All four website URLs, including the home page, returned HTTP 200 during this release pass. Publisher: Wei Jiang. Support: support@theory-a.com. The owner should verify that mailbox delivery and seller identity are correct.

The website's current content distinguishes **native app privacy** from **website analytics**. The marketing site now includes Vercel Web Analytics; this release work did not remove or modify that separate in-progress website implementation. Native Swift sources contain no analytics SDK, app account, remote voice generation, advertising identifier access, microphone capture or developer-operated network API. Links open external web pages.

## App Store privacy answers for this build

Proposed native-app label: **Data Not Collected**. The current session, settings and companion choice stay in UserDefaults. StoreKit handles purchases; no receipts or transaction records are sent to a developer backend. No tracking is performed. The privacy manifest declares UserDefaults with reason CA92.1, no collected data and no tracking.

This conclusion covers the inspected native build. Revisit it if analytics, a support form, crash-reporting SDK, remote generation or receipt backend is added. Support emails supplied voluntarily are explained by the policy; evaluate Apple's optional-disclosure criteria if your support workflow changes. Apple's own independent data handling is separate. [Apple privacy definitions and on-device guidance](https://developer.apple.com/app-store/app-privacy-details/).

## License, refunds and content rights

Use **Apple's Standard EULA**, already linked in the website terms, unless you deliberately adopt a reviewed custom license. No additional app account terms or subscription cancellation policy is needed for this product. Apple processes purchases and eligible refund requests; the website preserves statutory consumer rights. [Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/).

The native app includes Manrope Bold and its SIL Open Font License in `Banke/Fonts/OFL-Manrope.txt`. It ships prepared audio, not voice-model weights. The selected voice pipeline's Qwen3-TTS VoiceDesign model card and VoxCPM repository identify Apache-2.0 licensing; these sources do not establish rights to arbitrary third-party reference recordings. Preserve the existing synthetic audition/reference provenance and owner-approved route exports. No new voices were generated or replaced in this release pass. [Qwen model](https://huggingface.co/Qwen/Qwen3-TTS-12Hz-1.7B-VoiceDesign), [VoxCPM](https://github.com/OpenBMB/VoxCPM).

Characters are the original Tick & Kin companions, not ChatGPT, Claude or DeepSeek mascots. The artwork provenance is retained under `ios/Design`, including `DuoLayers/manifest.json`. Final rights confirmation should cover any externally supplied source image or recording and the image-service terms applicable when it was generated. Repository provenance is evidence of the production process, not a trademark search or legal clearance certificate. Nothing in this package claims exclusive ownership of AI-generated visual elements.

For export compliance, `ITSAppUsesNonExemptEncryption` is false: the inspected app uses Apple system services and does not implement or bundle non-exempt cryptography. Answer any territory-specific follow-up questions in App Store Connect consistently with the actual build. [Apple encryption guidance](https://developer.apple.com/help/app-store-connect/manage-app-information/determine-and-upload-app-encryption-documentation/).

## Public promotional language

Keep paid characters labeled as optional paid content, as in the Luna screenshot card. Do not promise future packs in the collection, lifetime service availability, therapeutic benefits, improved grades, app blocking, AI conversation, or guaranteed productivity gains. No subscription is accurate for the current one-time products.

For the generated desk images, use a caption such as **“Promotional visualization of Tick & Kin in tabletop mode.”** They illustrate the feature but do not certify physical hardware dimensions, camera placement or exact screen pixels. They belong on the website/social press materials, not in the real-screenshot folders. Do not use an Apple endorsement badge or imply the app has already been featured. [Apple marketing guidelines](https://developer.apple.com/app-store/marketing/guidelines/).
