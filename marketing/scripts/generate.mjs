import { cp, mkdir, rm, writeFile } from 'node:fs/promises';
import { resolve, dirname } from 'node:path';
import { site } from '../site.config.mjs';
import { pages, faqs, escape } from '../src/content.mjs';

const base = resolve(import.meta.dirname, '..');
const out = resolve(base, '.generated');
if (!site.publisherConfirmed) console.warn('Confirm the legal publisher in site.config.mjs before publishing.');
if (site.appStoreUrl && !/^https:\/\/apps\.apple\.com\//.test(site.appStoreUrl)) throw new Error('Use an official App Store listing URL.');
const origin = new URL(site.origin).origin;
if (origin !== site.origin || !origin.startsWith('https://')) throw new Error('The canonical origin must be HTTPS, with no path or trailing slash.');
await rm(out, { recursive: true, force: true });
await mkdir(out, { recursive: true });
await cp(resolve(base, 'public'), resolve(out, 'public'), { recursive: true });
await cp(resolve(base, 'src/style.css'), resolve(out, 'style.css'));
await cp(resolve(base, 'src/timer.css'), resolve(out, 'timer.css'));
await mkdir(resolve(out, 'src'), { recursive: true });
for (const file of ['main.js', 'web-timer.js', 'pomodoro.js', 'lib']) {
  await cp(resolve(base, 'src', file), resolve(out, 'src', file), { recursive: true });
}
const json = (value) => JSON.stringify(value).replace(/</g, '\\u003c');
const publisher = { '@type': 'Person', '@id': `${origin}/#publisher`, name: site.publisher, email: site.supportEmail };
const brand = `<a class="brand" href="/" aria-label="Tick and Kin home"><img src="/icon.png" alt="" width="36" height="36"><span>Tick <i>&</i> Kin</span></a>`;
const nav = (path) => `<header class="site-header wrap">${brand}<nav aria-label="Main navigation"><a href="/#how-it-works">How it works</a><a href="/#companions">Companions</a><a href="/support/" ${path === '/support/' ? 'aria-current="page"' : ''}>Support</a></nav>${site.appStoreUrl ? `<a class="header-cta" href="${escape(site.appStoreUrl)}">Get the app ↗</a>` : ''}</header>`;
const footer = `<footer class="site-footer wrap"><div>${brand}</div><nav aria-label="Footer navigation"><a href="/support/">Support</a><a href="/privacy/">Privacy</a><a href="/terms/">Terms</a><a href="mailto:${escape(site.supportEmail)}">Contact</a></nav><p class="copyright">© ${site.updated.slice(0, 4)} ${escape(site.publisher)}. Tick & Kin.</p></footer>`;
for (const page of pages) {
  const url = origin + page.path;
  const graph = [publisher, { '@type': 'WebSite', '@id': `${origin}/#website`, name: site.name, url: `${origin}/`, publisher: { '@id': publisher['@id'] }, inLanguage: 'en' }, {
    '@type': page.path === '/support/' ? 'ContactPage' : 'WebPage', '@id': `${url}#webpage`, url, name: page.title,
    description: page.description, isPartOf: { '@id': `${origin}/#website` }, inLanguage: 'en', dateModified: site.updated,
  }];
  if (page.kind === 'home') graph.push({
    '@type': 'SoftwareApplication', '@id': `${origin}/#app`, name: site.name, alternateName: 'Tick and Kin',
    applicationCategory: 'ProductivityApplication', operatingSystem: 'iOS, iPadOS', url: `${origin}/`,
    description: site.description, image: `${origin}/social.png`, publisher: { '@id': publisher['@id'] },
    featureList: ['25-minute Pomodoro preset and customizable breaks', 'Three free illustrated study companions, including Mochi the cat', 'Optional one-time companion purchases; no subscriptions', 'Offline timer with no account required', 'Portrait and landscape flip clock for iPhone and iPad', 'Nine interface languages'],
    ...(site.appStoreUrl ? { installUrl: site.appStoreUrl } : {}),
  }, {
    '@type': 'WebApplication', '@id': `${origin}/#web-timer`, name: 'Tick & Kin Web Timer',
    url: `${origin}/#timer`, applicationCategory: 'ProductivityApplication', operatingSystem: 'Web browser',
    isAccessibleForFree: true, browserRequirements: 'Requires JavaScript',
    description: 'A free browser Pomodoro timer with Mochi the cat, adjustable focus and break durations, and locally saved sessions.',
    publisher: { '@id': publisher['@id'] },
  }, { '@type': 'FAQPage', '@id': `${origin}/#questions`, mainEntity: faqs.map(([name, text]) => ({ '@type': 'Question', name, acceptedAnswer: { '@type': 'Answer', text } })) });
  else if (!page.noindex) graph.push({ '@type': 'BreadcrumbList', itemListElement: [
    { '@type': 'ListItem', position: 1, name: site.name, item: `${origin}/` },
    { '@type': 'ListItem', position: 2, name: page.label, item: url },
  ] });
  const html = `<!doctype html>
<html lang="en"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escape(page.title)}</title><meta name="description" content="${escape(page.description)}">
<meta name="robots" content="${page.noindex ? 'noindex, follow' : 'index, follow, max-image-preview:large'}">
<link rel="canonical" href="${url}"><meta name="theme-color" content="#f7f5ef"><meta name="color-scheme" content="light">
<link rel="icon" type="image/png" href="/icon.png"><link rel="apple-touch-icon" href="/apple-touch-icon.png">
<link rel="preload" href="/fonts/Manrope-Bold.ttf" as="font" type="font/ttf" crossorigin>
<meta property="og:type" content="website"><meta property="og:site_name" content="Tick &amp; Kin"><meta property="og:locale" content="en_US">
<meta property="og:title" content="${escape(page.title)}"><meta property="og:description" content="${escape(page.description)}"><meta property="og:url" content="${url}">
<meta property="og:image" content="${origin}/social.png"><meta property="og:image:width" content="1200"><meta property="og:image:height" content="630"><meta property="og:image:alt" content="Tick and Kin: a cozy focus timer with Mochi the cat by a sunny window">
<meta name="twitter:card" content="summary_large_image"><meta name="twitter:title" content="${escape(page.title)}"><meta name="twitter:description" content="${escape(page.description)}"><meta name="twitter:image" content="${origin}/social.png"><meta name="twitter:image:alt" content="Tick and Kin: a cozy focus timer with Mochi the cat by a sunny window">
<link rel="stylesheet" href="/style.css">
${page.kind === 'home' ? '<link rel="stylesheet" href="/timer.css"><script type="module" src="/src/main.js"></script>' : ''}
<script type="application/ld+json">${json({ '@context': 'https://schema.org', '@graph': graph })}</script>
</head><body class="${page.kind === 'home' ? 'home' : 'document-page'}"><a class="skip-link" href="#main">Skip to content</a>
${nav(page.path)}<main id="main">${page.kind === 'home' ? page.body() : `<article class="document wrap"><header class="document-header"><a class="back-link" href="/">← Back to Tick & Kin</a><h1>${escape(page.heading)}</h1>${page.noindex ? '' : `<p class="updated">${page.path === '/support/' ? 'Updated' : 'Effective'} <time datetime="${site.updated}">${new Date(`${site.updated}T12:00:00Z`).toLocaleDateString('en-US', { year: 'numeric', month: 'long', day: 'numeric', timeZone: 'UTC' })}</time></p>`}</header><div class="document-body">${page.body()}</div></article>`}</main>${footer}</body></html>`;
  const destination = resolve(out, page.file);
  await mkdir(dirname(destination), { recursive: true });
  await writeFile(destination, html);
}
const indexed = pages.filter((p) => !p.noindex);
await writeFile(resolve(out, 'public/robots.txt'), `User-agent: *\nAllow: /\n\nSitemap: ${origin}/sitemap.xml\n`);
await writeFile(resolve(out, 'public/sitemap.xml'), `<?xml version="1.0" encoding="UTF-8"?>\n<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n${indexed.map((p) => `  <url><loc>${escape(origin + p.path)}</loc><lastmod>${site.updated}</lastmod></url>`).join('\n')}\n</urlset>\n`);
await writeFile(resolve(out, 'public/llms.txt'), `# Tick & Kin\n\n> ${site.description}\n\n## Product facts\n\n- Platform: iPhone and iPad. ${site.appStoreUrl ? 'App Store: ' + site.appStoreUrl : 'Coming soon; no public App Store listing yet.'}\n- Free: timer, all nine supported interface languages, Mochi, Pip, and Pebble.\n- Optional purchases: one-time companion packs. No required subscription.\n- The native app works offline; purchases and restoration use Apple services.\n- A free browser Pomodoro timer with Mochi is available on the homepage. Requires JavaScript and a connection to load; saves sessions in browser local storage. No sounds, notifications, or app sync.\n- No accounts, ads, app analytics, or AI conversation. Settings and current session state stay on the device.\n- Publisher: ${site.publisher}. Support: ${site.supportEmail}.\n\n## Official pages\n\n${indexed.map((p) => `- [${p.title}](${origin + p.path}): ${p.description}`).join('\n')}\n\nUpdated: ${site.updated}. This file summarizes the linked public pages.\n`);
console.log(`Generated ${pages.length} static HTML pages for ${origin}.`);
