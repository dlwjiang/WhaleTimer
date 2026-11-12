from pathlib import Path
import json,subprocess,tempfile,math,hashlib
import numpy as np
from scipy.signal import correlate
root=Path(__file__).resolve().parents[1];audit=json.loads((root/'Verification/VoicePipelineAudit/audit.json').read_text())
keys=[f'en/{c}/{cue}' for c in audit['references'] for cue in ['greeting','poke']]
keys+= [r['key'] for r in sorted((r for r in audit['clips'] if 'encodingComparison' in r),key=lambda r:r['encodingComparison']['alignedSNRdB'])[:12]]
def decode(p):return np.frombuffer(subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-ac','1','-ar','24000','-f','f32le','-']),dtype=np.float32)
def snr(a,b):
 corr=correlate(b,a,method='fft');mid=len(a)-1;lo=mid-256;lag=int(np.argmax(corr[lo:mid+257])+lo-mid)
 if lag>=0:b=b[lag:]
 else:a=a[-lag:]
 n=min(len(a),len(b));a=a[:n].astype(float);b=b[:n].astype(float);g=np.dot(a,b)/np.dot(a,a)
 return round(float(10*np.log10(np.sum((a*g)**2)/np.sum((b-a*g)**2))),2)
rows=[]
with tempfile.TemporaryDirectory() as tmp:
 for k in keys:
  l,c,q=k.split('/');wav=root/'Design/Voices/ApprovedProduction'/c/l/(q+'.wav');bundle=root/'Banke/Audio/Voices'/(k+'.m4a');raw=decode(wav);out={}
  for rate in ['64k','128k']:
   p=Path(tmp)/(rate+'.m4a');subprocess.run(['ffmpeg','-v','error','-y','-i',str(wav),'-c:a','aac','-b:a',rate,'-ar','24000','-ac','1','-movflags','+faststart',str(p)],check=True)
   pcm=decode(p);out[rate]={'snrDB':snr(raw,pcm),'bytes':p.stat().st_size}
   if rate=='64k':out['reencoded64kMatchesBundledFile']=hashlib.sha256(p.read_bytes()).hexdigest()==hashlib.sha256(bundle.read_bytes()).hexdigest()
  rows.append({'key':k,**out})
report={'method':'Same saved production WAV encoded at 64k and 128k; decode and align against FFmpeg-resampled raw source. No new speech generation. No app asset replacement. SNR is not a perceptual quality score.','samples':rows}
(root/'Verification/VoicePipelineAudit/encoding-experiment.json').write_text(json.dumps(report,indent=2)+'\n')
print('Samples',len(rows),'64k reproduction matches',sum(r['reencoded64kMatchesBundledFile'] for r in rows));print('Median SNR 64k',np.median([r['64k']['snrDB'] for r in rows]),'128k',np.median([r['128k']['snrDB'] for r in rows]));print(json.dumps(rows[:2]))
