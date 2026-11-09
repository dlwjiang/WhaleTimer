#!/usr/bin/env python3
"""Re-split reviewed source takes at quiet gaps. Run only after generation finishes."""
from pathlib import Path
import hashlib
import json
import subprocess
import tempfile

import numpy as np
import soundfile as sf

from countdown_voices import recognize

ROOT = Path(__file__).resolve().parents[1]
VOICES = ROOT / 'Banke/Audio/Voices'


def main():
    corrections = json.loads((ROOT / 'Design/Voices/boundary-corrections.json').read_text())
    manifest_path = VOICES / 'manifest.json'
    manifest = json.loads(manifest_path.read_text())
    for key, correction in corrections.items():
        language, character = key.split('/')
        source = ROOT / 'Design/Voices' / character / language
        wav = source / 'countdown.wav'
        assert hashlib.sha256(wav.read_bytes()).hexdigest() == correction['sourceSHA256'], key
        if all(manifest['clips'][f'{key}/{n}'].get('boundaryCorrection') == correction['sourceSHA256']
               for n in [5, 4, 3, 2, 1]):
            continue
        pcm, sr = sf.read(wav)
        bounds = correction['boundaries']
        assert len(bounds) == 6 and all(a < b for a, b in zip(bounds, bounds[1:]))
        assert 0 <= bounds[0] and bounds[-1] <= len(pcm) / sr
        with tempfile.TemporaryDirectory(prefix='banke-countdown-') as staging:
            staging = Path(staging)
            entries, sequence = {}, []
            for n, start, end in zip([5, 4, 3, 2, 1], bounds, bounds[1:]):
                part = pcm[int(start * sr):int(end * sr)].copy()
                active = np.flatnonzero(np.abs(part) > 10 ** (-45 / 20))
                assert len(active), (key, n)
                part = part[max(0, active[0] - int(sr * .04)):min(len(part), active[-1] + int(sr * .07))]
                part *= min(4, .88 / max(np.abs(part)))
                duration = len(part) / sr
                assert .12 <= duration <= 1.5, (key, n, duration)
                sf.write(staging / f'{n}.wav', part, sr, subtype='PCM_16')
                dest = staging / f'{n}.m4a'
                command = ['ffmpeg', '-v', 'error', '-y', '-i', str(staging / f'{n}.wav')]
                if duration > .78:
                    command += ['-af', f'atempo={duration / .76:.6f}']
                subprocess.run(command + ['-c:a', 'aac', '-b:a', '64k', '-ar', '24000', '-ac', '1',
                                          '-movflags', '+faststart', str(dest)], check=True)
                raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(dest),
                                               '-f', 'f32le', '-ar', '16000', '-ac', '1', '-'])
                decoded = np.frombuffer(raw, dtype=np.float32)
                sequence.append(np.pad(decoded, (0, max(0, 16000 - len(decoded)))))
                entries[n] = {'bounds': [start, end], 'duration': round(.76 if duration > .78 else duration, 3),
                              'sourceDuration': round(duration, 3), 'bytes': dest.stat().st_size,
                              'boundaryCorrection': correction['sourceSHA256']}
            words, valid = recognize(np.concatenate(sequence), 16000, language)
            assert valid, (key, words)  # Never install a repair that fails the encoded sequence check.
            for n in entries:
                (staging / f'{n}.m4a').replace(VOICES / key / f'{n}.m4a')
                (staging / f'{n}.wav').replace(source / f'{n}.wav')
                manifest['clips'][f'{key}/{n}'].update(entries[n])
            metadata_path = source / 'countdown.json'
            metadata = json.loads(metadata_path.read_text())
            metadata['originalBoundaries'] = metadata['boundaries']
            metadata['boundaries'] = bounds
            metadata['boundaryCorrection'] = correction
            metadata_path.write_text(json.dumps(metadata, ensure_ascii=False, indent=2) + '\n')
        print(f'{key}: repaired and verified encoded 5→1', flush=True)
    staged = ROOT / 'Design/Voices/manifest-repaired.tmp'
    staged.write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + '\n')
    staged.replace(manifest_path)


if __name__ == '__main__':
    main()
