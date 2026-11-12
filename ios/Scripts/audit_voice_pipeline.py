#!/usr/bin/env python3
"""Read-only local audit of casting provenance, source PCM and bundled encoding.
Run with ../SocraticMeowWoof/studio/.venv/bin/python. No models/network/uploads.
Signal metrics diagnose file/transcoding problems, not perceived voice quality.
"""
from pathlib import Path
import json,hashlib,subprocess,concurrent.futures,math
import numpy as np
import soundfile as sf
from scipy.signal import resample_poly,correlate
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'Verification/VoicePipelineAudit';OUT.mkdir(exist_ok=True)
CAST=ROOT/'Design/Voices/VoiceCasting';SOURCE=ROOT/'Design/Voices/ApprovedProduction';BUNDLE=ROOT/'Banke/Audio/Voices'
choices=json.loads((CAST/'approved-choices.json').read_text());manifest=json.loads((BUNDLE/'manifest.json').read_text())
def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()
def decode(p):
 r=subprocess.run(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','24000','-f','f32le','-'],capture_output=True)
 if r.returncode:raise RuntimeError(r.stderr.decode())
 return np.frombuffer(r.stdout,dtype=np.float32).copy()
def metric(a):
 return {'samples':len(a),'duration':round(len(a)/24000,4),'peak':round(float(np.max(np.abs(a))),6),'rmsDBFS':round(float(20*np.log10(max(1e-12,np.sqrt(np.mean(a.astype(float)**2))))),2),'samplesOverFullScale':int(np.sum(np.abs(a)>1)),'finite':bool(np.isfinite(a).all())}
def align_snr(a,b):
 # AAC/resampling can change delay. Align before measuring; do not label this MOS.
 corr=correlate(b,a,mode='full',method='fft');mid=len(a)-1;lo=max(0,mid-256);hi=min(len(corr),mid+257);lag=int(np.argmax(corr[lo:hi])+lo-mid)
 if lag>=0:b=b[lag:]
 else:a=a[-lag:]
 n=min(len(a),len(b));a=a[:n].astype(float);b=b[:n].astype(float)
 gain=float(np.dot(a,b)/max(1e-12,np.dot(a,a)));err=b-a*gain
 return {'delaySamples':lag,'gainDB':round(20*math.log10(max(abs(gain),1e-12)),3),'alignedSNRdB':round(10*math.log10(max(1e-12,float(np.dot(a*gain,a*gain)))/max(1e-12,float(np.dot(err,err)))),2)}
refs={}
for c,v in choices['selectedVoices'].items():
 aud=CAST/'audio'/f'{v["voice"]}.m4a';ref=SOURCE/c/'reference.wav';pcm,sr=sf.read(ref,dtype='float32');decoded=decode(aud)
 if sr!=24000:pcm=resample_poly(pcm,24000//math.gcd(sr,24000),sr//math.gcd(sr,24000))
 refs[c]={'voice':v['voice'],'auditionModel':v['model'],'productionModel':manifest['model'],'auditionHashMatches':sha(aud)==v['sha256'],'referenceHash':sha(ref),'referencePCMEqualsDecodedAudition':len(pcm)==len(decoded) and bool(np.allclose(pcm,decoded,atol=1/32768+1e-7,rtol=0)), 'audition':metric(decoded),'reference':metric(pcm)}
print('Audition/reference checks complete',flush=True)
def inspect(item):
 key,entry=item;lang,c,cue=key.split('/');dest=BUNDLE/f'{key}.m4a';wav=SOURCE/c/lang/f'{cue}.wav';raw,sr=sf.read(wav,dtype='float32')
 if raw.ndim>1:raw=raw.mean(axis=1)
 if sr!=24000:raw=resample_poly(raw,24000//math.gcd(sr,24000),sr//math.gcd(sr,24000))
 result={'key':key,'voice':entry.get('castingVoice'),'bundleHashMatches':sha(dest)==entry['audioSHA256'],'raw':metric(raw),'sourceSampleRate':sr,'timeCompression':round(entry.get('sourceDuration',entry['duration'])/entry['duration'],3),'instructions':entry.get('instruction')}
 try:
  encoded=decode(dest);result['encoded']=metric(encoded)
  if result['timeCompression']<1.025:result['encodingComparison']=align_snr(raw,encoded)
 except Exception as e:result['decodeError']=str(e)
 return result
rows=[]
with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:
 for i,row in enumerate(pool.map(inspect,manifest['clips'].items()),1):
  rows.append(row)
  if i%200==0:print(f'{i}/{len(manifest["clips"])} clips checked',flush=True)
snrs=[r['encodingComparison']['alignedSNRdB'] for r in rows if 'encodingComparison' in r]
summary={'clips':len(rows),'decodeFailures':[r['key'] for r in rows if 'decodeError' in r],'hashMismatches':[r['key'] for r in rows if not r['bundleHashMatches']],'rawFullScaleClips':[r['key'] for r in rows if r['raw']['samplesOverFullScale']],'encodedFullScaleClips':[r['key'] for r in rows if r.get('encoded',{}).get('samplesOverFullScale',0)],'timeCompressedCount':sum(r['timeCompression']>1.025 for r in rows),'encodingSNRPercentiles':{str(p):round(float(np.percentile(snrs,p)),2) for p in [0,10,50,90,100]},'limits':'Signal metrics do not establish voice identity fidelity, intelligibility, or perceived quality. No human listening approval is inferred.'}
report={'references':refs,'summary':summary,'clips':rows};(OUT/'audit.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n');print(json.dumps(summary),flush=True)
