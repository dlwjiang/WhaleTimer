import { site } from '../site.config.mjs';
export const escape = (value) => String(value).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const email = `<a href="mailto:${escape(site.supportEmail)}">${escape(site.supportEmail)}</a>`;
export const faqs = [
  ['Is the Pomodoro timer free, or do I need a subscription?', 'The timer, all languages, and Mochi, Pip, and Pebble are free. Additional companion packs are one-time purchases. There are no subscriptions.'],
  ['Can I use the timer in my browser?', 'Yes. The timer on this page is free to use with Mochi. Choose a preset or custom durations, then start focusing. Your session is saved in this browser so you can refresh and continue. Each focus session and break starts when you choose.'],
  ['Can I use it as a Pomodoro timer?', 'Yes. Choose the Classic preset for 25 minutes of focus and a 5-minute break, or customize your durations. The iPhone and iPad app also lets you enable short and long breaks separately.'],
  ['Does Tick & Kin work offline?', 'The iPhone and iPad app’s timer, artwork, and audio work offline. Buying or restoring companion packs requires an internet connection. The web timer needs a connection to load the page; once loaded, its countdown runs locally.'],
  ['Do I need an account?', 'No. Your settings and current timer are saved on your device. The iPhone and iPad app has no ads or analytics. This website uses Vercel Web Analytics to measure visits.'],
  ['Are the companions AI chatbots?', 'No. Tap a companion to see a reaction and hear a recorded greeting. They do not hold conversations or listen to you.'],
  ['Which languages are supported?', 'English, Japanese, Korean, Simplified Chinese, Traditional Chinese, Spanish, Brazilian Portuguese, French, and German. All language options are included for free. Traditional and Simplified Chinese share Mandarin voice recordings.'],
];
export const faqHTML = () => faqs.map(([q, a]) => `<details><summary>${escape(q)}<span aria-hidden="true">+</span></summary><p>${escape(a)}</p></details>`).join('');
const sprite = (name, loading = 'lazy') => `<span class="sprite"><img src="/art/${name}.webp" alt="" width="1200" height="400" loading="${loading}"></span>`;
// Existing app artwork, grouped exactly as the StoreKit companion packs.
export const companionPacks = [
  { id: 'midnight-cafe', name: 'Midnight Café', room: 'cafe', ledge: 0.720, companions: [
    { id: 'jun', name: 'Jun', role: 'Barista', seat: 0.6871, center: 0.5373, top: 0.0331 },
    { id: 'bean', name: 'Bean', role: 'Café cat', seat: 0.8737, center: 0.4848, top: 0.0511 },
    { id: 'maple', name: 'Maple', role: 'Red-panda baker', seat: 0.7652, center: 0.4595, top: 0.0152 },
  ] },
  { id: 'moonlight-academy', name: 'Moonlight Academy', room: 'academy', ledge: 0.708, companions: [
    { id: 'luna', name: 'Luna', role: 'Star-atlas scholar', seat: 0.7, center: 0.5134, top: 0.0276 },
    { id: 'atlas', name: 'Atlas', role: 'Library owl', seat: 0.93, center: 0.4793, top: 0.0262 },
    { id: 'wisp', name: 'Wisp', role: 'Moth librarian', seat: 0.7133, center: 0.5215, top: 0.1104, aspect: 0.75 },
  ] },
  { id: 'orbital-night-shift', name: 'Orbital Night Shift', room: 'orbit', ledge: 0.700, companions: [
    { id: 'nova', name: 'Nova', role: 'Orbital study partner', seat: 0.7192, center: 0.5562, top: 0.0249 },
    { id: 'orbit', name: 'Orbit', role: 'Mission robot', seat: 0.7369, center: 0.5028, top: 0.0304 },
    { id: 'comet', name: 'Comet', role: 'Space courier', seat: 0.7342, center: 0.4995, top: 0.0345 },
  ] },
];
function packCard(companion, pack) {
  // Uniform scaling keeps each seated body on the painted ledge. Wisp has a
  // narrower source cell; using the other sheets' aspect would stretch its wings.
  const aspect = companion.aspect ?? 1.5;
  const height = Math.min(0.62, (pack.ledge / 1.5 - 0.04) / (companion.seat - companion.top));
  const width = height * aspect;
  const left = 0.5 - companion.center * width;
  const top = (pack.ledge / 1.5 - companion.seat * height) * 1.4;
  const style = `--sprite-width:${(width * 100).toFixed(3)}%;--sprite-left:${(left * 100).toFixed(3)}%;--sprite-top:${(top * 100).toFixed(3)}%;--sprite-aspect:${aspect}`;
  return `<article class="companion-card"><div class="companion-art pack-art" style="${style}" role="img" aria-label="${companion.name}, ${companion.role.toLowerCase()}, seated in ${pack.name}"><img class="room" src="/art/${pack.room}.webp" alt="" width="900" height="600" loading="lazy"><span class="sprite"><img src="/art/${companion.id}-sprite.webp" alt="" width="1000" height="${companion.id === 'wisp' ? '667' : '333'}" loading="lazy"></span></div><div class="companion-info"><h4>${companion.name}</h4><p>${companion.role}</p></div></article>`;
}
const cta = () => site.appStoreUrl ? `<a class="button" href="${escape(site.appStoreUrl)}">Download on the App Store <span aria-hidden="true">↗</span></a>` : '<a class="button" href="#companions">Meet your companions <span aria-hidden="true">↗</span></a>';
const section = (id, title, content) => `<section id="${id}"><h2>${title}</h2>${content}</section>`;

