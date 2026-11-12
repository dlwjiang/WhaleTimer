#!/usr/bin/env python3
"""Standalone listening comparison: approved auditions vs regenerated app greetings."""
from pathlib import Path
import argparse, base64, html, json
ROOT=Path(__file__).resolve().parents[1]
CAST=ROOT/'Design/Voices/VoiceCasting'
parser=argparse.ArgumentParser()
parser.add_argument('--audio-root',type=Path,default=ROOT/'Banke/Audio/Voices')
parser.add_argument('--output',type=Path,default=ROOT/'Verification/approved-voice-review.html')
args=parser.parse_args();AUDIO=args.audio_root
manifest=json.loads((AUDIO/'manifest.json').read_text())
review=manifest.get('productionReview',{})
a=json.loads((CAST/'approved-choices.json').read_text())
lines=json.loads((ROOT/'Localization/voice-lines.json').read_text())['en']
def uri(path,mime): return f'data:{mime};base64,'+base64.b64encode(path.read_bytes()).decode()
def esc(text): return html.escape(text,quote=True)
cards=[]
for name,choice in a['choices'].items():
    selected=a['selectedVoices'][name]
    picture=CAST/'images'/f'{name}.png'
    route=review.get('routes',{}).get(name,{}).get('route')
    route_label={'direct':'Original design process','reference':'Reuse original voice'}.get(route,'Legacy production')
    cards.append(f'''<article><div class="character"><img alt="{esc(name.title())}" src="{uri(picture,'image/png')}"><div><h2>{esc(name.title())}</h2><p>{esc(selected['name'])} · {esc(route_label)}</p></div></div>
<div class="samples"><section><h3>Your selected audition</h3><p>{esc(a['auditionText'])}</p><audio controls preload="none" src="{uri(CAST/'audio'/f'{choice["voice"]}.m4a','audio/mp4')}"></audio></section>
<section><h3>Regenerated app greeting</h3><p>{esc(lines[name])}</p><audio controls preload="none" src="{uri(AUDIO/'en'/name/'greeting.m4a','audio/mp4')}"></audio></section></div></article>''')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tick & Kin · Approved voice check</title><style>
*{box-sizing:border-box}body{margin:0;background:#f7f4ed;color:#294147;font:16px/1.5 system-ui}main{max-width:1050px;margin:40px auto;padding:0 24px}h1{font:42px Georgia;margin-bottom:12px}h2{margin:0}h3{font-size:15px;margin:0}p{color:#637677}article{background:#fffdf8;border:1px solid #dddcd2;border-radius:22px;margin:24px 0;padding:20px}.character{display:flex;align-items:center;gap:20px}.character img{width:110px;height:110px;object-fit:contain;image-rendering:pixelated}.samples{display:grid;grid-template-columns:1fr 1fr;gap:24px}section p{min-height:72px}audio{width:100%}small{color:#637677}@media(max-width:640px){.samples{grid-template-columns:1fr}section p{min-height:0}h1{font-size:32px}}
</style><main><small>TICK & KIN · APPROVED VOICE CHECK</small><h1>Your choices, speaking the app's lines.</h1><p>Compare the exact audition you selected with its regenerated English greeting. Each greeting uses the production method selected in your listening review. Your ears determine whether the character still feels right. All images and audio are embedded—double-click this file, no server required.</p>'''+''.join(cards)+'''<p>Local generation and transcript checks only. No external media assessment.</p></main><script>document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></html>'''
out=args.output
out.parent.mkdir(parents=True,exist_ok=True)
out.write_text(page)
print(out)
