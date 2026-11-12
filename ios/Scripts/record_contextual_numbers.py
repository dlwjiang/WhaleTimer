#!/usr/bin/env python3
"""Record difficult numerals as separate words inside short native-language phrases.
Only the numeral is packaged. Voice method, timbre and natural playback stay intact.
"""
from pathlib import Path
import argparse, hashlib, json, tempfile
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly
from faster_whisper import WhisperModel
import selected_voice_pipeline as production
from countdown_voices import number_words, word_key, LANGUAGES, separated_number_words
from selected_voice_contract import REFERENCE_LANGUAGES

FRAMES={'ko':('이제','다음'),'ja':('準備','次'),'zh-Hans':('准备','下一个'),
        'en':('Ready','Next'),'es':('Listo','Siguiente'),'pt-BR':('Pronto','Próximo'),
        'fr':('Prêt','Suivant'),'de':('Bereit','Weiter')}


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--character',required=True)
    parser.add_argument('--language',choices=LANGUAGES,required=True)
    parser.add_argument('--cues',default='5,4,3,2,1')
    parser.add_argument('--round',type=int,default=3)
    parser.add_argument('--attempts',type=int,default=6)
    args=parser.parse_args()
    c=args.character;lang=args.language
    choices,review=production.load_review(production.PILOT/'tick-and-kin-engine-review.json',[c])
    selected=choices['selectedVoices'][c];route=review['routes'][c]['route']
    pilot=json.loads((production.PILOT/'manifest.json').read_text())['clips'][f'{c}/{route}']
    lines=json.loads((production.ROOT/'Localization/voice-lines.json').read_text())[lang]
    manifest_path=production.OUT/'manifest.json';manifest=json.loads(manifest_path.read_text())
    folder=production.SOURCE/c/lang;folder.mkdir(parents=True,exist_ok=True)
    engine=production.Engine(Path('/tmp/banke-models/Qwen3-TTS-12Hz-1.7B-Base-bf16'))
    asr=WhisperModel(str(Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-medium/snapshots/08e178d48790749d25932bbc082711ddcfdfbc4f'),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    audit_path=folder/'contextual-number-attempts.json';audit=json.loads(audit_path.read_text()) if audit_path.exists() else {}
    failures=[]
    for cue in args.cues.split(','):
        if cue not in list('12345'):raise ValueError('Only countdown numerals are supported')
        key=f'{lang}/{c}/{cue}';before,after=FRAMES[lang]
        text=f'{before}. {lines[cue].strip(" .!。、！？")}. {after}.'
        accepted=False;takes=[]
        for attempt in range(args.attempts):
            seed=(pilot['seed']+args.round*1000003+attempt*1009)&0xffffffff
            pcm,sr=engine.render(text,lang,selected,route,seed,direction='Speak these short words crisply, with a brief clear pause between each word. Articulate the final consonants. Keep the same small character voice. No singing or extra sounds.')
            divisor=np.gcd(sr,16000);samples=resample_poly(pcm,16000//divisor,sr//divisor).astype(np.float32)
            segments,_=asr.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),word_timestamps=True,condition_on_previous_text=False,vad_filter=False,beam_size=3)
            words=[{'text':w.word,'start':float(w.start),'end':float(w.end)} for segment in segments for w in segment.words if word_key(w.word)]
            options=[str(cue)]+[word_key(v) for v in number_words(lang,int(cue))]
            recognized=words
            found=[i for i,w in enumerate(words) if word_key(w['text']) in options and i>0 and i<len(words)-1 and w['end']-w['start']>=.1]
            joined=''.join(word_key(w['text']) for w in words)
            if not found and any(joined==word_key(before)+option+word_key(after) for option in options):
                aligned=separated_number_words(pcm,sr,lang,order=(6,int(cue),0))
                if aligned:
                    aligned[0]['text']=before;aligned[-1]['text']=after
                    words=aligned;found=[1]
            take={'seed':seed,'text':text,'recognizedWords':recognized,'words':words};takes.append(take)
            # Keep the most recent source for diagnosis, even if it is rejected.
            sf.write(folder/f'{cue}-last-context.wav',pcm,sr,subtype='PCM_24')
            print('CONTEXT',key,seed,[w['text'] for w in words],flush=True)
            if len(found)!=1:continue
            i=found[0];w=words[i]
            a=max((words[i-1]['end']+w['start'])/2,w['start']-.12)
            b=min((w['end']+words[i+1]['start'])/2,w['end']+.12)
            if b<=a:continue
            try:
                part=production.clean(pcm[int(a*sr):int(b*sr)],sr,leading=.02,trailing=.05)
                edge=max(1,round(sr*.01))
                if max(float(np.sqrt(np.mean(part[:edge]**2))),float(np.sqrt(np.mean(part[-edge:]**2))))>.008:
                    take['rejected']='Boundary is not quiet; do not cut through the word';continue
                with tempfile.TemporaryDirectory(prefix='banke-context-number-') as temp:
                    wav=Path(temp)/'number.wav';aac=Path(temp)/'number.m4a'
                    sf.write(wav,part,sr,subtype='PCM_24');encoded=production.encode(wav,aac,short=True)
                    source=folder/f'{cue}-context.wav';sf.write(source,pcm,sr,subtype='PCM_24')
                    metadata={'method':'contextual-number-v2','number':int(cue),'text':text,'recognizedWords':recognized,'words':words,'numberIndex':i,'bounds':[a,b],'sourceSHA256':production.sha(source),'seed':seed,'speed':1,'pitch':1,'synthesisInstruction':engine.last_instruction}
                    production.write(source.with_suffix('.json'),metadata)
                    (folder/f'{cue}.wav').write_bytes(wav.read_bytes());dest=production.OUT/f'{key}.m4a';dest.parent.mkdir(parents=True,exist_ok=True);dest.write_bytes(aac.read_bytes())
                    entry={**encoded,'text':lines[cue],'seed':seed,'model':engine.path.name,'sourceSampleRate':sr,
                           'castingVoice':selected['voice'],'auditionSHA256':selected['sha256'],
                           'auditionWAVSHA256':production.sha(production.CAST/'audio'/f'{selected["voice"]}.wav'),
                           'route':route,'pilotSHA256':review['routes'][c]['pilotSHA256'],'pipelineRevision':production.REVISION,
                           'method':'contextual-number-v2','bounds':[a,b],'contextSHA256':production.sha(source),
                           'hash':hashlib.sha256(json.dumps([text,seed,selected,route,'contextual-number-v2']).encode()).hexdigest()}
                    if selected['model'].startswith('Qwen') and route=='reference':entry['languageConditioning']=REFERENCE_LANGUAGES[lang]
                    manifest['clips'][key]=entry;production.write(manifest_path,manifest)
                take['accepted']=True;print('ACCEPTED',key,round(len(part)/sr,3),'seconds',flush=True);accepted=True;break
            except ValueError as error:take['rejected']=str(error)
        audit.setdefault(cue,[]).append({'round':args.round,'takes':takes});production.write(audit_path,audit)
        if not accepted:failures.append(key)
    print('Context numeral failures:',failures,flush=True)
    if failures:raise SystemExit(1)


if __name__=='__main__':main()