export function home() {
  return `<section class="hero wrap" aria-labelledby="hero-heading">
    <div class="hero-copy">
      <h1 id="hero-heading">Make time.<br>Find your <em>kin.</em></h1>
      <p class="hero-lede">A cute Pomodoro timer for iPhone and iPad, with illustrated companions to keep you company while you study, read, or work.</p>
      <div class="hero-actions">${cta()}<a class="text-link" href="#timer">Try the timer <span aria-hidden="true">↓</span></a></div>
      ${site.appStoreUrl ? '' : '<p class="availability">Coming soon to the App Store.</p>'}
    </div>
    <section id="timer" class="hero-figure" data-web-timer aria-label="Pomodoro timer with Mochi">
    <div class="hero-scene"><div class="timer-art" role="img" aria-label="Mochi, a scarf-wearing cat, sits on a sunny windowsill.">
      <img class="room" src="/art/window.webp" width="1400" height="933" alt="" fetchpriority="high">
      ${sprite('mochi', 'eager')}
      </div><div class="preview-clock"><div class="clock-label"><span data-timer-phase>Focus</span><span data-timer-status>Ready</span></div>
        <div id="timer-display" data-timer-display role="timer" aria-label="Time remaining" aria-live="off"><span class="sr-only">25:00</span><div class="digits" aria-hidden="true"><span>2</span><span>5</span><b>:</b><span>0</span><span>0</span></div></div>
        <div class="timer-actions"><button type="button" data-timer-toggle disabled>Start focusing</button><button type="button" data-timer-reset disabled>Reset</button></div>
      </div>
    </div><p class="sr-only" role="status" data-timer-announcement></p>
    <details class="timer-settings" data-timer-settings hidden><summary>Timer settings</summary>
      <form><fieldset><legend class="sr-only">Focus and break durations</legend>
        <label class="timer-preset">Preset<select name="preset"><option value="gentle">Gentle · 15 / 3</option><option value="classic" selected>Classic · 25 / 5</option><option value="deep">Deep · 50 / 10</option><option value="quick">Quick try · 1 / 1</option><option value="custom">Custom</option></select></label>
        <label>Focus (minutes)<input name="focus" type="number" min="1" max="120" step="1" value="25" required></label>
        <label>Break (minutes)<input name="break" type="number" min="1" max="60" step="1" value="5" required></label>
        <button class="button" type="submit">Set timer</button>
      </fieldset><p class="timer-settings-hint">Reset an active timer to change its durations.</p><p role="alert" data-timer-error></p></form>
    </details>
    <noscript><p class="timer-noscript">Enable JavaScript to use the timer.</p></noscript></section>
  </section>
  <section id="how-it-works" class="ritual wrap section-space"><div class="section-intro"><h2>Focus, then<br><em>take a break.</em></h2></div>
    <ol class="steps"><li><span class="step-number">01</span><div><h3>Set your timer</h3><p>Choose 15, 25, or 50 minutes of focus, or set your own duration and break length.</p></div></li><li><span class="step-number">02</span><div><h3>Choose a companion</h3><p>In the app, choose a companion and tap to say hello. Voice cues and sound effects are optional.</p></div></li><li><span class="step-number">03</span><div><h3>Take a break</h3><p>Pause whenever you need to. The next session waits for you to start it.</p></div></li></ol>
  </section>
  <section id="companions" class="companions section-space"><div class="wrap"><div class="section-heading"><h2>Meet your <em>companions.</em></h2><p>All three free in the app.</p></div>
    <div class="companion-grid">${[
      ['mochi', 'window', 'Mochi', 'A cat by the window'],
      ['pip', 'study', 'Pip', 'A botanist in the study'],
      ['pebble', 'river', 'Pebble', 'An otter by the river'],
    ].map(([id, room, name, role]) => `<article class="companion-card"><div class="companion-art ${id}" role="img" aria-label="${name}, ${role.toLowerCase()}"><img class="room" src="/art/${room}.webp" alt="" width="900" height="600" loading="lazy">${sprite(id)}</div><div class="companion-info"><h3>${name}</h3><p>${role}</p></div></article>`).join('')}</div>
    <div class="pack-collection"><div class="section-heading"><h2>Companion packs</h2><p>Optional one-time purchases.</p></div>
      ${companionPacks.map((pack) => `<section class="companion-pack" aria-labelledby="${pack.id}"><h3 id="${pack.id}">${pack.name}</h3><div class="companion-grid">${pack.companions.map((companion) => packCard(companion, pack)).join('')}</div></section>`).join('')}
    </div>
  </div></section>
  <section class="details-section wrap section-space" aria-label="App features"><div class="detail-grid"><article><h3>An iPad desk timer</h3><p>Turn your iPad sideways for a landscape flip clock beside your work. iPhone supports portrait and landscape, too.</p></article><article><h3>Nine languages</h3><p>Choose your language for the interface, voice cues, and captions.</p></article><article><h3>Works offline</h3><p>Use the app’s timer without an account or connection. Your settings stay on your device.</p><a class="text-link" href="/privacy/">Privacy policy ↗</a></article></div></section>
  <section id="questions" class="faq-section wrap section-space"><div class="section-intro"><h2>Questions</h2><p><a class="text-link" href="/support/">Contact support ↗</a></p></div><div class="faq-list">${faqHTML()}</div></section>`;
}

