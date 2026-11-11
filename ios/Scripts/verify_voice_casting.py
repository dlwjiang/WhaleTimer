#!/usr/bin/env python3
"""Local wording/decoding diagnostics only; the user judges acting and cuteness."""
from pathlib import Path
from difflib import SequenceMatcher
import hashlib, json, subprocess
import numpy as np
from faster_whisper import WhisperModel

ROOT = Path(__file__).resolve().parents[1] / 'Design/Voices/VoiceCasting'
MODEL = Path.home() / '.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'
report_path = ROOT / 'transcripts.json'
report = json.loads(report_path.read_text()) if report_path.exists() else {
    'method': 'Local faster-whisper small/int8, wording diagnostics; not acting or cuteness approval.', 'clips': {}}
model = WhisperModel(str(MODEL), device='cpu', compute_type='int8', local_files_only=True, cpu_threads=4)
manifest = json.loads((ROOT / 'manifest.json').read_text())
normalize = lambda s: ''.join(c for c in s.lower() if c.isalnum())
for key, entry in manifest['clips'].items():
    path = ROOT / 'audio' / (key + '.m4a')
    digest = hashlib.sha256(path.read_bytes()).hexdigest()
    if report['clips'].get(key, {}).get('sha256') == digest:
        continue
    raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(path), '-f', 'f32le', '-ar', '16000', '-ac', '1', '-'])
    samples = np.frombuffer(raw, dtype=np.float32)
    if not np.isfinite(samples).all() or np.max(np.abs(samples)) < .01:
        raise ValueError(f'Invalid audio: {key}')
    segments, _ = model.transcribe(np.pad(samples, (4000, 8000)), language='en',
        condition_on_previous_text=False, vad_filter=False, beam_size=3)
    heard = ' '.join(s.text.strip() for s in segments)
    score = SequenceMatcher(None, normalize(entry['text']), normalize(heard)).ratio()
    report['clips'][key] = {'sha256': digest, 'heard': heard, 'similarity': round(score, 3),
        'review': 'transcript-match' if score >= .88 else 'check'}
    temp = report_path.with_suffix('.tmp')
    temp.write_text(json.dumps(report, indent=2) + '\n')
    temp.replace(report_path)
    print(key, report['clips'][key]['review'], heard, flush=True)
