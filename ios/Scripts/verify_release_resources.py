#!/usr/bin/env python3
"""Check localization/commerce completeness and decodability of the shipped audio."""
from pathlib import Path
import argparse, hashlib, json, re, struct, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
LANGS={'en','ja','ko','zh-Hans','zh-Hant','es','pt-BR','fr','de'}
CHARS=['mochi','pip','pebble','jun','bean','maple','luna','atlas','wisp','nova','orbit','comet']
CUES=['go','pause','resume','reset','focusComplete','breakComplete','1','2','3','4','5','greeting','poke']

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--allow-incomplete',action='store_true');parser.add_argument('--decode',action='store_true');args=parser.parse_args()
    errors=[]
    catalog=json.loads((ROOT/'Banke/Localizable.xcstrings').read_text())['strings']
    # Catch missing keys used by direct SwiftUI labels, not just incomplete
    # translations of keys that happen to remain in the catalog.
    literal_label = re.compile(r'\b(?:Text|Button|Toggle|Label|Section|Picker|ProgressView|TextField|alert|confirmationDialog|accessibilityLabel|accessibilityHint|navigationTitle|L10n\.text)\("([^"\\]*)"')
    for source in (ROOT/'Banke').rglob('*.swift'):
        for key in literal_label.findall(source.read_text()):
            if key and key not in catalog:
                errors.append(f'Missing UI localization key in {source.name}: {key}')
    for key,value in catalog.items():
        localizations=value.get('localizations',{})
        if set(localizations)!=LANGS:errors.append(f'Locales missing for {key}')
        for lang,item in localizations.items():
            if not item['stringUnit']['value'].strip():errors.append(f'Empty {key}: {lang}')
    names=json.loads((ROOT/'Localization/app-names.json').read_text())
    info=json.loads((ROOT/'Banke/InfoPlist.xcstrings').read_text())['strings']
    if set(names)!=LANGS:errors.append('App names must cover all nine locales')
    for lang,name in names.items():
        for key,table in [('app.name',catalog),('CFBundleDisplayName',info),('CFBundleName',info)]:
            if table.get(key,{}).get('localizations',{}).get(lang,{}).get('stringUnit',{}).get('value')!=name:
                errors.append(f'App title mismatch: {key}/{lang}')
    commerce=json.loads((ROOT/'Commerce/Companions.storekit').read_text())
    expected_locales={'en_US','ja','ko','zh_CN','zh_TW','es_ES','pt_BR','fr_FR','de_DE'}
    for product in commerce['products']:
        if {x['locale'] for x in product['localizations']}!=expected_locales:errors.append(f'Commerce locales missing: {product["productID"]}')
    # Confirm runtime pose copies match their inspected source extractions.
    assets=ROOT/'Banke/Assets.xcassets'
    for character in CHARS:
        for pose in ['idle','focus','rest','happy']:
            name=f'{character}-{pose}'
            source=ROOT/'Design'/f'{character}-pixel'/f'{pose}.png'
            asset=assets/f'{name}.imageset'/'sprite.png'
            if not source.exists() or not asset.exists():
                errors.append(f'Missing companion pose: {name}');continue
            data=asset.read_bytes()
            if data!=source.read_bytes():errors.append(f'Stale runtime pose: {name}')
            if data[:8]!=b'\x89PNG\r\n\x1a\n' or len(data)<26:
                errors.append(f'Invalid PNG pose: {name}');continue
            width,height=struct.unpack('>II',data[16:24])
            if width!=height or data[25]!=6:errors.append(f'Expected square RGBA pose: {name}')
    expansion=json.loads((ROOT/'Design/companion-expansion.json').read_text())
    for character,entry in expansion['characters'].items():
        for relative,digest in entry['files'].items():
            path=ROOT/relative
            if not path.exists() or hashlib.sha256(path.read_bytes()).hexdigest()!=digest:
                errors.append(f'Changed/missing inspected asset: {relative}')
        source=ROOT/'Design/DuoConcepts'/f'{character}-scene.png'
        asset=assets/f'duo-{character}.imageset'/'scene.png'
        if not asset.exists() or asset.read_bytes()!=source.read_bytes():
            errors.append(f'Stale runtime Duo scene: {character}')
    # Every companion must have a full-width Duo scene, including existing paid packs.
    for character in CHARS:
        source=ROOT/'Design/DuoConcepts'/f'{character}-scene.png'
        asset=assets/f'duo-{character}.imageset'/'scene.png'
        if not asset.exists():
            errors.append(f'Missing Duo scene: {character}');continue
        data=asset.read_bytes()
        if data[:8]!=b'\x89PNG\r\n\x1a\n' or len(data)<26:
            errors.append(f'Invalid Duo PNG: {character}');continue
        width,height=struct.unpack('>II',data[16:24])
        if width*2!=height*3:errors.append(f'Expected 3:2 Duo scene: {character}')
        if source.exists() and source.read_bytes()!=data:
            errors.append(f'Stale runtime Duo scene: {character}')
    layers=json.loads((ROOT/'Design/DuoLayers/manifest.json').read_text())['assets']
    if set(layers)!=set(CHARS)|{f'room-{r}' for r in ['window','study','river','cafe','academy','orbit']}:
        errors.append('Duo layers must cover all twelve companions and six shared rooms')
    for name,entry in layers.items():
        room=name.startswith('room-')
        source=ROOT/'Design/DuoLayers'/entry['source']
        asset=assets/f'duo-{name if room else "sprite-"+name}.imageset'/('room.png' if room else 'poses.png')
        if not source.exists() or not asset.exists():
            errors.append(f'Missing Duo layer: {name}');continue
        data=asset.read_bytes()
        if data!=source.read_bytes() or hashlib.sha256(data).hexdigest()!=entry['sha256']:
            errors.append(f'Changed/stale Duo layer: {name}')
        if data[:8]!=b'\x89PNG\r\n\x1a\n' or len(data)<26:
            errors.append(f'Invalid Duo layer PNG: {name}');continue
        width,height=struct.unpack('>II',data[16:24])
        if [width,height]!=entry['size']:errors.append(f'Duo layer size mismatch: {name}')
        if room and width*2!=height*3:errors.append(f'Expected 3:2 Duo room: {name}')
        if not room and (width%2 or data[25]!=6 or entry.get('frames')!=['idle','poked']):
            errors.append(f'Expected two-frame RGBA companion: {name}')
    landscapes=json.loads((ROOT/'Design/DuoLandscape/generation.json').read_text())['assets']
    if {entry['name'] for entry in landscapes}!={'window','study','river','cafe','academy','orbit'}:
        errors.append('Duo landscape backgrounds must cover all six rooms')
    for entry in landscapes:
        source=ROOT/'Design/DuoLandscape'/entry['source']
        asset=assets/f"{entry['asset']}.imageset"/'landscape.png'
        if not source.exists() or not asset.exists():
            errors.append(f"Missing Duo landscape: {entry['name']}");continue
        data=asset.read_bytes()
        if data!=source.read_bytes() or hashlib.sha256(data).hexdigest()!=entry['sha256']:
            errors.append(f"Changed/stale Duo landscape: {entry['name']}")
        if data[:8]!=b'\x89PNG\r\n\x1a\n' or len(data)<26:
            errors.append(f"Invalid Duo landscape PNG: {entry['name']}");continue
        if list(struct.unpack('>II',data[16:24]))!=entry['size']:
            errors.append(f"Duo landscape size mismatch: {entry['name']}")
    audio=ROOT/'Banke/Audio/Voices';manifest=json.loads((audio/'manifest.json').read_text())
    expected={f'{lang}/{character}/{cue}' for lang in LANGS-{'zh-Hant'} for character in CHARS for cue in CUES}
    missing=expected-set(manifest['clips'])
    voice_lines=json.loads((ROOT/'Localization/voice-lines.json').read_text())
    for key,entry in manifest['clips'].items():
        language,character,cue=key.split('/')
        if entry['text']!=voice_lines[language][character if cue=='greeting' else cue]:
            errors.append(f'Speech/caption mismatch: {key}')
        path=audio/f'{key}.m4a'
        if not path.exists() or path.stat().st_size!=entry['bytes']:errors.append(f'Missing/changed audio: {key}');continue
        if key.split('/')[-1].isdigit() and entry.get('method')!='context-countdown-v1':errors.append(f'Unverified isolated digit: {key}')
        if args.decode:
            info=json.loads(subprocess.check_output(['ffprobe','-v','error','-show_entries','format=duration:stream=codec_name,sample_rate,channels','-of','json',str(path)]))
            stream=info['streams'][0];duration=float(info['format']['duration'])
            if stream['codec_name']!='aac' or stream['sample_rate']!='24000' or stream['channels']!=1:errors.append(f'Wrong audio format: {key}')
            if duration<=.1 or duration>12:errors.append(f'Unexpected duration: {key} = {duration}')
            if key.split('/')[-1].isdigit() and duration>.9:errors.append(f'Digit exceeds one beat: {key} = {duration}')
            if subprocess.run(['ffmpeg','-v','error','-i',str(path),'-f','null','-'],capture_output=True).returncode:errors.append(f'Cannot decode: {key}')
    print(f'{len(catalog)} translation keys × 9 languages; 4 products × 9 languages; {len(expected)-len(missing)}/{len(expected)} voice clips.')
    if missing:print(f'{len(missing)} voice clips remain missing.')
    for error in errors:print(error)
    if errors or (missing and not args.allow_incomplete):sys.exit(1)
    if missing:print('Partial check only: not a release-complete voice bundle.')
if __name__=='__main__':main()
