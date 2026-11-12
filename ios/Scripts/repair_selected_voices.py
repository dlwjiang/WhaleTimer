#!/usr/bin/env python3
"""Retake unclear words through the user's reviewed engine/method, never another voice."""
from pathlib import Path
import argparse
import hashlib
import json
import tempfile
from difflib import SequenceMatcher
import subprocess
import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel
import selected_voice_pipeline as production
from verify_voices import MODEL, normalize


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--report', type=Path, required=True)
    parser.add_argument('--review', type=Path, default=production.PILOT/'tick-and-kin-engine-review.json')
    parser.add_argument('--characters', default='')
    parser.add_argument('--attempts', type=int, default=4)
    parser.add_argument('--round', type=int, default=1)
    parser.add_argument('--model-root', type=Path, default=MODEL)
    parser.add_argument('--enunciate', action='store_true', help='Request clear articulation without replacing the selected voice profile')
    args = parser.parse_args()
    report = json.loads(args.report.read_text())
    manifest_path = production.OUT/'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    chars = args.characters.split(',') if args.characters else list(manifest['casting']['selectedVoices'])
    choices, review = production.load_review(args.review, chars)
    engine = production.Engine(Path('/tmp/banke-models/Qwen3-TTS-12Hz-1.7B-Base-bf16'))
    asr = WhisperModel(str(args.model_root),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    keys = [k for k,v in report['clips'].items() if v.get('review')=='check' and k.split('/')[1] in chars and not k.split('/')[-1].isdigit() and v.get('similarity',0) < (.95 if k.startswith('en/') else .85)]
    audit_path = production.OUT/'wording-retakes.json'
    audit = json.loads(audit_path.read_text()) if audit_path.exists() else {}
    for key in sorted(keys, key=lambda k:(production.expected_model(choices['selectedVoices'][k.split('/')[1]],review['routes'][k.split('/')[1]]['route']),k)):
        lang, character, cue = key.split('/')
        current = manifest['clips'][key]
        dest = production.OUT/f'{key}.m4a'
        if production.sha(dest) != report['clips'][key]['sha256']:
            print('SKIP stale diagnostics',key,flush=True);continue
        selected = choices['selectedVoices'][character]
        route = review['routes'][character]['route']
        best = report['clips'][key].get('similarity',0)
        expected = current['text']
        takes = []
        for attempt in range(args.attempts):
            seed = (current['seed'] + args.round*1000003 + attempt*1009) & 0xffffffff
            with tempfile.TemporaryDirectory(prefix='banke-selected-retake-') as temp:
                wav = Path(temp)/'take.wav';aac = Path(temp)/'take.m4a'
                try:
                    spoken=expected
                    if lang=='ja' and attempt>0:
                        for written,reading in {'ひと息':'ひといき','休憩':'きゅうけい','準備':'じゅんび'}.items():spoken=spoken.replace(written,reading)
                    if attempt>0:
                        spoken=spoken.replace('!', '.').replace('！','。')
                        if lang=='de':spoken=spoken.replace("geht's",'geht es').replace('geht’s','geht es')
                        if lang in ['fr','de'] and attempt>1:spoken=spoken.replace(', ','. ')
                    direction=None
                    if args.enunciate:
                        direction='Keep the same character voice. Articulate each supplied word clearly, including brief interjections.'
                        if lang=='ko' and '앗' in spoken:direction+=' Preserve the final consonant in 앗.'
                        if lang=='zh-Hans' and '啦' in spoken:direction+=' Pronounce 啦 as lā, with an open ah vowel.'
                    pcm,sr = engine.render(spoken,lang,selected,route,seed,direction=direction)
                    sf.write(wav,pcm,sr,subtype='PCM_24')
                    metadata = production.encode(wav,aac)
                except ValueError as exc:
                    takes.append({'seed':seed,'rejected':str(exc)});continue
                raw = subprocess.check_output(['ffmpeg','-v','error','-i',str(aac),'-f','f32le','-ar','16000','-ac','1','-'])
                samples = np.pad(np.frombuffer(raw,dtype=np.float32),(4000,8000))
                segments,_ = asr.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),condition_on_previous_text=False,vad_filter=False,beam_size=3)
                heard = ''.join(s.text for s in segments).strip()
                score = SequenceMatcher(None,normalize(expected,lang),normalize(heard,lang)).ratio()
                takes.append({'seed':seed,'heard':heard,'score':round(score,3)})
                print('RETAKE',key,round(score,3),heard,flush=True)
                if score > best:
                    (production.SOURCE/character/lang/f'{cue}.wav').write_bytes(wav.read_bytes())
                    dest.write_bytes(aac.read_bytes())
                    current.update(metadata,seed=seed,wordingRetake=args.round,spokenText=spoken,synthesisInstruction=engine.last_instruction)
                    production.write(manifest_path,manifest)
                    report['clips'][key]={'sha256':metadata['audioSHA256'],'expected':expected,'heard':heard,'similarity':round(score,3),'review':'transcript-match' if score>=(.95 if lang=='en' else .85) else 'check','recognizer':str(args.model_root)}
                    production.write(args.report,report)
                    best=score
            if best >= (.95 if lang=='en' else .85):break
        audit.setdefault(key,[]).append({'round':args.round,'takes':takes,'bestScore':round(best,3)})
        production.write(audit_path,audit)
    print('Retake pass finished',flush=True)


if __name__ == '__main__':main()
