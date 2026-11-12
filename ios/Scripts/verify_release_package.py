#!/usr/bin/env python3
"""Validate the v1.0 handoff and build its local, server-free visual index."""
from pathlib import Path
import hashlib,html,json,struct
ROOT=Path(__file__).resolve().parents[1]/'Release/1.0'
EXPECTED={'iphone-medium':(1206,2622),'iphone-large':(1320,2868),'ipad-13':(2064,2752),'duo-current':(1398,2034),'duo-inner':(2853,2007),'duo-tabletop':(2007,2853)}
STORIES=['01-mochi-focus','02-pip-focus','04-your-rhythm','06-luna-focus']
def png(path):
 data=path.read_bytes();assert data[:8]==b'\x89PNG\r\n\x1a\n',path
 w,h=struct.unpack('>II',data[16:24]);return w,h,data[25],len(data)
metadata=json.loads((ROOT/'metadata/app-store.json').read_text())
assert set(metadata)=={'en','ja','ko','zh-Hans','zh-Hant','es','pt-BR','fr','de'}
for locale,fields in metadata.items():
 for key,limit in [('name',30),('subtitle',30),('keywords',100),('promotionalText',170),('description',4000)]:
  assert 0<len(fields[key])<=limit,(locale,key)
 assert len(fields['keywords'].encode())<=100,(locale,'keyword bytes')
products=json.loads((ROOT/'metadata/in-app-purchases.json').read_text());assert len(products)==4
for product in products:assert len(product['localizations'])==9
for group,size in EXPECTED.items():
 for story in STORIES:
  for base in ['screenshots','store-upload/en']:
   p=ROOT/base/group/(story+'.png');w,h,t,n=png(p)
   assert (w,h)==size,(p,w,h)
   assert t==2,(p,'PNG must be opaque RGB',t)
   assert n<10*1024*1024,(p,'over 10 MiB')
for name in ['collection','midnightCafe','moonlightAcademy','orbitalNightShift']:
 p=ROOT/'iap-review'/('iap-'+name+'-purchase.png');assert p.exists(),p
for name,size in {'app-icon-1024':(1024,1024),'launch-header':(2400,1200),'social-preview':(1200,630),'launch-square':(1080,1080)}.items():
 w,h,t,n=png(ROOT/'marketing'/(name+'.png'));assert (w,h)==size;assert t==2,(name,'alpha')
assets=[]
for p in sorted(ROOT.rglob('*.png')):
 w,h,t,n=png(p);assets.append({'path':p.relative_to(ROOT).as_posix(),'width':w,'height':h,'bytes':n,'colorType':t,'sha256':hashlib.sha256(p.read_bytes()).hexdigest()})