export function privacy() {
  return `<div class="summary-box"><h2>How your data is handled</h2><ul><li>Your timer and settings are stored locally.</li><li>We do not receive your focus sessions or sell your personal information.</li><li>Apple processes optional in-app purchases.</li><li>This website uses Vercel Web Analytics to measure visits.</li><li>If you email us, we receive what you choose to send.</li></ul></div>
  ${section('scope', '1. Who this policy covers', `<p>This policy describes the Tick & Kin iPhone and iPad app and this marketing website, operated by ${escape(site.publisher)} (“we”, “us”). For privacy questions, contact ${email}.</p>`)}
  ${section('app-data', '2. Information in the app', '<p>The app stores preferences, your selected companion, and your current timer/session state on your device using local app storage. It uses this information to remember your choices and resume your timer. We do not operate an account or cloud-sync service, and this information is not sent to our servers.</p><p>The app does not include advertising, tracking, or third-party analytics SDKs. It does not request access to your contacts, location, camera, or microphone. Prepared voice recordings play on your device; the app does not record your speech or provide an online AI chat service.</p>')}
  ${section('apple', '3. Apple purchases and device services', '<p>Optional companion purchases and purchase restoration are handled by Apple through the App Store. The app checks Apple-provided purchase entitlements to unlock your companions. We do not receive your payment card details. Apple handles purchase information under its own <a href="https://www.apple.com/legal/privacy/">privacy policy</a>.</p><p>If you enable session reminders, the app asks for notification permission and schedules local notifications. You can change permission in your device’s Settings. Device backups and any diagnostic information you choose to share with Apple are controlled by your Apple and device settings.</p>')}
  ${section('website', '4. Visiting this website', '<p>This website uses Vercel Web Analytics to understand traffic, including pages visited, referrers, approximate location, and browser and device information. Vercel processes these visits into aggregate statistics without third-party cookies or identifiers that track visitors across websites. We do not send timer settings or session data as analytics events. See <a href="https://vercel.com/docs/analytics/privacy-policy">Vercel’s analytics privacy information</a>.</p><p>The website does not require an account. Fonts and artwork are served with the website rather than from third-party font or image services.</p><p>If you use the web timer, its durations and current session are saved in your browser’s local storage so they can resume after a refresh. This information is not sent to us or synced with the iPhone or iPad app. Clear this site’s data in your browser to remove it. The timer still works if local storage is unavailable, but cannot remember the session after a refresh.</p><p>When you visit, the hosting service necessarily receives connection information such as your IP address, requested URL, browser information, and request time to deliver and protect the site. Its operational logs may retain this information. This differs from data generated inside the app, which we do not receive.</p><p>Links to Apple and other external sites are governed by those sites’ own policies.</p>')}
  ${section('support', '5. Contacting support', '<p>If you contact us, we receive your email address, message, and any attachments or technical details you send. We use them to respond, troubleshoot, and handle your request. Please do not send passwords, payment card details, or information you do not want to share.</p><p>Support correspondence is processed through our email provider and retained only as long as needed to address the request and meet applicable recordkeeping requirements. Hosting and email providers may process information in countries other than your own.</p>')}
  ${section('choices', '6. Retention, deletion, and your choices', `<p>Local app data remains on your device until it is changed or removed. Deleting the app using iOS or iPadOS removes its local app container; offloading the app can preserve its data. Backups may retain earlier copies according to your device settings. Removing the app does not cancel or erase Apple’s purchase records.</p><p>There is no Tick & Kin account to delete. For access, correction, or deletion requests concerning support correspondence, email ${email}. Depending on your location, you may have additional rights to restrict or object to processing, receive a copy of your data, or complain to a local data protection authority. We respond as required by applicable law.</p><p>Where applicable, we process support and operational information to respond to requests, keep the website working securely, and meet legal obligations. We do not sell personal information or share it for cross-context behavioral advertising.</p>`)}
  ${section('children', '7. Children and privacy', `<p>The app does not ask users to submit personal information. If you believe a child has provided personal information to us through support, contact ${email} so we can address it, including deleting it where appropriate.</p>`)}
  ${section('changes', '8. Changes to this policy', '<p>If our data practices change, we will update this page and its effective date. Material changes will be communicated as required by applicable law. The practices described here apply to the current app and website.</p>')}`;
}

