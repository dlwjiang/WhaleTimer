#!/usr/bin/env python3
"""Original-engine voice generation and lossless staging. No live-bundle writes.
A reviewed pilot selects each character's generation route. This module never
silently changes engines, redesigns references, or time-stretches a recording.
"""
import os
os.environ.setdefault('HF_HUB_OFFLINE','1')
os.environ.setdefault('TRANSFORMERS_OFFLINE','1')
from pathlib import Path
import argparse,datetime,gc,hashlib,json,subprocess,tempfile,time
import numpy as np
import soundfile as sf
from countdown_voices import LANGUAGES,recognize,number_words,quiet_word_boundaries,separated_number_words,sequence_matches,word_key
from selected_voice_contract import validate_review, expected_model, reference_generation_options, REFERENCE_LANGUAGES
ROOT=Path(__file__).resolve().parents[1]
CAST=ROOT/'Design/Voices/VoiceCasting'
SOURCE=ROOT/'Design/Voices/SelectedEngineProduction'
OUT=ROOT/'Verification/SelectedEngineVoices'
PILOT=ROOT/'Verification/SelectedEnginePilot'
REVISION='selected-engine-v2'
PHRASES=['go','pause','resume','reset','focusComplete','breakComplete','greeting','poke']
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def write(p,d):
 p.parent.mkdir(parents=True,exist_ok=True);tmp=p.with_suffix(p.suffix+'.tmp');tmp.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');tmp.replace(p)
def load_review(path,characters):
 review=json.loads(path.read_text())
 return validate_review(review,characters),review

def cached(manifest,key,fingerprint):
 entry=manifest['clips'].get(key,{})
 lang,character,cue=key.split('/')
 encoded=OUT/f'{key}.m4a';raw=SOURCE/character/lang/f'{cue}.wav'
 return (entry.get('hash')==fingerprint and encoded.exists() and raw.exists()
         and sha(encoded)==entry.get('audioSHA256') and sha(raw)==entry.get('rawSHA256'))

def clean(pcm,sr,leading=.06,trailing=.12):
 pcm=np.asarray(pcm,dtype=np.float32).reshape(-1)
 if not len(pcm) or not np.isfinite(pcm).all():raise ValueError('Invalid waveform')
 active=np.flatnonzero(np.abs(pcm)>10**(-45/20))
 if not len(active):raise ValueError('Silent waveform')
 pcm=pcm[max(0,active[0]-int(sr*leading)):min(len(pcm),active[-1]+int(sr*trailing))]
 pcm*=min(3,.88/max(float(np.abs(pcm).max()),1e-8))
 return pcm

def encode(wav,dest,short=False):
 info=sf.info(wav);duration=info.frames/info.samplerate
 if duration<.12 or duration>(.88 if short else 12):raise ValueError(f'Regenerate at a natural pace; duration {duration:.3f}s is outside limits')
 dest.parent.mkdir(parents=True,exist_ok=True)
 with tempfile.TemporaryDirectory(prefix='banke-selected-encode-') as td:
  staged=Path(td)/'voice.m4a'
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-af','loudnorm=I=-19:TP=-3:LRA=9','-c:a','aac','-b:a','128k','-ar','24000','-ac','1','-movflags','+faststart',str(staged)],check=True)
  raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(staged),'-f','f32le','-ar','24000','-ac','1','-']);pcm=np.frombuffer(raw,dtype=np.float32)
  peak=float(np.abs(pcm).max())
  if not np.isfinite(pcm).all() or peak>.95:raise ValueError(f'Encoded headroom failed: {peak}')
  actual=len(pcm)/24000
  if abs(actual-duration)>1024/24000+.001:raise ValueError('Encoding changed playback duration')
  dest.write_bytes(staged.read_bytes())
 return {'duration':round(actual,4),'sourceDuration':round(duration,4),'bytes':dest.stat().st_size,'audioSHA256':sha(dest),'rawSHA256':sha(wav),'encoding':{'codec':'aac','bitrateTarget':128000,'sampleRate':24000,'channels':1,'decodedPeak':round(peak,6),'speed':1,'pitch':1,'loudnessTarget':-19,'truePeakTarget':-3}}

