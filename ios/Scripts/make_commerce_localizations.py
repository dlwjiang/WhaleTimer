#!/usr/bin/env python3
"""Prepare local StoreKit copy and an App Store Connect copy draft; does not publish."""
from pathlib import Path
import json
ROOT=Path(__file__).resolve().parents[1]
strings=json.loads((ROOT/'Banke/Localizable.xcstrings').read_text())['strings']
locales={'en':'en_US','ja':'ja','ko':'ko','zh-Hans':'zh_CN','zh-Hant':'zh_TW','es':'es_ES','pt-BR':'pt_BR','fr':'fr_FR','de':'de_DE'}
path=ROOT/'Commerce/Companions.storekit';config=json.loads(path.read_text())
def translate(key,lang):return strings[key]['localizations'][lang]['stringUnit']['value']
for product in config['products']:
    product['localizations']=[]
    for lang,locale in locales.items():
        description=translate('Nine companions, voices and scenes.' if product['productID'].endswith('.collection.v1') else 'Three companions, poses, voices and scenes.',lang)
        name=translate(product['referenceName'],lang)
        assert len(name)<=30,(lang,name)
        assert len(description)<=55,(lang,description)
        product['localizations'].append({'description':description,'displayName':name,'locale':locale})
path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n')
(ROOT/'Commerce/localization-draft.json').write_text(json.dumps({'status':'Draft for review and manual App Store Connect setup; not published.','products':[{ 'productID':p['productID'],'localizations':p['localizations']} for p in config['products']]},ensure_ascii=False,indent=2)+'\n')
print('Prepared four products × nine languages.')
