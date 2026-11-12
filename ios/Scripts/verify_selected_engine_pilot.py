#!/usr/bin/env python3
"""Local wording and waveform diagnostics; explicitly not listening approval."""
from pathlib import Path
import json,subprocess,hashlib
from difflib import SequenceMatcher
import numpy as np
from faster_whisper import WhisperModel
from verify_voices import MODEL,normalize
ROOT=Path(__file__).resolve().parents[1]/'Verification/SelectedEnginePilot'
m=json.loads((ROOT/'manifest.json').read_text());out=ROOT/'checks.json';checks=json.loads(out.read_text()) if out.exists() else {'method':'Local Whisper small and PCM checks; no perceptual approval inferred','clips':{}}
asr=WhisperModel(str(MODEL),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
for key,entry in m['clips'].items():
 p=ROOT/f'{key}.m4a';digest=hashlib.sha256(p.read_bytes()).hexdigest()
 if checks['clips'].get(key,{}).get('sha256')==digest:continue
 raw=subprocess.check_output(['ffmpeg','-v','error','-i',str(p),'-f','f32le','-ar','16000','-ac','1','-']);pcm=np.frombuffer(raw,dtype=np.float32)
 segs,_=asr.transcribe(np.pad(pcm,(4000,8000)),language='en',condition_on_previous_text=False,vad_filter=False,beam_size=3)
 heard=''.join(s.text for s in segs).strip();score=SequenceMatcher(None,normalize(entry['text'],'en'),normalize(heard,'en')).ratio()
 checks['clips'][key]={'sha256':digest,'text':entry['text'],'heard':heard,'wordingScore':round(score,3),'finite':bool(np.isfinite(pcm).all()),'decodedPeak':round(float(np.abs(pcm).max()),5),'status':'words-match' if score>.95 else 'check-words'}
 temp=out.with_suffix('.tmp');temp.write_text(json.dumps(checks,ensure_ascii=False,indent=2)+'\n');temp.replace(out);print(key,round(score,3),heard,flush=True)
