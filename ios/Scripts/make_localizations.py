#!/usr/bin/env python3
"""Compile translation source rows + speech captions into one Apple String Catalog."""
from pathlib import Path
import json
import re
root=Path(__file__).resolve().parents[1]
languages=['en','ja','ko','zh-Hans','zh-Hant','es','pt-BR','fr','de']
strings={}
for source in sorted((root/'Localization').glob('*.tsv')):
    for number,line in enumerate(source.read_text().splitlines(),1):
        if not line or line.startswith('#'): continue
        values=line.split('\t')
        if len(values)!=9: raise ValueError(f'{source.name}:{number}: expected 9 columns, got {len(values)}')
        key=values[0]
        if key in strings: raise ValueError(f'Duplicate key {key}')
        placeholders = sorted(re.findall(r'%(?:\d+\$)?(?:0\d+)?(?:lld|@)', key))
        for lang, value in zip(languages, values):
            if not value.strip(): raise ValueError(f'{source.name}:{number}: empty {lang} translation')
            if sorted(re.findall(r'%(?:\d+\$)?(?:0\d+)?(?:lld|@)', value)) != placeholders:
                raise ValueError(f'{source.name}:{number}: mismatched {lang} format placeholders')
        strings[key]={'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':value}} for lang,value in zip(languages,values)}}
voices=json.loads((root/'Localization/voice-lines.json').read_text())
names=json.loads((root/'Localization/app-names.json').read_text())
if set(names)!=set(languages) or any(not name.strip() for name in names.values()):
    raise ValueError('App names must cover all nine languages')
name_localizations={lang:{'stringUnit':{'state':'translated','value':names[lang]}} for lang in languages}
strings['app.name']={'extractionState':'manual','localizations':name_localizations}
info_strings={key:{'extractionState':'manual','localizations':name_localizations} for key in ['CFBundleDisplayName','CFBundleName']}
(root/'Banke/InfoPlist.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':info_strings,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
for cue in voices['en']:
    key='voice.'+('greeting.'+cue if cue in ['mochi','pip','pebble','jun','bean','maple','luna','atlas','wisp','nova','orbit','comet'] else cue)
    strings[key]={'extractionState':'manual','localizations':{lang:{'stringUnit':{'state':'translated','value':voices[lang][cue]}} for lang in languages}}
(root/'Banke/Localizable.xcstrings').write_text(json.dumps({'sourceLanguage':'en','strings':strings,'version':'1.0'},ensure_ascii=False,indent=2)+'\n')
print(f'{len(strings)} keys × {len(languages)} languages')
