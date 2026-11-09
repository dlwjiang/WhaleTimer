#!/usr/bin/env python3
"""Check localization/commerce completeness and decodability of the shipped audio."""
from pathlib import Path
import argparse, json, subprocess, sys
ROOT=Path(__file__).resolve().parents[1]
LANGS={'en','ja','ko','zh-Hans','zh-Hant','es','pt-BR','fr','de'}
CHARS=['mochi','pip','jun','bean','luna','atlas','nova','orbit']
CUES=['go','pause','resume','reset','focusComplete','breakComplete','1','2','3','4','5','greeting']

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--allow-incomplete',action='store_true');parser.add_argument('--decode',action='store_true');args=parser.parse_args()
    errors=[]
    catalog=json.loads((ROOT/'Banke/Localizable.xcstrings').read_text())['strings']
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
    audio=ROOT/'Banke/Audio/Voices';manifest=json.loads((audio/'manifest.json').read_text())
    expected={f'{lang}/{character}/{cue}' for lang in LANGS-{'zh-Hant'} for character in CHARS for cue in CUES}
    missing=expected-set(manifest['clips'])
    for key,entry in manifest['clips'].items():
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
    print(f'{len(catalog)} translation keys × 9 languages; 4 products × 9 languages; {len(expected)-len(missing)}/768 voice clips.')
    if missing:print(f'{len(missing)} voice clips remain missing.')
    for error in errors:print(error)
    if errors or (missing and not args.allow_incomplete):sys.exit(1)
    if missing:print('Partial check only: not a release-complete voice bundle.')
if __name__=='__main__':main()
