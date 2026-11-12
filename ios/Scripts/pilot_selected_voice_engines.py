#!/usr/bin/env python3
"""Stage original-engine pilots; never overwrite audition choices or app audio."""
import os
os.environ['HF_HUB_OFFLINE']='1';os.environ['TRANSFORMERS_OFFLINE']='1'
from pathlib import Path
import argparse,json,hashlib,time,gc,subprocess
import numpy as np
import soundfile as sf
import mlx.core as mx
from mlx_audio.tts.utils import load_model
ROOT=Path(__file__).resolve().parents[1]
CAST=ROOT/'Design/Voices/VoiceCasting'
OUT=ROOT/'Verification/SelectedEnginePilot'
TEXT="Oh! You found me! Let's begin. Take a breath. I'll wait."
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def save(p,d):
 tmp=p.with_suffix('.tmp');tmp.write_text(json.dumps(d,ensure_ascii=False,indent=2)+'\n');tmp.replace(p)
def main():
 parser=argparse.ArgumentParser();parser.add_argument('--route',choices=['direct','reference'],required=True);parser.add_argument('--characters',default='mochi,pip,pebble,jun,bean,maple,luna,atlas,wisp,nova,orbit,comet');parser.add_argument('--base-model',type=Path,default=Path('/tmp/banke-models/Qwen3-TTS-12Hz-1.7B-Base-bf16'));args=parser.parse_args()
 choices=json.loads((CAST/'approved-choices.json').read_text());auditions=json.loads((CAST/'manifest.json').read_text())['clips']
 OUT.mkdir(parents=True,exist_ok=True);manifest_path=OUT/'manifest.json';manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'status':'pilot-needs-listening','text':TEXT,'clips':{}}
 active=None;model=None
 for c in args.characters.split(','):
  selected=choices['selectedVoices'][c];audition=auditions[selected['voice']];qwen=selected['model'].startswith('Qwen');key=f'{c}/{args.route}'
  path=(args.base_model if qwen and args.route=='reference' else Path.home()/'Models/tts'/selected['model'])
  fingerprint=hashlib.sha256(json.dumps([TEXT,args.route,selected,audition['seed'],str(path)],sort_keys=True).encode()).hexdigest()
  folder=OUT/c;folder.mkdir(exist_ok=True);wav=folder/f'{args.route}.wav';aac=folder/f'{args.route}.m4a'
  if manifest['clips'].get(key,{}).get('fingerprint')==fingerprint and aac.exists():continue
  if active!=path:
   if model is not None:del model;gc.collect();mx.clear_cache()
   print('Loading',path,flush=True);model=load_model(str(path));active=path
   if not qwen:model.set_dtype(mx.float32)
  seed=audition['seed'];mx.random.seed(seed);started=time.monotonic()
  kwargs={'text':TEXT,'max_tokens':350}
  if args.route=='direct':
   kwargs['instruct']=audition['instruction']
   results=model.generate_voice_design(**kwargs,language='English',temperature=0.85) if qwen else model.generate(**kwargs)
  else:
   # Use the original lossless audition performance, never a re-generated reference.
   reference=CAST/'audio'/f'{selected["voice"]}.wav'
   if not reference.exists():raise RuntimeError(f'Missing original lossless audition: {reference}')
   if qwen:results=model.generate(**kwargs,ref_audio=str(reference),ref_text=choices['auditionText'],lang_code='auto',temperature=0.85)
   else:results=model.generate(**kwargs,prompt_audio=str(reference),prompt_text=choices['auditionText']+' ')
  pcm=np.concatenate([np.asarray(r.audio).reshape(-1) for r in results]).astype(np.float32);sr=model.sample_rate
  if not len(pcm) or not np.isfinite(pcm).all():raise ValueError('Invalid waveform')
  active_samples=np.flatnonzero(np.abs(pcm)>10**(-45/20))
  if not len(active_samples):raise ValueError('Silent waveform')
  pcm=pcm[max(0,active_samples[0]-int(sr*.06)):min(len(pcm),active_samples[-1]+int(sr*.15))]
  if not 1<=len(pcm)/sr<20:raise ValueError(f'Unexpected duration {len(pcm)/sr}')
  # Preserve a lossless source. Audition-matched loudness and encoding only.
  pcm*=min(3,.88/max(float(np.abs(pcm).max()),1e-8));sf.write(wav,pcm,sr,subtype='PCM_24')
  subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-af','loudnorm=I=-19:TP=-2:LRA=9','-c:a','aac','-b:a','128k','-ar','24000','-ac','1','-movflags','+faststart',str(aac)],check=True)
  manifest['clips'][key]={'character':c,'route':args.route,'voice':selected['voice'],'auditionSHA256':selected['sha256'],'model':path.name,'seed':seed,'text':TEXT,'fingerprint':fingerprint,'rawSHA256':sha(wav),'audioSHA256':sha(aac),'seconds':round(len(pcm)/sr,3),'sampleRate':sr,'speed':1,'pitch':1,'status':'needs-listening'}
  save(manifest_path,manifest);print(key,round(len(pcm)/sr,2),'sec audio;',round(time.monotonic()-started,1),'sec generation',flush=True);mx.clear_cache()
if __name__=='__main__':main()
