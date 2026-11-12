# App Store Connect handoff — November 12, 2026

[Open version 1.0](https://appstoreconnect.apple.com/apps/6833866597/distribution/ios/version/inflight)

**Saved as Prepare for Submission. Nothing was added or submitted for review. Manual release is selected.**

## Completed

- Attached processed version 1.0, build 1. Bundle ID `app.banke.timer`; Apple ID `6833866597`.
- Saved names, subtitles, descriptions, promotional text, keywords, support and marketing URLs in all nine supported languages.
- Saved the owner-supplied review contact, review instructions and copyright. Sign-in is not required.
- Selected Productivity as primary category and Utilities as secondary. Age questionnaire calculated 4+, without a Made for Kids designation.
- Uploaded four English screenshots each for iPhone medium, iPhone large, iPad 13-inch and iPhone Duo. Duo includes outer portrait, tabletop portrait, inner landscape and Luna tabletop. These assets inherit into other localizations; screenshot UI and artwork copy are English.
- Uploaded English header and search artwork. Local copies: `marketing/app-store-header.png` (3840×1646) and `marketing/app-store-search.png` (3840×2560), opaque RGB PNGs composed from the real app capture.
- Set the app price to free, based in the United States. Price schedules do not enable geographic availability.
- Configured all four non-consumable purchases with nine localized names/descriptions, review notes, review screenshots and prices. Family Sharing remains off. Tax category inherits App Store software from the app.
- Saved privacy-policy URLs for all nine locales and drafted Data Not Collected, consistent with the inspected native build. Final publication remains an owner action below.
- Retained Apple's Standard EULA and public distribution. Disabled default Mac and Vision Pro availability for this iPhone/iPad launch; those platforms have not been validated.

Reload checks confirmed the localized app names/subtitles, screenshot and creative-asset counts, attached build, manual release selection, and purchase review images on Apple's servers. The initial review-image upload error was resolved. The saved review images show purchase controls; smaller JPEG copies remain in `iap-review/`.

## Owner actions before submission

1. **[Business](https://appstoreconnect.apple.com/business): sign the Paid Apps Agreement.** Status is New; Free Apps Agreement is Active. Complete the bank account and tax forms requested after signing, including accurate payee identity and any verification. Banking/tax completion could not be verified before the paid agreement is accepted.
2. **Business: complete Digital Services Act compliance.** The account shows Complete Compliance Requirements. Choose the truthful trader status and finish contact/document verification. Private App Review contact details do not replace the public trader requirements.
3. **[App Information](https://appstoreconnect.apple.com/apps/6833866597/distribution/info): complete Content Rights.** Check `LEGAL-AND-PRIVACY.md`, source-art and synthetic-audio provenance, and applicable licenses. Automatic approval review blocked making this legal declaration for the owner.
4. **[App Privacy](https://appstoreconnect.apple.com/apps/6833866597/distribution/privacy): review and Publish the prepared privacy responses.** The final confirmation agrees the responses comply with applicable law and Apple's guidelines. Publishing this label is separate from submitting or releasing the app.
5. **Launch countries configured November 13, 2026.** At the owner's request, saved a focused 29-market launch for the app and all four purchases, based on supported languages and excluding mainland China. Automatic availability in future countries is off. Reload checks confirmed the app shows 29 available / 146 not available and every purchase shows 29 selected. This configures availability only; nothing was submitted or released. EU trader verification and other applicable account requirements still apply.
6. **Do a final TestFlight purchase/restore check after the real products and agreements are ready.** Confirm the support mailbox receives mail. Local StoreKit tests do not replace checking the uploaded, signed build against Apple's sandbox.
7. **When satisfied, submit the app and its four first purchases together.** Nothing has been added for review. After approval, manual release still requires a release action.

## Purchase records

### Launch countries saved November 13

- Americas: United States, Canada, Argentina, Brazil, Chile, Colombia, Costa Rica, Mexico, Panama, Peru, Uruguay.
- Europe: Austria, Belgium, France, Germany, Ireland, Luxembourg, Portugal, Spain, Switzerland, United Kingdom.
- Asia and Pacific: Australia, Hong Kong, Japan, South Korea, Macau, New Zealand, Singapore, Taiwan.

This is a focused launch selection, not a legal clearance for these markets or a finding that every excluded market requires extra filings. Brazil is included for the Brazilian Portuguese audience; Apple's regional tax/withholding adjustments may affect proceeds. Mainland China is explicitly excluded to avoid its additional filing requirements. Existing app and purchase prices were unchanged.

| Product | Product ID | US base price | App Store Connect |
| --- | --- | --- | --- |
| Midnight Café | `app.banke.companions.midnightCafe.v1` | $3.99 | [6833879222](https://appstoreconnect.apple.com/apps/6833866597/distribution/iaps/6833879222) |
| Moonlight Academy | `app.banke.companions.moonlightAcademy.v1` | $3.99 | [6833882690](https://appstoreconnect.apple.com/apps/6833866597/distribution/iaps/6833882690) |
| Orbital Night Shift | `app.banke.companions.orbitalNightShift.v1` | $3.99 | [6833883889](https://appstoreconnect.apple.com/apps/6833866597/distribution/iaps/6833883889) |
| Three-Pack Collection | `app.banke.companions.collection.v1` | $8.99 | [6833884541](https://appstoreconnect.apple.com/apps/6833866597/distribution/iaps/6833884541) |

Apple's regional price equivalents were accepted. The collection includes the nine companions from these three launch packs only, not future packs. No subscriptions were created.

## Naming and marketing notes

Apple rejected Simplified Chinese `伴刻` as already taken. The saved store title is **伴刻：可爱伙伴番茄钟**. The native app name is unchanged. Traditional Chinese remains `伴刻`; all other localized titles were accepted.

Generated half-folded desk images remain website/social promotional visualizations, not App Store screenshots. No featuring nomination was submitted. No optional app-preview videos, in-app events, custom product pages, or unverified accessibility badges were added.

The owner's signing changes in `ios/Banke.xcodeproj/project.pbxproj` were not altered by this metadata work.
