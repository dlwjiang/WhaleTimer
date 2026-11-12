# Tick & Kin marketing site

A standalone Vite 8 site for `https://tick-and-kin.theory-a.com`. It has its own dependencies, lockfile, assets, and build output. It does not change the existing web timer or iOS app.

The site uses warm paper colors, the app’s actual painted rooms and companions, a working flip-clock Pomodoro timer, and locally hosted typography. A small JavaScript module runs the homepage timer and saves its session in browser local storage. Vercel Web Analytics measures page views across the site. There is no advertising, contact form backend, or remote font dependency. Navigation, FAQ disclosures, legal content, and email links work without JavaScript; the timer shows an enable-JavaScript message when scripting is disabled.

## Run or build

Use Node 20.19+ or 22.12+ (Node 24 works).

```sh
cd marketing
npm ci
npm run dev
```

No development or preview server was started during implementation. Please spot-check the home page at phone and desktop widths, the FAQ disclosures with a keyboard, the support email link, and each legal page. For the timer, choose **Timer settings → Quick try → Set timer** to check a one-minute focus/break cycle. Try pause/resume, refresh while running, returning from another tab, and Reset. Check that the clock and buttons fit comfortably on a narrow phone screen and work with keyboard focus and Reduce Motion.

```sh
npm run build
npm test
npm run preview
```

`npm run build` generates static HTML, builds with Vite, and validates the result. Publish **`marketing/dist/`**. There is no runtime Node server.

Source content lives in `src/content.mjs`, styling in `src/style.css`, and shared configuration in `site.config.mjs`. HTML is generated into the ignored `.generated/` folder. After source/content/config edits while running the development server, run `npm run generate` again or restart `npm run dev`. Do not edit generated HTML or `dist/` directly.

## Web timer

The homepage timer supports start, pause, resume, reset, explicit focus/break transitions, 15/3, 25/5, 50/10 and 1/1 presets, and custom durations (focus 1–120 minutes, break 1–60 minutes). Reset returns to a fresh focus session. Active or paused durations cannot be changed until reset. The tab title displays the remaining time. The browser version uses Mochi; companion selection, voices, notifications, and long-break settings remain native-app features.

`src/lib/timer.js` and `src/lib/flip-clock.js` are unchanged copies of the repository's existing `src/timer.js` and `src/flip-clock.js`. They are intentionally included here so this folder remains independently deployable. `src/timer.css` adapts the existing split-flap stylesheet to the marketing palette without its paper-texture dependency. When updating the original modules, review and update these copies together.

`src/pomodoro.js` adapts the engine's single countdown to alternating focus and break sessions; the original engine's grace/overtime behavior is not a Pomodoro break. `src/web-timer.js` binds the accessible controls and saves state under `tick-and-kin.web-pomodoro.v1`. Elapsed time comes from the engine's clock, not the number of interval callbacks. Refreshes and suspended tabs catch up to the current session, but never automatically start the next one. Storage failures fall back to an in-memory timer. Timer state is not sent to analytics. There is no network sync or service worker; loading or reloading the site requires a connection.

## Deployment

For a static host connected to this repository:

| Setting | Value |
| --- | --- |
| Project/root directory | `marketing` |
| Install command | `npm ci` |
| Build command | `npm run build` |
| Publish/output directory | `dist` |
| Production domain | `tick-and-kin.theory-a.com` |

If the host runs commands from the repository root, use `npm --prefix marketing ci`, `npm --prefix marketing run build`, and publish `marketing/dist` instead.

Use static directory-index routing: `/privacy/` serves `privacy/index.html`, and likewise for terms and support. **Do not add an SPA catch-all rewrite to the home page.** Configure the host to serve `404.html` with HTTP 404 for missing paths, redirect `/privacy` to `/privacy/` (and likewise for terms/support), and redirect HTTP to HTTPS. Keep staging deployments out of indexing using the host’s preview controls. Once the custom domain is attached, redirect any public deployment alias to the canonical domain if supported.

The production origin is already configured. Add the DNS record your chosen host provides; the site itself does not change DNS or provision hosting. After connecting the domain, verify each URL below responds publicly over HTTPS, including in a signed-out browser. Submit `/sitemap.xml` to search tools when ready.

## Vercel Web Analytics

