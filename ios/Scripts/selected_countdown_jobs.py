#!/usr/bin/env python3
"""List only missing or invalid countdown performances; keep successful takes."""
from pathlib import Path
import argparse
import json
from selected_voice_contract import ROOT, REFERENCE_LANGUAGES, sha


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--include-wording-flags',action='store_true')
    parser.add_argument('--output',type=Path,default=ROOT/'Verification/selected-countdown-jobs.json')
    args=parser.parse_args()
    audio=ROOT/'Verification/SelectedEngineVoices'
    source=ROOT/'Design/Voices/SelectedEngineProduction'
    manifest=json.loads((audio/'manifest.json').read_text())
    report_path=ROOT/'Verification/selected-engine-transcripts.json'
    report=json.loads(report_path.read_text()) if report_path.exists() else {'clips':{}}
    jobs=[]
    for character in manifest['casting']['selectedVoices']:
        for language in REFERENCE_LANGUAGES:
            reasons=[]
            for cue in ['5','4','3','2','1']:
                key=f'{language}/{character}/{cue}';entry=manifest['clips'].get(key,{})
                path=audio/f'{key}.m4a';wav=source/character/language/f'{cue}.wav'
                if not entry or not path.exists() or not wav.exists():
                    reasons.append(f'{cue}: missing');continue
                if sha(path)!=entry.get('audioSHA256') or sha(wav)!=entry.get('rawSHA256'):
                    reasons.append(f'{cue}: source/output hash mismatch')
                if entry['route']=='reference' and language!='en' and entry.get('languageConditioning')!=REFERENCE_LANGUAGES[language]:
                    reasons.append(f'{cue}: missing explicit target-language conditioning')
                if args.include_wording_flags:
                    check=report['clips'].get(key,{})
                    if check.get('sha256')==entry['audioSHA256'] and check.get('review')=='check':
                        reasons.append(f'{cue}: wording check failed')
            if reasons:jobs.append({'character':character,'language':language,'reasons':reasons})
    args.output.write_text(json.dumps({'entries':jobs},ensure_ascii=False,indent=2)+'\n')
    print(f'{len(jobs)} countdown performances need work; saved to {args.output}')


if __name__=='__main__':main()
