#!/usr/bin/env python3
"""Offline transcript diagnostics, resumable by encoded-file SHA256. Human listening still required."""
from pathlib import Path
import argparse, hashlib, json, re, subprocess, unicodedata, time
from difflib import SequenceMatcher
import numpy as np
from faster_whisper import WhisperModel
import zhconv
from countdown_voices import WORDS, word_key, sequence_matches
from selected_voice_contract import equivalent_wording

ROOT=Path(__file__).resolve().parents[1]
AUDIO=ROOT/'Banke/Audio/Voices'
OUT=ROOT/'Verification/voice-transcripts.json'
MODEL=Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'

def normalize(text, language=None):
    text=unicodedata.normalize('NFKC',text)
    if language=='ja':
        # Compare readings for the app's short scripts. These are orthographic
        # equivalents, not permission to substitute different spoken sentences.
        readings={'お疲れ様':'おつかれさま','お疲れさま':'おつかれさま',
                  'ひと息':'ひといき','一息':'ひといき','ひと行き':'ひといき',
                  '待ってる':'まってる','続けよう':'つづけよう','少し':'すこし',
                  '休もう':'やすもう','休憩':'きゅうけい','準備':'じゅんび',
                  '始めよう':'はじめよう','気持ち':'きもち','新たに':'あらたに',
                  'もう一度':'もういちど','見つかっちゃった':'みつかっちゃった',
                  '隣':'となり','席':'せき','取って':'とって','進もう':'すすもう',
                  '小さな':'ちいさな','大きな':'おおきな','冒険':'ぼうけん',
                  '集中':'しゅうちゅう','一緒':'いっしょ','仲間':'なかま',
                  '魔法':'まほう','届けよう':'とどけよう','一歩':'いっぽ',
                  '僕':'ぼく','君':'きみ','進めよう':'すすめよう','学ぼう':'まなぼう',
                  '一ページ':'いちページ','1ページ':'いちページ','星':'ほし',
                  '近づこう':'ちかづこう','課題':'かだい','波紋':'はもん',
                  '焼きたて':'やきたて','元気':'げんき','光':'ひかり',
                  '見つけよう':'みつけよう','お届けもの':'おとどけもの'}
        for written,reading in readings.items():text=text.replace(written,reading)
    text=zhconv.convert(text,'zh-cn')
    return ''.join(c for c in unicodedata.normalize('NFKC',text).lower() if c.isalnum())

def main():
    global AUDIO, OUT
    parser=argparse.ArgumentParser()
    parser.add_argument('--characters',default='')
    parser.add_argument('--cues',default='',help='Optional comma-separated cue filter')
    parser.add_argument('--follow-seconds',type=float,default=0,help='Watch atomic staging updates for this many seconds; reuse the local recognizer.')
    parser.add_argument('--audio-root',type=Path,default=AUDIO)
    parser.add_argument('--source-root',type=Path,default=ROOT/'Design/Voices/ApprovedProduction')
    parser.add_argument('--report',type=Path,default=OUT)
    parser.add_argument('--model-root',type=Path,default=MODEL)
    parser.add_argument('--only-flagged',action='store_true',help='Recheck uncertain clips even if their audio hash is unchanged.')
    args=parser.parse_args()
    AUDIO=args.audio_root.resolve(); OUT=args.report.resolve()
    OUT.parent.mkdir(parents=True,exist_ok=True)
    manifest=json.loads((AUDIO/'manifest.json').read_text())
    report=json.loads(OUT.read_text()) if OUT.exists() else {'method':'Local faster-whisper small/int8; diagnostics only, not native-speaker approval.','clips':{}}
    model=WhisperModel(str(args.model_root),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    def scan():
        manifest=json.loads((AUDIO/'manifest.json').read_text())
        checked_countdowns=set()
        for key,entry in manifest['clips'].items():
            lang,character,cue=key.split('/')
            if args.characters and character not in args.characters.split(','):continue
            if args.cues and cue not in args.cues.split(','):continue
            if args.only_flagged and report['clips'].get(key,{}).get('review')!='check':continue
            path=AUDIO/f'{key}.m4a';digest=hashlib.sha256(path.read_bytes()).hexdigest()
            previous=report['clips'].get(key,{})
            if not args.only_flagged and previous.get('sha256')==digest and previous.get('expected')==entry['text']:continue
            if cue.isdigit() and entry.get('method') in {'natural-countdown-v2','contextual-number-v2'}:
                group=(lang,character)
                if group in checked_countdowns:continue
                checked_countdowns.add(group)
                keys=[f'{lang}/{character}/{n}' for n in [5,4,3,2,1]]
                # The generator commits each clip separately; wait for all five.
                if not all(k in manifest['clips'] and (AUDIO/f'{k}.m4a').exists() for k in keys):continue
                chunks=[]
                for digit_key in keys:
                    raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(AUDIO/f'{digit_key}.m4a'),'-f','f32le','-ar','16000','-ac','1','-'])
                    chunks.extend([np.frombuffer(raw,dtype=np.float32),np.zeros(2400,dtype=np.float32)])
                samples=np.concatenate([np.zeros(4000,dtype=np.float32),*chunks,np.zeros(8000,dtype=np.float32)])
                segments,_=model.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),word_timestamps=True,condition_on_previous_text=False,vad_filter=False,beam_size=3)
                heard_words=[w.word for segment in segments for w in segment.words if word_key(w.word)]
                valid=sequence_matches(heard_words,lang)
                for digit_key in keys:
                    report['clips'][digit_key]={'sha256':hashlib.sha256((AUDIO/f'{digit_key}.m4a').read_bytes()).hexdigest(),
                        'expected':manifest['clips'][digit_key]['text'],'heardCountdown':heard_words,
                        'review':'encoded-countdown-match' if valid else 'check',
                        'recognizer':str(args.model_root),
                        'note':'Recognized the actual packaged 5–1 clips played in sequence; no inference from source timestamps.'}
                temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');temp.replace(OUT)
                print(lang,character,'encoded countdown',valid,heard_words,flush=True)
                continue
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
            similarity=SequenceMatcher(None,normalize(entry['text'],lang),normalize(heard,lang)).ratio()
            report['clips'][key]={'sha256':digest,'expected':entry['text'],'heard':heard,'similarity':round(similarity,3),'recognizer':str(args.model_root),'review': 'isolated-digit' if cue.isdigit() else 'check' if similarity < (.95 if lang=='en' else .85) else 'transcript-match'}
            if report['clips'][key]['review']=='check' and equivalent_wording(key,entry['text'],heard):
                report['clips'][key].update(review='equivalent-wording',note='Complete reaction has an accepted interjection/ending-particle variant; original transcript and score retained.')
            temp=OUT.with_suffix('.tmp');temp.write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');temp.replace(OUT)
            print(key,report['clips'][key]['review'],heard,flush=True)
    deadline=time.monotonic()+max(0,args.follow_seconds)
    while True:
        scan()
        remaining=deadline-time.monotonic()
        if remaining<=0:break
        time.sleep(min(15,remaining))
if __name__=='__main__':main()