export function terms() {
  return `  ${section('provider', '1. Provider and scope', `<p>Tick & Kin and this website are provided by ${escape(site.publisher)}. Contact ${email} with questions about these terms.</p><p>These terms describe the website and our product-specific practices. The app’s license is governed by <a href="https://www.apple.com/legal/internet-services/itunes/dev/stdeula/">Apple’s Standard Licensed Application End User License Agreement (Standard EULA)</a>, unless a separate custom license is displayed for the app in the App Store. These terms do not replace that license or override rights you have under applicable consumer law.</p>`)}
  ${section('purpose', '2. Using Tick & Kin', '<p>Tick & Kin is a personal focus and break timer with illustrated companions. You choose your session lengths and when to start, pause, or reset. It is a general productivity tool, not medical advice, treatment, or a safety-critical alarm.</p><p>Use the app and website lawfully, respect others’ rights, and do not interfere with their operation or security. Your use of the app is also subject to the usage rights and restrictions in its applicable license.</p>')}
  ${section('purchases', '3. Optional purchases', '<p>The timer, supported languages, and the Mochi, Pip, and Pebble companions are included free. Additional companion packs are optional one-time in-app purchases, not recurring subscriptions. Prices, currencies, taxes, and availability are shown by Apple before you confirm a purchase.</p><p>The three-pack collection includes Midnight Café, Moonlight Academy, and Orbital Night Shift. It does not promise access to future packs. Purchases can be restored with the same Apple Account through the app’s Restore Purchases option, subject to Apple’s purchase records and policies.</p><p>Apple processes payments and handles eligible refund requests. You can request assistance through <a href="https://reportaproblem.apple.com/">Apple’s purchase support</a>. Any statutory refund or consumer rights remain unaffected.</p>')}
  ${section('availability', '4. Availability and reminders', '<p>We aim to keep the app useful and the website accurate, but features may change with updates, device capabilities, or operating-system changes. Notifications may be delayed or silenced by device settings, Focus modes, or the operating system. Do not rely on Tick & Kin for critical reminders.</p><p>App Store availability depends on device, region, and release status. The website will link to the App Store when a listing is available. The free browser timer runs independently of the app; it does not sync sessions or purchases. App layouts may vary by device.</p>')}
  ${section('ownership', '5. Artwork and intellectual property', '<p>The app, website, branding, and illustrations are protected by applicable intellectual-property laws. Using them does not transfer ownership or grant a right to redistribute or sell the artwork. Separately licensed components remain subject to their respective licenses.</p>')}
  ${section('privacy', '6. Privacy', '<p>Our <a href="/privacy/">Privacy Policy</a> explains local app storage, Apple purchases, website analytics and delivery, and information you provide when contacting support.</p>')}
  ${section('rights', '7. Your rights', '<p>The applicable app license governs warranties, liability, and termination for the app. Nothing on this page limits rights or remedies that cannot be excluded under the laws that apply to you. We do not promise a particular productivity result from using the app.</p>')}
  ${section('updates', '8. Updates and contact', `<p>We may update these terms to reflect product or legal changes. The date above identifies the current version. For questions or a copy of a previous version, contact ${email}.</p>`)}`;
}