def check_packaged_countdown(parts,sr,language):
 # The actual encoded cuts must still say exactly 5–1. Source ASR alone can
 # miss a late boundary that includes part of a neighboring number.
 import countdown_voices as counter
 chunks=[];hashes=[]
 with tempfile.TemporaryDirectory(prefix='banke-countdown-check-') as td:
  for i,part in enumerate(parts):
   wav=Path(td)/f'{i}.wav';aac=wav.with_suffix('.m4a')
   sf.write(wav,part,sr,subtype='PCM_24');encoded=encode(wav,aac,True)
   hashes.append(encoded['audioSHA256'])
   raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(aac),'-f','f32le','-ar','16000','-ac','1','-'])
   chunks.extend([np.frombuffer(raw,dtype=np.float32),np.zeros(2400,dtype=np.float32)])
 samples=np.concatenate([np.zeros(4000,dtype=np.float32),*chunks,np.zeros(8000,dtype=np.float32)])
 segments,_=counter.ASR.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(language,language),word_timestamps=True,condition_on_previous_text=False,vad_filter=False,beam_size=3)
 heard=[w.word for segment in segments for w in segment.words if word_key(w.word)]
 return sequence_matches(heard,language),heard,hashes

class Engine:
 def __init__(self,base_model):self.base_model=base_model;self.model=None;self.path=None;self.last_instruction=None
 def prepare(self,selection,route):
  import mlx.core as mx
  from mlx_audio.tts.utils import load_model
  qwen=selection['model'].startswith('Qwen')
  path=self.base_model if qwen and route=='reference' else Path.home()/'Models/tts'/selection['model']
  if path!=self.path:
   if self.model is not None:del self.model;gc.collect();mx.clear_cache()
   if not path.exists():raise ValueError(f'Model not installed: {path}')
   print('Loading',path,flush=True);self.model=load_model(str(path));self.path=path
   if not qwen:self.model.set_dtype(mx.float32)
  return qwen
 def render(self,text,language,selection,route,seed,direction=None):
  import mlx.core as mx
  qwen=self.prepare(selection,route);mx.random.seed(seed);self.last_instruction=None
  kwargs={'text':text,'max_tokens':350}
  if route=='direct':
   instruction=selection['instruction'].replace('supplied English words',f'supplied {LANGUAGES[language]} words').replace('supplied English text',f'supplied {LANGUAGES[language]} text')
   if language!='en':instruction+=f' Speak in {LANGUAGES[language]}.'
   if direction:
    # Change counting cadence only; keep pitch, resonance, character and gender.
    if direction.startswith(('Count quickly', 'Say each number')):
     instruction=instruction.replace('slow cozy pauses','crisp little syllables').replace('shy unhurried pauses','shy, brief pauses').replace('smooth floating phrases','short, lightly floating syllables')
    instruction+=' '+direction
   self.last_instruction=instruction
   kwargs['instruct']=instruction
   results=self.model.generate_voice_design(**kwargs,language={'zh-Hans':'Chinese','pt-BR':'Portuguese'}.get(language,LANGUAGES[language]),temperature=.85) if qwen else self.model.generate(**kwargs)
  else:
   reference=CAST/'audio'/f'{selection["voice"]}.wav'
   transcript=json.loads((CAST/'approved-choices.json').read_text())['auditionText']
   if qwen:
    import inspect
    if 'lang_code' not in inspect.signature(self.model.generate).parameters:raise RuntimeError('Qwen wrapper language API changed; refusing implicit language fallback')
    results=self.model.generate(**kwargs,**reference_generation_options(language,reference,transcript))
   else:
    # Continuation uses the original engine's own lossless audition + transcript.
    # No cross-engine reference cloning and no replacement designed voice.
    results=self.model.generate(**kwargs,prompt_audio=str(reference),prompt_text=transcript+' ')
  pcm=clean(np.concatenate([np.asarray(r.audio).reshape(-1) for r in results]),self.model.sample_rate)
  mx.clear_cache();return pcm,self.model.sample_rate

