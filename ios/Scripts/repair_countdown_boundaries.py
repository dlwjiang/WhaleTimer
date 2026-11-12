#!/usr/bin/env python3
"""Recover clean cuts from retained performances; never synthesize or speed audio.
Proposals live separately until --apply, which verifies the originals are unchanged.
"""
from pathlib import Path
import argparse, hashlib, json, subprocess
import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel
import selected_voice_pipeline as p
from countdown_voices import quiet_word_boundaries, separated_number_words, sequence_matches, word_key

OUT=p.ROOT/'Verification/CountdownBoundaryRepair'
MODEL=Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-medium/snapshots/08e178d48790749d25932bbc082711ddcfdfbc4f'

def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--report',type=Path,required=True)
    parser.add_argument('--apply',action='store_true')
    args=parser.parse_args()
    manifest=json.loads((p.OUT/'manifest.json').read_text())
    report=json.loads(args.report.read_text())
    if args.apply:
        applied=[]
        for proposal in sorted(OUT.glob('*/*/proposal.json')):
            data=json.loads(proposal.read_text());lang=data['language'];character=data['character']
            folder=p.SOURCE/character/lang
            if data['sourceSHA256']!=p.sha(folder/'countdown.wav'):continue
            if any(manifest['clips'][k]['audioSHA256']!=v for k,v in data['originalHashes'].items()):continue
            previous=folder/'countdown-before-boundary-repair.json'
            if not previous.exists():previous.write_bytes((folder/'countdown.json').read_bytes())
            metadata=json.loads((folder/'countdown.json').read_text())
            metadata.update(boundaries=data['boundaries'],boundaryMethod='quiet-pauses')
            p.write(folder/'countdown.json',metadata)
            for key,encoding in data['encodings'].items():
                cue=key.split('/')[-1];base=proposal.parent
                (folder/f'{cue}.wav').write_bytes((base/f'{cue}.wav').read_bytes())
                (p.OUT/f'{key}.m4a').write_bytes((base/f'{cue}.m4a').read_bytes())
                entry=manifest['clips'][key];entry.update(encoding)
                entry['packagedCheckSHA256']=encoding['audioSHA256']
                index=5-int(cue);entry['bounds']=data['boundaries'][index:index+2]
                entry['hash']=hashlib.sha256((entry['hash']+encoding['rawSHA256']+'quiet-boundary-repair').encode()).hexdigest()
                report['clips'][key]={'sha256':encoding['audioSHA256'],'expected':entry['text'],'heardCountdown':data['heard'],'review':'encoded-countdown-match','recognizer':str(MODEL),'note':'Rechecked actual packaged clips after cutting at quiet pauses in the same source performance.'}
            p.write(p.OUT/'manifest.json',manifest);p.write(args.report,report);applied.append(f'{lang}/{character}')
        print('Applied boundary repairs:',applied,flush=True);return
    groups=set()
    for key,check in report['clips'].items():
        lang,character,cue=key.split('/')
        if cue.isdigit() and check.get('review')=='check' and manifest['clips'].get(key,{}).get('audioSHA256')==check.get('sha256'):groups.add((lang,character))
    asr=WhisperModel(str(MODEL),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    for lang,character in sorted(groups):
        source=p.SOURCE/character/lang/'countdown.wav';metadata=json.loads(source.with_suffix('.json').read_text())
        cached=OUT/lang/character/'proposal.json'
        if cached.exists() and json.loads(cached.read_text())['sourceSHA256']==p.sha(source):continue
        pcm,sr=sf.read(source);words=metadata.get('sourceWords',metadata['words'])
        aligned=separated_number_words(pcm,sr,lang,metadata.get('contextOrder',[5,4,3,2,1]))
        boundaries=quiet_word_boundaries(pcm,sr,aligned or words)
        if boundaries is None:print('NO QUIET CUTS',lang,character,flush=True);continue
        if len(words)==7:boundaries=boundaries[1:-1]
        if len(boundaries)!=6:continue
        dest=OUT/lang/character;dest.mkdir(parents=True,exist_ok=True)
        encodings={};chunks=[];original={}
        try:
            for n,a,b in zip([5,4,3,2,1],boundaries,boundaries[1:]):
                part=p.clean(pcm[int(a*sr):int(b*sr)],sr,leading=.02,trailing=.05)
                wav=dest/f'{n}.wav';aac=dest/f'{n}.m4a';sf.write(wav,part,sr,subtype='PCM_24')
                key=f'{lang}/{character}/{n}';encodings[key]=p.encode(wav,aac,short=True);original[key]=manifest['clips'][key]['audioSHA256']
                raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(aac),'-f','f32le','-ar','16000','-ac','1','-'])
                chunks.extend([np.frombuffer(raw,dtype=np.float32),np.zeros(2400,dtype=np.float32)])
        except ValueError as error:print('CUT REJECTED',lang,character,error,flush=True);continue
        samples=np.concatenate([np.zeros(4000,dtype=np.float32),*chunks,np.zeros(8000,dtype=np.float32)])
        segments,_=asr.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),word_timestamps=True,condition_on_previous_text=False,vad_filter=False,beam_size=3)
        heard=[w.word for segment in segments for w in segment.words if word_key(w.word)]
        valid=sequence_matches(heard,lang)
        print('RECUT',lang,character,valid,heard,flush=True)
        if valid:p.write(dest/'proposal.json',{'language':lang,'character':character,'sourceSHA256':p.sha(source),'originalHashes':original,'encodings':encodings,'boundaries':boundaries,'heard':heard})

if __name__=='__main__':main()
