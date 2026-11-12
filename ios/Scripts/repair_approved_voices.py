#!/usr/bin/env python3
"""Targeted local wording retakes. Never changes an approved reference identity."""
from pathlib import Path
from difflib import SequenceMatcher
import argparse, hashlib, json, time
import numpy as np
from scipy.signal import resample_poly
import generate_voices as gen
from countdown_voices import LANGUAGES, generate as countdown, recognize
from verify_voices import normalize

ROOT=Path(__file__).resolve().parents[1]

def transcribe(pcm,sr,lang):
    import countdown_voices as counter
    # The recognizer is shared with countdown boundary verification.
    if counter.ASR is None:
        from faster_whisper import WhisperModel
        from verify_voices import MODEL
        counter.ASR=WhisperModel(str(MODEL),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    divisor=np.gcd(sr,16000)
    samples=np.pad(resample_poly(pcm,16000//divisor,sr//divisor).astype(np.float32),(4000,8000))
    segments,_=counter.ASR.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),condition_on_previous_text=False,vad_filter=False,beam_size=3)
    return ''.join(s.text for s in segments).strip()

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--audio-root',type=Path,default=ROOT/'Verification/ApprovedVoices')
    parser.add_argument('--report',type=Path,default=ROOT/'Verification/approved-voice-transcripts.json')
    parser.add_argument('--characters',default='')
    parser.add_argument('--attempts',type=int,default=3)
    parser.add_argument('--round',type=int,default=1,help='Use fresh deterministic seeds for a later repair pass.')
    args=parser.parse_args()
    gen.SOURCE=ROOT/'Design/Voices/ApprovedProduction'; gen.OUT=args.audio_root.resolve()
    approved=json.loads((ROOT/'Design/Voices/VoiceCasting/approved-choices.json').read_text())
    manifest_path=gen.OUT/'manifest.json';manifest=json.loads(manifest_path.read_text())
    profiles=json.loads((gen.SOURCE/'profiles.json').read_text())
    pronunciations_path=gen.SOURCE/'pronunciations.json'
    pronunciations=json.loads(pronunciations_path.read_text()) if pronunciations_path.exists() else {}
    report=json.loads(args.report.read_text())
    chars=args.characters.split(',') if args.characters else list(approved['choices'])
    flags=[k for k,v in report['clips'].items() if v['review']=='check' and k.split('/')[1] in chars]
    lines=json.loads((ROOT/'Localization/voice-lines.json').read_text())
    missing=[(c,l) for c in chars for l in LANGUAGES if any(f'{l}/{c}/{n}' not in manifest['clips'] for n in range(1,6))]
    print(f'{len(flags)} flagged phrases; {len(missing)} missing countdowns',flush=True)
    if not flags and not missing:return
    model=gen.load_model(str(gen.MODEL));model.set_dtype(gen.mx.float32)
    gen.cache_reference_encoder(model)
    audit_path=gen.OUT/'repairs.json'
    audit=json.loads(audit_path.read_text()) if audit_path.exists() else {}
    for character in chars:
        selected=approved['selectedVoices'][character]
        ref=gen.SOURCE/character/'reference.wav';refmeta=json.loads(ref.with_suffix('.json').read_text())
        digest=hashlib.sha256(ref.read_bytes()).hexdigest()
        assert refmeta['auditionSHA256']==selected['sha256'] and refmeta['referenceSHA256']==digest
        for ch,lang in missing:
            if ch!=character:continue
            for attempt in range(1,args.attempts+1):
                ok=countdown(model,character,lang,ref,gen.SOURCE/character/lang,gen.OUT/lang/character,lines[lang],manifest,gen.clean,gen.encode,retake=(args.round-1)*10+attempt)
                if ok:
                    for cue in ['1','2','3','4','5']:
                        manifest['clips'][f'{lang}/{character}/{cue}'].update(castingVoice=selected['voice'],auditionSHA256=selected['sha256'],referenceSHA256=digest)
                gen.write(manifest_path,manifest)
                if ok:break
        for key in [k for k in flags if k.split('/')[1]==character]:
            lang,_,cue=key.split('/')
            entry=manifest['clips'][key];expected=entry['text'];best=report['clips'][key].get('similarity',0)
            old_sha=hashlib.sha256((gen.OUT/f'{key}.m4a').read_bytes()).hexdigest()
            if report['clips'][key]['sha256']!=old_sha:
                print('SKIP stale transcript',key,flush=True);continue
            instruction=f'Speak {LANGUAGES[lang]} naturally and clearly. Say only the supplied words, with no extra sounds or laughter.'
            spoken=expected
            if args.round>1:
                # Punctuation and kana spellings improve short-phrase pronunciation
                # without changing the intended words or the reference voice.
                spoken=expected.replace('!', '.').replace('！','。')
                if lang=='pt-BR' and cue=='poke':spoken='Oi, você me achou.'
                if lang=='ja':
                    spoken={'pause':'ひといき、つこう。まってるね。',
                            'resume':'よし、つづけよう。',
                            'reset':'きもちをあらたに、もういちど。',
                            'breakComplete':'きゅうけい、おしまい。じゅんびができたら、はじめよう。',
                            'go':'さあ、はじめよう。'}.get(cue,spoken)
                    if args.round>2 and cue=='breakComplete':
                        spoken='キュウケイ、おしまい。ジュンビができたら、はじめよう。'
            fingerprint=hashlib.sha256((expected+profiles[character]+gen.MODEL.name+('spoken:'+spoken if spoken!=expected else '')+'instruct:'+instruction+'reference:'+digest).encode()).hexdigest()
            takes=[]
            for attempt in range(args.attempts):
                seed=(int(fingerprint[:8],16)+args.round*1_000_003+attempt*1009)&0xffffffff
                pcm,seed=gen.render(model,spoken,seed,reference=ref,instruct=instruction)
                if pcm is None:continue
                heard=transcribe(pcm,model.sample_rate,lang)
                score=SequenceMatcher(None,normalize(expected,lang),normalize(heard,lang)).ratio()
                takes.append({'seed':seed,'heard':heard,'score':round(score,3)})
                print('RETAKE',key,round(score,3),heard,flush=True)
                if score>best:
                    wav=gen.SOURCE/character/lang/f'{cue}.wav';dest=gen.OUT/f'{key}.m4a'
                    gen.sf.write(wav,pcm,model.sample_rate,subtype='PCM_16')
                    duration=gen.encode(wav,dest)
                    manifest['clips'][key]={'text':expected,'hash':fingerprint,'seed':seed,'duration':round(duration,3),'sourceDuration':round(len(pcm)/model.sample_rate,3),'bytes':dest.stat().st_size,'referenceSHA256':digest,'castingVoice':selected['voice'],'auditionSHA256':selected['sha256'],'audioSHA256':hashlib.sha256(dest.read_bytes()).hexdigest(),'instruction':instruction}
                    pronunciations[key]={'instruct':instruction}
                    if spoken!=expected:
                        manifest['clips'][key]['spokenText']=spoken
                        pronunciations[key]['text']=spoken
                    gen.write(pronunciations_path,pronunciations);gen.write(manifest_path,manifest)
                    report['clips'][key]={'sha256':manifest['clips'][key]['audioSHA256'],'expected':expected,'heard':heard,'similarity':round(score,3),'review':'transcript-match' if score>=.85 else 'check'}
                    gen.write(args.report,report)
                    best=score
                gen.mx.clear_cache()
                if best>=.85:break
            audit[key]={'previousSHA256':old_sha,'takes':takes,'bestScore':round(best,3)}
            gen.write(audit_path,audit)
if __name__=='__main__':main()
