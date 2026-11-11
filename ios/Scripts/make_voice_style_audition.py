#!/usr/bin/env python3
"""Build the local A/B audition page for proposed character-voice retakes."""
from pathlib import Path
import html,json
root=Path(__file__).resolve().parents[1]
folder=root/'Design/Voices/StyleReview'
current=json.loads((folder/'original-audio/manifest.json').read_text())['clips']
manifest=folder/'candidate-audio/manifest.json'
candidates=json.loads(manifest.read_text())['clips'] if manifest.exists() else {}
report=folder/'candidate-transcripts.json'
transcripts=json.loads(report.read_text())['clips'] if report.exists() else {}
profiles=json.loads((folder/'candidate-source/profiles.json').read_text())
notes={'mochi':'Plush, light kitten warmth','jun':'A smiling little café helper','luna':'Soft, bright stargazing curiosity','atlas':'A small, rounded storybook owl','nova':'A buoyant little space companion','pebble':'A soft little river otter','bean':'A cheeky, cuddly kitten','maple':'A sweet little bakery helper','comet':'A light, bouncy rabbit courier'}
parts=['''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tick &amp; Kin — Voice comparisons</title><style>
:root{color-scheme:light}body{font:16px/1.5 system-ui,sans-serif;background:#f8f3ed;color:#483e3a;max-width:860px;margin:40px auto;padding:0 20px}h1{margin-bottom:4px}h2{margin-bottom:4px}p{margin-top:0}section{padding:24px;background:#fffcf8;border:1px solid #e3d6c8;border-radius:20px;margin:24px 0}.row{display:grid;grid-template-columns:1fr 1fr;gap:16px;margin-bottom:24px}.take{background:#f2ebe4;border-radius:12px;padding:12px}audio{width:100%;margin-top:8px}label{display:block;font-size:13px;font-weight:700}.filters{display:flex;gap:20px;flex-wrap:wrap}.filters label{font-size:14px}select{display:block;margin-top:6px}select{font:inherit;padding:8px 12px;border-radius:8px;border:1px solid #b7aa9c}small{display:block;color:#746658}.flag{color:#9d4d29}details{font-size:13px}summary{cursor:pointer}audio:focus-visible,select:focus-visible,summary:focus-visible{outline:3px solid #376d86;outline-offset:4px}@media(max-width:600px){.row{grid-template-columns:1fr}section{padding:16px}body{margin-top:20px}}</style>
<h1>Tick &amp; Kin · Voice comparisons</h1><p>Soft and playful — a cozy little companion.</p><p>Compare the current and proposed voices for the seven companions you identified. The app still uses its existing recordings.</p><p><small>Keeping Pip, Atlas, Wisp, Nova, and Orbit unchanged.</small></p><div class="filters"><label>Companion <select id="companion">__COMPANION_OPTIONS__</select></label><label>Spoken language <select id="language"><option value="en">English</option><option value="zh-Hans">Mandarin · 中文</option></select></label></div>''']
for ch in profiles:
 parts.append(f'<section class="companion-section" data-companion="{ch}"><h2>{ch.title()}</h2><p>{notes[ch]}</p>')
 for lang in ['en','zh-Hans']:
  parts.append(f'<div data-language="{lang}">')
  for cue in ['greeting','pause','resume']:
   key=f'{lang}/{ch}/{cue}'
   parts.append(f'<h3>{cue.title()}</h3><p>{html.escape(current[key]["text"])}</p><div class="row">')
   for kind,path in [('Current',f'original-audio/{key}.m4a'),('Candidate',f'candidate-audio/{key}.m4a')]:
    parts.append(f'<div class="take"><label>{kind}</label>')
    if kind=='Current' or key in candidates:
     parts.append(f'<audio controls preload="none" aria-label="{ch.title()} {lang} {cue} {kind}" src="{path}"></audio>')
    else:parts.append('<p>Still generating.</p>')
    if kind=='Candidate' and key in candidates:
     parts.append(f'<small>{candidates[key]["duration"]:.2f} seconds</small>')
     t=transcripts.get(key,{})
     if t.get('review')=='check':parts.append(f'<small class="flag">Transcript diagnostic differs: {html.escape(t["heard"])}. Please listen for clarity.</small>')
    parts.append('</div>')
   parts.append('</div>')
  parts.append('</div>')
 parts.append(f'<details><summary>Voice direction</summary><p>{html.escape(profiles[ch])}</p></details></section>')
parts.append('''<p><small>Local files only; no server required. Transcript checks assess wording, not cuteness, pronunciation approval, or acting quality.</small></p><script>
const language=document.querySelector('#language'),companion=document.querySelector('#companion');function render(){document.querySelectorAll('[data-companion]').forEach(el=>el.hidden=el.dataset.companion!==companion.value);document.querySelectorAll('[data-language]').forEach(el=>el.hidden=el.dataset.language!==language.value);document.querySelectorAll('audio').forEach(a=>a.pause())}language.addEventListener('change',render);companion.addEventListener('change',render);document.querySelectorAll('audio').forEach(a=>a.addEventListener('play',()=>document.querySelectorAll('audio').forEach(b=>{if(a!==b)b.pause()})));render();
</script></html>''')
options=''.join(f'<option value="{ch}">{ch.title()}</option>' for ch in profiles)
(folder/'compare.html').write_text('\n'.join(parts).replace('__COMPANION_OPTIONS__',options))
print(f'{len(candidates)} candidate clips; comparison page written.')