export function support() {
  return `<div class="contact-box"><h2>Email us</h2><p>${email}</p><p>Include your device model, iOS or iPadOS version, app version, and a short description of what happened. If you attach a screenshot, remove any personal information.</p></div>
  ${section('web-timer', 'Using the web timer', '<p>Use the <a href="/#timer">timer on the homepage</a> to focus with Mochi. Open Timer settings to choose a preset or set focus and break durations, then select Set timer. Pause keeps your remaining time; Reset returns to a fresh focus session and lets you change durations.</p><p>When a session ends, start the next focus session or break when you are ready. The web timer is silent and does not send notifications. If your browser suspends the page, the countdown catches up when you return, without starting another session.</p><p>Your durations and session are saved locally in this browser. Refreshing resumes the same timer when browser storage is available. To remove saved data, clear this site’s data in your browser. The browser timer does not sync with the iPhone or iPad app.</p>')}
  ${section('getting-started', 'Getting started', '<p>Choose a companion, select a timer preset in Settings, and start focusing. Gentle uses 15 minutes of focus and a 3-minute break, Classic uses 25 / 5, and Deep uses 50 / 10. The one-minute Quick try preset lets you try a full cycle.</p><p>Each next session starts explicitly. Short breaks and long breaks can be enabled separately. Long breaks replace every fourth short break when enabled.</p>')}
  ${section('restore', 'Restore companion purchases', '<p>Make sure you are signed into the Apple Account used for the purchase, connect to the internet, then open Settings → Companion packs → Restore Purchases. If a purchase is pending approval, it may not unlock immediately. If the pack is still missing, email us with the pack name and the steps you tried. Do not send payment card details.</p>')}
  ${section('sound', 'Check sound and reminders', '<p>Voice cues and sound effects are optional and have separate settings. Check those settings and your device volume if a companion is quiet. For reminders, check notification permission in your device’s Settings. Focus modes and system settings can silence notifications.</p>')}
  ${section('timer', 'Pause or start over', '<p>Use Pause to keep your remaining time. Use the slide-to-reset control to start the timer over. When you return to the app after a session has ended, the next session waits for you to start it.</p>')}
  ${section('data', 'Manage your local data', '<p>There is no account to delete. Settings and current session data are stored on your device. Deleting the app removes its local app container; offloading can preserve it. Backups and Apple purchase records are managed separately. See the <a href="/privacy/#choices">privacy choices section</a> for details.</p>')}
  ${section('billing', 'Billing and refunds', '<p>Apple processes companion purchases. For purchase history or an eligible refund request, visit <a href="https://reportaproblem.apple.com/">reportaproblem.apple.com</a>. We can help troubleshoot access to a companion pack, but cannot directly issue App Store refunds.</p>')}
  ${section('accessibility', 'Accessibility and feedback', `<p>The app supports system text sizing and Reduce Motion. If text, controls, speech, or artwork makes something difficult to use, let us know at ${email}. Tell us the device and setting involved so we can investigate.</p>`)}`;
}
export const pages = [
  { path: '/', file: 'index.html', title: 'Tick & Kin — Cute Pomodoro Timer for iPhone & iPad', description: site.description, body: home, kind: 'home' },
  { path: '/privacy/', file: 'privacy/index.html', title: 'Privacy Policy — Tick & Kin', heading: 'Privacy Policy', label: 'Privacy policy', description: 'How Tick & Kin handles local timer data, Apple purchases, Vercel website analytics, and support emails. The native app has no accounts, ads, or analytics.', body: privacy },
  { path: '/terms/', file: 'terms/index.html', title: 'Terms of Use — Tick & Kin', heading: 'Terms of Use', label: 'Terms of use', description: 'Terms for Tick & Kin, including the Apple Standard EULA, optional companion purchases, product availability, and your consumer rights.', body: terms },
  { path: '/support/', file: 'support/index.html', title: 'Support & Contact — Tick & Kin', heading: 'Support', label: 'Support', description: 'Contact Tick & Kin support. Get help with focus sessions, companion purchases, restoring purchases, voice cues, notifications, and privacy.', body: support },
  { path: '/404.html', file: '404.html', title: 'Page not found — Tick & Kin', heading: 'Page not found', label: '404 · Page not found', description: 'Find your way back to Tick & Kin.', body: () => '<p class="document-lede">This page may have moved, or the address may be mistyped.</p><a class="button" href="/">Back to home ↗</a>', noindex: true },
];
