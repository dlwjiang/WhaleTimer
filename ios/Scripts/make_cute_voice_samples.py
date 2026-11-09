#!/usr/bin/env python3
"""Make an offline before/after audition without changing the shipped voices.

Run with the same local Python environment as generate_voices.py.
"""
from pathlib import Path
import hashlib
import html
import json
import time

from generate_voices import MODEL, REFERENCE, clean, encode, load_model, mx, render, sf

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'Verification' / 'CuteVoices'
PROFILES = {
    'mochi': 'An original cute feminine plush desk-cat character voice. Soft, light, rounded mezzo soprano with a small warm smile in every phrase. Gentle playful rises and falls, affectionate tiny pauses, cozy and reassuring. Sweet clear conversational speech, softly energetic, relaxed and close. No whispering, no singing, no meowing.',
    'pip': 'An original cute feminine little botanical apprentice character voice. Light warm soprano, bright rounded vowels and a smiling gentle lilt. Playful curiosity, softly buoyant phrasing, tender encouraging warmth. Small delighted inflections with clear relaxed speech. No shouting, no whispering, no singing.',
    'jun': 'An original charming masculine cafe companion voice. Soft warm light tenor with a friendly audible smile and rounded mellow resonance. Gently playful, affectionate, cozy, lightly lilting short phrases, relaxed easy articulation. A sweet encouraging companion talking quietly beside you. No whispering, no deep announcer delivery, no singing.'
}
LANGUAGES = {'en': 'English', 'fr': 'Français'}
CUES = ('greeting', 'focusComplete')


def save_manifest(manifest):
    (OUT / 'manifest.json').write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')


def make_page(manifest):
    lines = json.loads((ROOT / 'Localization/voice-lines.json').read_text())
    sections = []
    for character in PROFILES:
        rows = []
        for lang, language in LANGUAGES.items():
            for cue in CUES:
                key = f'{character}/{lang}/{cue}'
                if key not in manifest['clips']:
                    continue
                text = lines[lang][character if cue == 'greeting' else cue]
                before = f'../../Banke/Audio/Voices/{lang}/{character}/{cue}.m4a'
                after = f'{key}.m4a'
                rows.append(f'''<article><p><b>{language} · {'Hello' if cue == 'greeting' else 'Focus complete'}</b><br>{html.escape(text)}</p>
                    <div class="pair"><label>Current<audio controls preload="none" src="{before}"></audio></label>
                    <label>Soft &amp; playful<audio controls preload="none" src="{after}"></audio></label></div></article>''')
        sections.append(f'<section><h2>{character.title()}</h2>{"".join(rows)}</section>')
    page = '''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
    <title>Tick &amp; Kin · Cozy voice samples</title><style>
    body{font:16px/1.6 system-ui,sans-serif;background:#f6f1e9;color:#493c36;margin:0;padding:32px 20px}
    main{max-width:900px;margin:auto}h1{font-size:30px;line-height:1.2}h2{margin:0}
    section{background:#fffaf3;border:1px solid #dfd0be;border-radius:22px;padding:24px;margin:24px 0}
    article+article{border-top:1px solid #e8ded2;margin-top:24px;padding-top:8px}
    .pair{display:grid;grid-template-columns:1fr 1fr;gap:20px}label{display:block;font-size:14px}
    audio{display:block;width:100%;margin-top:8px}@media(max-width:620px){.pair{grid-template-columns:1fr}}
    </style><main><h1>A softer little companion</h1><p>Compare the current voices with new soft, playful performances.
    Same words; new original synthetic voices. These are audition samples, separate from the app recordings.</p>
    <p>Listen for warmth, a gentle smile, clear words, and a voice you would enjoy hearing repeatedly.</p>'''
    page += ''.join(sections)
    page += '''</main><script>document.addEventListener('play',event=>{for(const audio of document.querySelectorAll('audio'))if(audio!==event.target)audio.pause()},true)</script></html>'''
    (OUT / 'index.html').write_text(page)


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    path = OUT / 'manifest.json'
    manifest = json.loads(path.read_text()) if path.exists() else {
        'model': MODEL.name, 'direction': 'soft and playful', 'profiles': PROFILES, 'clips': {}
    }
    lines = json.loads((ROOT / 'Localization/voice-lines.json').read_text())
    model = load_model(str(MODEL))
    model.set_dtype(mx.float32)
    for character, profile in PROFILES.items():
        folder = OUT / character
        folder.mkdir(exist_ok=True)
        reference = folder / 'reference.wav'
        if not reference.exists():
            seed = int(hashlib.sha256(profile.encode()).hexdigest()[:8], 16)
            started = time.monotonic()
            pcm, seed = render(model, REFERENCE, seed, instruct=profile, max_tokens=350)
            if pcm is None:
                raise RuntimeError(f'Reference needs a new take: {character}')
            sf.write(reference, pcm, model.sample_rate, subtype='PCM_16')
            (folder / 'reference.json').write_text(json.dumps({
                'description': profile, 'seed': seed, 'text': REFERENCE,
                'seconds': len(pcm) / model.sample_rate
            }, indent=2) + '\n')
            print(f'REFERENCE {character}: {time.monotonic()-started:.1f}s compute', flush=True)
        for lang in LANGUAGES:
            target = folder / lang
            target.mkdir(exist_ok=True)
            for cue in CUES:
                key = f'{character}/{lang}/{cue}'
                if key in manifest['clips'] and (OUT / f'{key}.m4a').exists():
                    continue
                text = lines[lang][character if cue == 'greeting' else cue]
                seed = int(hashlib.sha256((profile+lang+text).encode()).hexdigest()[:8], 16)
                started = time.monotonic()
                pcm, seed = render(model, text, seed, reference=reference)
                if pcm is None:
                    raise RuntimeError(f'Cue needs a new take: {key}')
                wav = target / f'{cue}.wav'
                sf.write(wav, pcm, model.sample_rate, subtype='PCM_16')
                seconds = encode(wav, target / f'{cue}.m4a')
                manifest['clips'][key] = {'text': text, 'seed': seed, 'seconds': seconds}
                save_manifest(manifest)
                make_page(manifest)
                print(f'{key}: {seconds:.2f}s audio / {time.monotonic()-started:.1f}s compute', flush=True)
                mx.clear_cache()
    print(f'Finished: {OUT / "index.html"}', flush=True)


if __name__ == '__main__':
    main()
