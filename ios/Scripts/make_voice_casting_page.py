#!/usr/bin/env python3
"""Build a single-file audition page with embedded images and audio."""
from pathlib import Path
import base64, json

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Design/Voices/VoiceCasting'
plan = json.loads((OUT / 'plan.json').read_text())
manifest = json.loads((OUT / 'manifest.json').read_text()) if (OUT / 'manifest.json').exists() else {'clips': {}}
report = json.loads((OUT / 'transcripts.json').read_text()) if (OUT / 'transcripts.json').exists() else {'clips': {}}
def embedded(path, mime):
    return f'data:{mime};base64,' + base64.b64encode(path.read_bytes()).decode('ascii')

for ch in plan['characters']:
    ch['image'] = embedded(ROOT / f'Banke/Assets.xcassets/{ch["id"]}-idle.imageset/sprite.png', 'image/png')
    for c in ch['candidates']:
        clip = manifest['clips'].get(c['id'], {})
        audio = OUT / f'audio/{c["id"]}.m4a'
        c['ready'] = bool(clip) and audio.exists()
        c['audio'] = embedded(audio, 'audio/mp4') if c['ready'] else ''
        c['duration'] = clip.get('duration')
        c['model'] = clip.get('model', '')
        diagnostic = report['clips'].get(c['id'], {})
        c['diagnostic'] = diagnostic.get('heard', '') if diagnostic.get('review') == 'check' else ''
template = (ROOT / 'Scripts/voice_casting_template.html').read_text()
page = template.replace('__CASTING_DATA__', json.dumps(plan, ensure_ascii=False).replace('<', '\\u003c'))
(OUT / 'index.html').write_text(page)
if plan.get('editionFile'):
    (OUT / Path(plan['editionFile']).name).write_text(page)
print(f'{sum(c["ready"] for ch in plan["characters"] for c in ch["candidates"])}/48 samples: {OUT / "index.html"}')
