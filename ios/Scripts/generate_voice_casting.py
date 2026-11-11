#!/usr/bin/env python3
"""Generate isolated, resumable casting auditions with two installed local models."""
import os
os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('TRANSFORMERS_OFFLINE', '1')
from pathlib import Path
import argparse, gc, hashlib, json, subprocess, time
import numpy as np
import soundfile as sf
import mlx.core as mx
from mlx_audio.tts.utils import load_model

ROOT = Path(__file__).resolve().parents[1] / 'Design/Voices/VoiceCasting'
MODELS = {'qwen': 'Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16', 'vox': 'VoxCPM2-bf16'}

def save(path, data):
    tmp = path.with_suffix('.tmp')
    tmp.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    tmp.replace(path)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--engine', choices=MODELS)
    parser.add_argument('--only', default='')
    args = parser.parse_args()
    plan = json.loads((ROOT / 'plan.json').read_text())
    output = ROOT / 'audio'
    output.mkdir(exist_ok=True)
    manifest_path = ROOT / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        'text': plan['text'], 'language': plan['language'],
        'provenance': 'Original synthetic voice designs; generated locally; no human voice references; no pitch shifting.', 'clips': {}}
    for engine in ([args.engine] if args.engine else MODELS):
        jobs = [c for ch in plan['characters'] for c in ch['candidates']
                if c['engine'] == engine and (not args.only or c['id'] in args.only.split(','))]
        pending = []
        for c in jobs:
            fingerprint = hashlib.sha256((plan['text'] + c['instruction'] + MODELS[engine]).encode()).hexdigest()
            if manifest['clips'].get(c['id'], {}).get('fingerprint') == fingerprint and (output / (c['id'] + '.m4a')).exists():
                continue
            pending.append((c, fingerprint))
        if not pending:
            continue
        print(f'Loading {engine}: {len(pending)} auditions', flush=True)
        model = load_model(str(Path.home() / 'Models/tts' / MODELS[engine]))
        if engine == 'vox':
            model.set_dtype(mx.float32)
        for c, fingerprint in pending:
            start = time.monotonic()
            seed = int(fingerprint[:8], 16)
            for attempt in range(3):
                mx.random.seed((seed + 1009 * attempt) & 0xffffffff)
                if engine == 'qwen':
                    results = model.generate_voice_design(text=plan['text'], instruct=c['instruction'],
                        language='English', max_tokens=350, temperature=0.85)
                else:
                    results = model.generate(text=plan['text'], instruct=c['instruction'], max_tokens=350)
                chunks = [np.asarray(r.audio).reshape(-1) for r in results]
                pcm = np.concatenate(chunks).astype(np.float32)
                sr = model.sample_rate
                active = np.flatnonzero(np.abs(pcm) > 10 ** (-45 / 20))
                if not len(active) or not np.isfinite(pcm).all():
                    print(f'{c["id"]}: invalid take, retrying', flush=True)
                    continue
                pcm = pcm[max(0, active[0] - int(sr * .06)):min(len(pcm), active[-1] + int(sr * .15))]
                duration = len(pcm) / sr
                if 3 <= duration <= 18:
                    break
                print(f'{c["id"]}: unexpected duration {duration:.2f}, retrying', flush=True)
            else:
                raise RuntimeError(f'No valid take for {c["id"]}')
            pcm *= min(3, .88 / max(float(np.abs(pcm).max()), 1e-8))
            wav = output / (c['id'] + '.wav')
            dest = output / (c['id'] + '.m4a')
            sf.write(wav, pcm, sr, subtype='PCM_16')
            # Loudness matching only: no pitch/speed transformations.
            subprocess.run(['ffmpeg', '-y', '-v', 'error', '-i', str(wav),
                '-af', 'loudnorm=I=-19:TP=-2:LRA=9', '-c:a', 'aac', '-b:a', '128k',
                '-ar', '24000', '-ac', '1', '-movflags', '+faststart', str(dest)], check=True)
            manifest['clips'][c['id']] = {'id': c['id'], 'model': MODELS[engine],
                'fingerprint': fingerprint, 'seed': (seed + 1009 * attempt) & 0xffffffff,
                'duration': round(duration, 3), 'sampleRate': sr, 'text': plan['text'],
                'instruction': c['instruction'], 'sha256': hashlib.sha256(dest.read_bytes()).hexdigest()}
            save(manifest_path, manifest)
            print(f'{c["id"]}: {duration:.1f}s audio / {time.monotonic()-start:.1f}s compute ({len(manifest["clips"])} archived auditions)', flush=True)
            mx.clear_cache()
        del model
        gc.collect()
        mx.clear_cache()

if __name__ == '__main__':
    main()