(ROOT/'verification/assets.json').write_text(json.dumps({'images':assets,'preparedDisplayGroups':EXPECTED,'captionedScreenshotCount':24,'iapReviewCount':4},indent=2)+'\n')
parts=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tick & Kin · 1.0 release room</title><style>
*{box-sizing:border-box}body{margin:0;background:#f7f3eb;color:#293e4a;font:17px/1.55 system-ui}main{max-width:1280px;margin:auto;padding:48px 28px}h1{font:64px/1.05 Georgia;margin:12px 0 20px}h2{font:36px Georgia;margin:52px 0 18px}p{max-width:850px}a{color:#2e6963}nav{display:flex;gap:14px;flex-wrap:wrap;margin:28px 0}nav a{background:white;padding:12px 18px;border-radius:12px;text-decoration:none;border:1px solid #e0dace}.status{padding:18px 22px;background:#e9eee5;border-radius:18px}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(220px,1fr));gap:20px}.wide{grid-template-columns:repeat(auto-fit,minmax(360px,1fr))}figure{margin:0;background:white;padding:10px;border:1px solid #e1ddd3;border-radius:16px}img{width:100%;height:auto;display:block;border-radius:9px}figcaption{padding:10px;font-size:14px}.label{letter-spacing:3px;font-size:13px;color:#2e6963;font-weight:700}small{color:#596b71}code{font-size:13px}@media(max-width:600px){h1{font-size:43px}.wide{grid-template-columns:1fr}main{padding:28px 18px}}
</style><main><div class="label">TICK & KIN · RELEASE ROOM</div><h1>Make room for focus.</h1><p>Version 1.0, build 1. Store screenshots, desk scenes and the submission handoff in one place.</p><div class="status"><strong>Prepared for review, not submitted.</strong><br>37 core tests + 14 focused native tests passed. App Store Connect, signing, bank/tax setup and TestFlight verification are still required.</div><nav><a href="SUBMISSION.md">Submission checklist</a><a href="AUDIT.md">Audit evidence</a><a href="LEGAL-AND-PRIVACY.md">Legal & privacy</a><a href="metadata/en.txt">English listing</a><a href="metadata/app-store.json">All nine languages</a><a href="metadata/featuring-nomination.txt">Featuring pitch</a></nav><h2>A little company on your desk.</h2><p>Generated promotional visualizations, based on real app captures. These are for website/social use—not App Store screenshot slots. Luna is optional paid content.</p><div class="grid wide">''']
def card(path,caption):
 assert (ROOT/path).exists(),path
 return f'<figure><a href="{html.escape(path)}"><img loading="lazy" src="{html.escape(path)}" alt="{html.escape(caption)}"></a><figcaption>{html.escape(caption)}</figcaption></figure>'
for name,caption in [('duo-desk-morning','Morning with Mochi · included free'),('duo-desk-evening','Evening with Luna · Moonlight Academy paid pack')]:parts.append(card('marketing/'+name+'.png',caption))
parts.append('</div><h2>Headers & launch artwork</h2><div class="grid wide">')
for name in ['launch-header','social-preview','launch-square']:parts.append(card('marketing/'+name+'.png',name.replace('-',' ').title()))
parts.append('</div><p><a href="marketing/app-icon-1024.png">App icon · 1024 × 1024</a> · <a href="marketing/PROVENANCE.md">Sources and usage notes</a></p>')
labels={'iphone-medium':'iPhone · medium','iphone-large':'iPhone · large','ipad-13':'iPad · 13-inch','duo-current':'Duo · outer portrait','duo-inner':'Duo · inner landscape','duo-tabletop':'Duo · tabletop portrait'}
for group,size in EXPECTED.items():
 parts.append(f'<h2>{labels[group]}</h2><p>{size[0]} × {size[1]} pixels · English upload set. Click an image for the full-resolution PNG.</p><div class="grid">')
 for story in STORIES:parts.append(card(f'store-upload/en/{group}/{story}.png',story[3:].replace('-',' ').title()))
 parts.append('</div>')
parts.append('<h2>Purchase review images</h2><p>Actual local StoreKit purchase controls, showing the proposed US prices. Configure and verify real products before submitting.</p><div class="grid">')
for p in sorted((ROOT/'iap-review').glob('*.png')):parts.append(card(p.relative_to(ROOT).as_posix(),p.stem.replace('iap-','').replace('-purchase','')))
parts.append('</div><h2>Copy & next steps</h2><p><a href="metadata/launch-copy.txt">Launch, website and social copy</a> · <a href="metadata/review-notes.txt">App Review notes</a> · <a href="metadata/in-app-purchases.json">Purchase localizations</a></p><p>Open this folder directly in your browser. No server, account, tracking or external assets. Keep the files beside this index. Final physical-device checks are listed in the submission guide.</p><small>Prepared November 12, 2026. No Apple endorsement or featuring decision is implied.</small></main></html>')
(ROOT/'index.html').write_text(''.join(parts))
print(f'Validated {len(assets)} image assets; 24 upload cards, 4 IAP review images, 9 listing locales. Local gallery written.')
