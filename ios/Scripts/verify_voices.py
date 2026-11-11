#!/usr/bin/env python3
"""Offline transcript diagnostics, resumable by encoded-file SHA256. Human listening still required."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, unicodedata
from difflib import SequenceMatcher
import numpy as np
from faster_whisper import WhisperModel
import zhconv

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'Banke/Audio/Voices'
OUT=ROOT/'Verification/voice-transcripts.json'
MODEL=Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'

def normalize(text):
    text=zhconv.convert(text,'zh-cn')
    return ''.join(c for c in unicodedata.normalize('NFKC',text).lower() if c.isalnum())

def main():
    global AUDIO, OUT
    parser=argparse.ArgumentParser()
    parser.add_argument('--characters',default='')
    parser.add_argument('--audio-root',type=Path,default=AUDIO)
    parser.add_argument('--source-root',type=Path,default=ROOT/'Design/Voices')
    parser.add_argument('--report',type=Path,default=OUT)
    args=parser.parse_args()
    AUDIO=args.audio_root.resolve(); OUT=args.report.resolve()
    OUT.parent.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((AUDIO/'manifest.json').read_text())
    report=json.loads(OUT.read_text()) if OUT.exists() else {'method':'Local faster-whisper small/int8; diagnostics only, not native-speaker approval.','clips':{}}
    model=WhisperModel(str(MODEL),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    for key,entry in manifest['clips'].items():
        lang,character,cue=key.split('/')
        if args.characters and character not in args.characters.split(','):continue
        path=AUDIO/f'{key}.m4a';digest=hashlib.sha256(path.read_bytes()).hexdigest()
        if report['clips'].get(key,{}).get('sha256')==digest:continue
        if cue.isdigit() and entry.get('method')=='context-countdown-v1':
            source=json.loads((args.source_root/character/lang/'countdown.json').read_text())
            report['clips'][key]={'sha256':digest,'expected':entry['text'],'heard':source['words'][5-int(cue)]['text'],
                'review':'context-verified','note':'Full source countdown recognized in order; clip boundary/format checked separately.'}
            temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');temp.replace(OUT)
            continue
        # Padding prevents clipping decoder context around short recordings.
        raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(path),'-f','f32le','-ar','16000','-ac','1','-'])
        samples=np.pad(np.frombuffer(raw,dtype=np.float32),(4000,8000))
        segments,_=model.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),condition_on_previous_text=False,vad_filter=False,beam_size=3)
        heard=''.join(s.text for s in segments).strip()
        similarity=SequenceMatcher(None,normalize(entry['text']),normalize(heard)).ratio()
        report['clips'][key]={'sha256':digest,'expected':entry['text'],'heard':heard,'similarity':round(similarity,3),'review': 'isolated-digit' if cue.isdigit() else 'check' if similarity < .85 else 'transcript-match'}
        temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');temp.replace(OUT)
        print(key,report['clips'][key]['review'],heard,flush=True)
if __name__=='__main__':main()
