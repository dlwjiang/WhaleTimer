#!/usr/bin/env python3
"""Recognize the actual encoded 5→1 clips after splitting/time compression, not just source WAVs."""
from pathlib import Path
import argparse,hashlib,json,subprocess
import numpy as np
from countdown_voices import recognize
ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'Banke/Audio/Voices'
REPORT=ROOT/'Verification/encoded-countdowns.json'
LANGS=['en','zh-Hans','ja','ko','es','pt-BR','fr','de']
CHARS=['mochi','pip','jun','bean','luna','atlas','nova','orbit']

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--allow-incomplete',action='store_true');args=parser.parse_args()
    report=json.loads(REPORT.read_text()) if REPORT.exists() else {'method':'Decode actual bundled AAC digits, assemble one-second slots, then recognize 5→1 with local Whisper. Human pronunciation review remains separate.','sequences':{}}
    missing=[]
    for character in CHARS:
        for language in LANGS:
            key=f'{language}/{character}'
            paths=[AUDIO/key/f'{n}.m4a' for n in [5,4,3,2,1]]
            if not all(p.exists() for p in paths):missing.append(key);continue
            digest=hashlib.sha256(b''.join(p.read_bytes() for p in paths)).hexdigest()
            if report['sequences'].get(key,{}).get('sha256')==digest:continue
            clips=[]
            for p in paths:
                raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar','16000','-ac','1','-'])
                pcm=np.frombuffer(raw,dtype=np.float32)
                clips.append(np.pad(pcm,(0,max(0,16000-len(pcm)))))
            words,valid=recognize(np.concatenate(clips),16000,language)
            report['sequences'][key]={'sha256':digest,'recognized':[w['text'] for w in words],'status':'verified' if valid else 'review'}
            temp=REPORT.with_suffix('.tmp');temp.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');temp.replace(REPORT)
            print(key,report['sequences'][key]['status'],[w['text'] for w in words],flush=True)
    review=[k for k,v in report['sequences'].items() if v['status']!='verified']
    print(f'{len(report["sequences"])}/64 encoded countdowns checked; {len(review)} need review; {len(missing)} missing.',flush=True)
    if review or (missing and not args.allow_incomplete):raise SystemExit(1)
if __name__=='__main__':main()
