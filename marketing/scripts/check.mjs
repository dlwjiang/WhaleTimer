import { readFile, access, stat } from 'node:fs/promises';
import { resolve } from 'node:path';
import assert from 'node:assert/strict';
import { site } from '../site.config.mjs';
import { pages, faqs } from '../src/content.mjs';

const root = resolve(import.meta.dirname, '../dist');
const htmlByPath = new Map();
for (const page of pages) htmlByPath.set(page.path, await readFile(resolve(root, page.file), 'utf8'));
const ids = (html) => new Set([...html.matchAll(/\bid="([^"]+)"/g)].map((m) => m[1]));
const titles = new Set();
for (const page of pages) {
  const html = htmlByPath.get(page.path);
  assert.equal((html.match(/<h1\b/g) || []).length, 1, `${page.path} needs one H1`);
  assert(html.includes(`href="${site.origin + page.path}"`), `${page.path}: wrong canonical`);
  assert(html.includes('<html lang="en">'));
  const title = html.match(/<title>(.*?)<\/title>/s)?.[1];
  assert(title && !titles.has(title), `${page.path}: missing/duplicate title`); titles.add(title);
  assert(html.includes('name="description"'));
  assert(!/TODO|lorem ipsum|example\.com|undefined|\[insert/i.test(html), `${page.path}: placeholder content`);
  const schemas = [...html.matchAll(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/g)].map((m) => JSON.parse(m[1]));
  assert(schemas[0]?.['@graph']?.length, `${page.path}: structured data missing`);
  const publisher = schemas[0]['@graph'].find((n) => n['@id'] === `${site.origin}/#publisher`);
  assert.equal(publisher.name, site.publisher);
  for (const image of html.matchAll(/<img\b[^>]*>/g)) {
    assert(/\balt="/.test(image[0]), `Image missing alt in ${page.path}`);
    assert(/\bwidth="/.test(image[0]) && /\bheight="/.test(image[0]), `Image needs dimensions in ${page.path}`);
  }
  for (const [, target] of html.matchAll(/(?:href|src)="([^"]+)"/g)) {
    if (/^(?:https?:|mailto:|data:)/.test(target)) continue;
    const url = new URL(target.replaceAll('&amp;', '&'), site.origin + page.path);
    const file = resolve(root, `.${url.pathname}`, url.pathname.endsWith('/') ? 'index.html' : '');
    await access(file).catch(() => { throw new Error(`Broken ${page.path} link: ${target}`); });
    if (url.hash) {
      const targetHTML = htmlByPath.get(url.pathname) || await readFile(file, 'utf8');
      assert(ids(targetHTML).has(url.hash.slice(1)), `Broken anchor ${target} on ${page.path}`);
    }
  }
  if (page.noindex) assert(html.includes('noindex, follow'));
  assert.equal((html.match(/<script\b[^>]*\btype="module"/g) || []).length, 1,
    `${page.path}: every page should load its analytics entry point`);
}
const home = htmlByPath.get('/');
const faqSchema = JSON.parse(home.match(/<script type="application\/ld\+json">([\s\S]*?)<\/script>/)[1])['@graph'].find((n) => n['@type'] === 'FAQPage');
assert.equal(faqSchema.mainEntity.length, faqs.length);
assert(!home.includes('aggregateRating'), 'Do not invent ratings');
if (!site.appStoreUrl) assert(!home.includes('Download on the App Store'), 'No download button without a real listing');
const sitemap = await readFile(resolve(root, 'sitemap.xml'), 'utf8');
for (const page of pages.filter((p) => !p.noindex)) assert(sitemap.includes(site.origin + page.path));
assert(!sitemap.includes('404.html'));
assert((await readFile(resolve(root, 'robots.txt'), 'utf8')).includes(`Sitemap: ${site.origin}/sitemap.xml`));
const social = await readFile(resolve(root, 'social.png'));
assert.equal(social.readUInt32BE(16), 1200); assert.equal(social.readUInt32BE(20), 630);
for (const asset of ['social.png', 'art/window.webp', 'art/mochi.webp']) assert((await stat(resolve(root, asset))).size < 600_000, `${asset} exceeds image budget`);
const cssFiles = [...home.matchAll(/href="([^"]+\.css)"/g)].map((m) => m[1]);
for (const cssFile of cssFiles) {
  const css = await readFile(resolve(root, `.${cssFile}`), 'utf8');
  for (const [, url] of css.matchAll(/url\(["']?([^"')]+)["']?\)/g)) {
    if (url.startsWith('/')) await access(resolve(root, `.${url}`));
  }
}
console.log(`Verified ${pages.length} pages: direct HTML, internal links and anchors, metadata, JSON-LD, sitemap, image dimensions, and assets.`);