`src/analytics.js` initializes `@vercel/analytics` on every page, including support, legal pages, and the 404 page. The homepage imports it alongside the timer; other pages load only the analytics entry. Vercel handles automatic page views. No custom timer events or local-storage contents are sent.

Development uses the SDK's development mode; production builds use production mode. Web Analytics has been enabled in the Vercel dashboard by the owner. Redeploy this folder after installing the SDK so Vercel can serve its analytics routes. Visit the deployed homepage and a support/legal page, then confirm those visits appear in the project's Analytics dashboard. Collection on a deployed Vercel site has not been verified locally; no preview server was started.

References: [Vercel quickstart](https://vercel.com/docs/analytics/quickstart), [SDK options](https://vercel.com/docs/analytics/package), [analytics privacy](https://vercel.com/docs/analytics/privacy-policy). The native app's no-analytics statement remains separate from website analytics.

## App Store URLs

| App Store field/use | URL |
| --- | --- |
| Marketing URL | `https://tick-and-kin.theory-a.com/` |
| Privacy Policy URL | `https://tick-and-kin.theory-a.com/privacy/` |
| Support URL | `https://tick-and-kin.theory-a.com/support/` |
| Terms of Use link | `https://tick-and-kin.theory-a.com/terms/` |
| Optional privacy choices link | `https://tick-and-kin.theory-a.com/privacy/#choices` |

Publisher: **Wei Jiang**. Support: **support@theory-a.com**. These values were provided by the owner and are centralized in `site.config.mjs`.

There is no App Store listing URL yet, so the site says “Coming soon” and does not invent a download link, App Store badge, reviews, or ratings. Set `appStoreUrl` to the real `https://apps.apple.com/...` URL and rebuild when the listing is live; the download links and structured data update together.

The privacy content follows the current native implementation: local UserDefaults storage, no accounts or app analytics, optional local notifications, and StoreKit purchases. It separately explains web-timer local storage, Vercel Web Analytics, website delivery logs, and support email. Verify that it still matches the shipping app and the selected host/email practices when deploying. The terms link Apple’s Standard EULA rather than presenting this website page as a custom replacement license. Keep the app’s own privacy link and App Store Connect privacy answers consistent; this change only creates the website.

Apple requires publicly accessible support/contact and privacy information; creating these pages alone does not constitute App Review approval. References: [App Review](https://developer.apple.com/app-store/review/), [Review Guidelines](https://developer.apple.com/app-store/review/guidelines/), [Apple Standard EULA](https://www.apple.com/legal/internet-services/itunes/dev/stdeula/), [seller identity](https://developer.apple.com/help/account/membership/program-enrollment).

## Search and answer-engine foundations

- Complete, visible content in each page’s initial HTML; real links between pages.
- Unique titles and descriptions, canonical URLs, Open Graph and Twitter metadata, and a 1200×630 social image.
- WebSite, WebPage/ContactPage, Person publisher, SoftwareApplication, WebApplication, BreadcrumbList, and FAQPage JSON-LD, using only supported product facts. The native app and free web timer are described separately. No invented ratings or unsupported offer markup.
- The FAQ’s visible answers and structured data share the same source.
- `robots.txt` and `sitemap.xml` covering the four public pages; the error page is noindexed and excluded.
- A concise `llms.txt` pointing to the official pages. This is an optional discovery aid, not a search-engine requirement or a ranking guarantee.
- Semantic headings, a skip link, keyboard focus states, reduced-motion support, responsive layouts, descriptive artwork labels, explicit image sizes, WebP artwork, and self-hosted fonts.

These are the same useful-content and technical SEO foundations Google recommends for AI search features. There is no special AI schema or guaranteed AI placement. FAQ markup also does not guarantee a FAQ rich result. Sources: [Google AI features guidance](https://developers.google.com/search/docs/appearance/ai-features), [Search Essentials](https://developers.google.com/search/docs/essentials), [Vite multi-page build documentation](https://vite.dev/guide/build.html#multi-page-app), fetched through Context7.

### Search targeting

Audience: people who use a Pomodoro timer for studying, reading, or work and appreciate cute/kawaii characters. This is not positioned as a children's timer. Lead with **cute Pomodoro timer for iPhone and iPad**. Use **cozy study timer**, **kawaii Pomodoro timer**, and **aesthetic focus timer** as related search concepts, without repeating all of them in the copy.

| Priority | Query examples | Product evidence and page coverage |
| --- | --- | --- |
| Primary | cute Pomodoro timer; cute Pomodoro timer for iPhone | Homepage title and introduction, 25/5 preset, actual companion gallery |
| First long-tail targets | cat Pomodoro timer for iPhone; cute study timer with companions | Mochi is included free; Bean is shown in the optional Midnight Café pack |
| First long-tail targets | cute Pomodoro timer without subscription; free cute Pomodoro app for iPad | Free timer and three companions; visible purchase FAQ distinguishes optional paid packs |
| Supporting targets | cozy Pomodoro timer for iPad; iPad landscape Pomodoro timer | Visible native desk-timer section and landscape support |
| Supporting targets | cute Pomodoro timer online; cat Pomodoro timer online | Working free browser timer with Mochi, custom durations, no account |
| Supporting targets | offline cute Pomodoro timer; Pomodoro timer without an account | Visible offline section and FAQ; purchases and restoration still require a connection |
| Explore after launch | kawaii study timer app; aesthetic Pomodoro app for iPhone | Artwork and native platform fit; query demand and intent need validation |

These priorities reflect product fit and a qualitative search review on November 12, 2026, not measured search volumes or keyword-difficulty scores. They are hypotheses to test, not promises of easy rankings. Broad searches such as “Pomodoro timer” and “aesthetic timer” also surface browser tools and videos; the working homepage timer now serves the browser-tool intent too. Keep native-app features distinct from the browser timer. Avoid targeting unsupported features such as app blocking, virtual-pet progression, an Android app, or AI chat.

The niche already has competitors: [Cute Pomodoro](https://apps.apple.com/us/app/cute-pomodoro/id1560743102) offers cute animations on iPhone/iPad; [Pobbo](https://getpobbo.com/) positions around a cute study buddy; [Atteno](https://www.atteno.app/) already offers offline use and one-time purchases. Our proposed angle combines illustrated companions, a free native timer, and no subscriptions. No single feature establishes an uncontested search niche.

Keep these closely related queries on the homepage initially. Do not create near-identical pages for every synonym. A later iPad desk-setup guide or companion page should add real screenshots, setup details, and original information beyond the homepage. Do not add those pages solely to repeat keywords.

After deployment and the App Store release:

1. Verify the production domain in Google Search Console, submit the sitemap, and inspect the homepage's indexing and selected canonical. Check real mobile performance and HTTP status codes on the deployed site.
2. Add the actual App Store URL. Align the listing's description and screenshots with the cute-companion/Pomodoro positioning so visitors see the same product promise.
3. Review impressions, clicks, click-through rate, and positions by query cluster (cute/kawaii/cozy, cat/companion, iPad/landscape, offline/no subscription) and country/device. Compare rolling 28-day periods once there is enough data; zero early impressions do not establish zero demand.
4. Use queries with actual impressions to choose the next substantive page or copy change. Monitor App Store acquisition separately; website search rankings and App Store search rankings are different outcomes.

## Verification and assets

`npm test` covers focus/break transitions, pause/resume/reset, long background delays, reload recovery, clock corrections, invalid saved data, duration validation, actual homepage controls in jsdom, tab titles, reduced motion, accessible announcements, and unavailable browser storage. jsdom is a development-only dependency, not part of the shipped bundle.

`npm run build` validates all five HTML documents, local links and fragments, page titles, canonical URLs, JSON-LD, image attributes, CSS asset paths, sitemap coverage, absence of placeholder content, social-image dimensions, and main-image size budgets. It checks that every page has a JavaScript entry point for analytics; the timer remains in the homepage bundle. These checks do not claim browser visual QA, deployed HTTP status verification, indexing, or App Store approval.

The WebP files are compressed copies of existing `ios/Banke/Assets.xcassets/duo-room-*` and `duo-sprite-*` images. The gallery shows all twelve companions grouped into the three included characters and the three optional packs. Each uses its matching room; the paid companions are aligned to the painted ledge, including Wisp’s narrower sprite. Full two-frame sprites are preserved; CSS shows only the idle half. The icon and touch icon reuse `public/brand/` assets. Manrope Bold is copied from the iOS font bundle; its SIL Open Font License ships beside it. All required files are inside this folder, so it can be deployed or moved independently.

`public/social.png` reuses the same artwork with a simple native composition. To recreate it on macOS from this directory, run `swift scripts/social.swift`. Swift is not required for installing, building, or deploying the site; the PNG is included with the source assets.