def main():
 parser=argparse.ArgumentParser();parser.add_argument('--review',type=Path,required=True);parser.add_argument('--characters',default='mochi,pip,pebble,jun,bean,maple,luna,atlas,wisp,nova,orbit,comet');parser.add_argument('--languages',default=','.join(LANGUAGES));parser.add_argument('--only',default='');parser.add_argument('--retake',type=int,default=0);parser.add_argument('--base-model',type=Path,default=Path('/tmp/banke-models/Qwen3-TTS-12Hz-1.7B-Base-bf16'));parser.add_argument('--countdown-recognizer',choices=['small','medium'],default='small');parser.add_argument('--jobs',type=Path,help='JSON entries containing exact character/language pairs');parser.add_argument('--countdown-context',action='store_true',help='Render six through zero, retaining only the interior five through one');parser.add_argument('--korean-counting',choices=['sino','native'],default='sino',help='Equivalent Korean numeral system for countdown recordings');parser.add_argument('--strict-countdown-boundaries',action='store_true',help='Require inter-word silence around every cut');args=parser.parse_args()
 chars=args.characters.split(',');langs=args.languages.split(',');only=set(args.only.split(',')) if args.only else set(PHRASES+list('12345'))
 if not set(langs)<=set(LANGUAGES) or not only<=set(PHRASES+list('12345')):parser.error('Unknown language or cue')
 if args.retake<0 or (args.retake and not args.only):parser.error('Retakes require explicit cues and a nonnegative take number')
 jobs=None
 if args.jobs:
  jobs={(v['character'],v['language']) for v in json.loads(args.jobs.read_text())['entries']}
  if not jobs<={(c,l) for c in chars for l in langs}:parser.error('Job list contains an unknown or excluded character/language pair')
 if args.countdown_recognizer=='medium' and only&set('12345'):
  import countdown_voices as counter
  from faster_whisper import WhisperModel
  counter.ASR=WhisperModel(str(Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-medium/snapshots/08e178d48790749d25932bbc082711ddcfdfbc4f'),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
 choices,review=load_review(args.review,chars);auditions=json.loads((CAST/'manifest.json').read_text())['clips'];lines=json.loads((ROOT/'Localization/voice-lines.json').read_text())
 manifest_path=OUT/'manifest.json';manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'model':'per-character original engine','aliases':{'zh-Hant':'zh-Hans'},'clips':{}}
 write(SOURCE/'routes.json',review)
 manifest['casting']={'pipelineRevision':REVISION,'choicesSHA256':sha(CAST/'approved-choices.json'),'selectedVoices':choices['selectedVoices'],'reviewSHA256':sha(SOURCE/'routes.json'),'method':'Reviewed original-engine route per character; original lossless audition; no time or pitch transforms.'}
 manifest['productionReview']=review;write(manifest_path,manifest);engine=Engine(args.base_model);failures=[]
 for c in sorted(chars,key=lambda c:(expected_model(choices['selectedVoices'][c],review['routes'][c]['route']),c)):
  selection=choices['selectedVoices'][c];route=review['routes'][c]['route'];ref=CAST/'audio'/f'{selection["voice"]}.wav'
  if sha(CAST/'audio'/f'{selection["voice"]}.m4a')!=selection['sha256']:raise ValueError(f'{c}: audition changed')
  for lang in langs:
   if jobs is not None and (c,lang) not in jobs:continue
   folder=SOURCE/c/lang;folder.mkdir(parents=True,exist_ok=True)
   common={'castingVoice':selection['voice'],'auditionSHA256':selection['sha256'],'auditionWAVSHA256':sha(ref),'route':route,'pipelineRevision':REVISION,'pilotSHA256':review['routes'][c]['pilotSHA256']}
   if selection['model'].startswith('Qwen') and route=='reference':common['languageConditioning']=REFERENCE_LANGUAGES[lang]
   # Include review and complete synthesis configuration in resumable identity.
   context=json.dumps([REVISION,selection,route,common['pilotSHA256'],lang,args.retake],sort_keys=True)
   if selection['model'].startswith('Qwen') and route=='reference' and lang!='en':context+='explicit-lang-code:'+REFERENCE_LANGUAGES[lang]
   def store(cue,pcm,sr,text,seed,fingerprint,extra=None):
    wav=folder/f'{cue}.wav';sf.write(wav,pcm,sr,subtype='PCM_24');dest=OUT/lang/c/f'{cue}.m4a'
    entry={**common,**encode(wav,dest,cue.isdigit()),'text':text,'seed':seed,'hash':fingerprint,'model':engine.path.name,'sourceSampleRate':sr,**(extra or {})}
    if entry.get('packagedCheckSHA256',entry['audioSHA256'])!=entry['audioSHA256']:raise ValueError('Packaged countdown differs from its checked audio')
    manifest['clips'][f'{lang}/{c}/{cue}']=entry;write(manifest_path,manifest)
   if only&set('12345'):
    direction='Say each number crisply and briefly, with a distinct quiet pause between numbers. Keep your character voice. Do not stretch vowels, add noises, or sing.' if args.retake else None
    order=[6,5,4,3,2,1,0] if args.countdown_context else [5,4,3,2,1]
    texts=[lines[lang][str(n)] if 1<=n<=5 else number_words(lang,n)[0] for n in order]
    if lang=='ko' and args.korean_counting=='native':texts=[{6:'여섯',5:'다섯',4:'넷',3:'셋',2:'둘',1:'하나',0:'영'}[n] for n in order]
    text=' '.join(texts)
    if args.retake:text=('、' if lang=='ja' else ', ').join(t.strip(' .!。、！？') for t in texts)+'.'
    fingerprint=hashlib.sha256((context+text+'countdown-v2'+str(args.strict_countdown_boundaries)).encode()).hexdigest();keys=[f'{lang}/{c}/{n}' for n in [5,4,3,2,1]]
    if not all(cached(manifest,k,fingerprint) for k in keys):
     ok=False
     for attempt in range(6):
      seed=(auditions[selection['voice']]['seed']+args.retake*1000003+attempt*1009)&0xffffffff
      pcm,sr=engine.render(text,lang,selection,route,seed,direction=direction);words,valid=recognize(pcm,sr,lang,order)
      if not valid:print('COUNTDOWN words rejected',c,lang,words,flush=True);continue
      boundaries=[max(0,words[0]['start']-.08)]+[(a['end']+b['start'])/2 for a,b in zip(words,words[1:])]+[len(pcm)/sr]
      if args.strict_countdown_boundaries:
       aligned=separated_number_words(pcm,sr,lang,order)
       boundaries=quiet_word_boundaries(pcm,sr,aligned or words)
       if boundaries is None:print('COUNTDOWN lacks clear pauses',c,lang,flush=True);continue
      source_words=words
      if args.countdown_context:
       # Only complete interior words ship; six and zero remain in the source.
       boundaries=boundaries[1:-1];words=words[1:-1]
      parts=[clean(pcm[int(a*sr):int(b*sr)],sr,leading=.02,trailing=.05) for a,b in zip(boundaries,boundaries[1:])]
      # A close take may fit by removing optional silence padding alone. Never
      # shorten the active word or alter its sample rate to meet the beat.
      parts=[clean(pcm[int(a*sr):int(b*sr)],sr,leading=.01,trailing=.02) if len(part)/sr>.88 else part for part,a,b in zip(parts,boundaries,boundaries[1:])]
      if any(not .12<=len(p)/sr<=.88 for p in parts):
       print('COUNTDOWN natural duration rejected',c,lang,[round(len(p)/sr,2) for p in parts],flush=True);continue
      packaged_ok,heard,checked_hashes=check_packaged_countdown(parts,sr,lang)
      if not packaged_ok:print('COUNTDOWN encoded words rejected',c,lang,heard,flush=True);continue
      sf.write(folder/'countdown.wav',pcm,sr,subtype='PCM_24');source_sha=sha(folder/'countdown.wav')
      metadata={'method':'natural-countdown-v2','recognizer':args.countdown_recognizer,'direction':direction,'boundaryMethod':'quiet-pauses' if args.strict_countdown_boundaries else 'word-timestamps','contextOrder':order,'synthesisInstruction':engine.last_instruction,'sourceWords':source_words,'text':text,'words':words,'boundaries':boundaries,'sourceSHA256':source_sha,'seed':seed,'speed':1,'pitch':1};write(folder/'countdown.json',metadata)
      for n,part,a,b,digest in zip([5,4,3,2,1],parts,boundaries,boundaries[1:],checked_hashes):store(str(n),part,sr,lines[lang][str(n)],seed,fingerprint,{'method':'natural-countdown-v2','bounds':[a,b],'countdownSHA256':source_sha,'spokenText':dict(zip(order,texts))[n],'packagedCheckSHA256':digest})
      ok=True;print('COUNTDOWN',lang,c,'natural timing verified',flush=True);break
     if not ok:
      failures.append({'character':c,'language':lang,'cue':'countdown','reason':'No natural, correctly spoken countdown within six attempts'})
      print('FAILED COUNTDOWN',lang,c,flush=True)
   for cue in PHRASES:
    if cue not in only:continue
    text=lines[lang][c if cue=='greeting' else cue];fingerprint=hashlib.sha256((context+text+cue).encode()).hexdigest();key=f'{lang}/{c}/{cue}'
    if cached(manifest,key,fingerprint):continue
    seed=(auditions[selection['voice']]['seed']+args.retake*1000003)&0xffffffff
    try:
     pcm,sr=engine.render(text,lang,selection,route,seed);store(cue,pcm,sr,text,seed,fingerprint);print(key,'staged',round(len(pcm)/sr,2),'s',flush=True)
    except ValueError as error:
     failures.append({'character':c,'language':lang,'cue':cue,'reason':str(error)});print('FAILED',key,str(error),flush=True)
 write(OUT/'last-run.json',{'characters':chars,'languages':langs,'cues':sorted(only),'failures':failures,'finishedAt':datetime.datetime.now().isoformat()})
 print('Staged clips:',len(manifest['clips']),'failures:',len(failures),flush=True)
 if failures:raise SystemExit(1)
if __name__=='__main__':main()
