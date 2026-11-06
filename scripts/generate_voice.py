"""Generate Tide's original Mandarin character voice entirely from local models.

Run with the existing SocraticMeowWoof studio Python environment:
  ../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py design
  ../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py clips
  ../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py verify

Add --character claude or --character chatgpt for independent companion voices.
Run design, clips, then timer-start. Existing WAVs are reused; provenance for
retakes and extracted fragments is stored in each character's manifest.

No model downloads or service are needed. Override model directories with
WHALE_VOICE_DESIGN_MODEL, WHALE_VOICE_CLONE_MODEL, and WHALE_VOICE_ASR_MODEL.
"""
from pathlib import Path
import argparse
import difflib
import hashlib
import json
import os
import subprocess
import time

os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('TRANSFORMERS_OFFLINE', '1')
import numpy as np
import soundfile as sf

ROOT = Path(__file__).resolve().parents[1]
DESIGN = ROOT / 'design' / 'voice'
PUBLIC = ROOT / 'public' / 'voice'
HOME = Path.home()
QWEN = os.environ.get('WHALE_VOICE_DESIGN_MODEL', str(HOME / 'Models/tts/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16'))
VOX = os.environ.get('WHALE_VOICE_CLONE_MODEL', str(HOME / 'Models/tts/VoxCPM2-bf16'))
WHISPER = os.environ.get('WHALE_VOICE_ASR_MODEL', str(HOME / '.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'))
REFERENCE_TEXT = '准备好了吗？我会陪着你哦。时间到了，我们快一点吧！哼，再磨蹭，我就要生气啦！'
DESCRIPTION = '原创二次元Q版鲸鱼女仆角色的年轻成年女性声线。标准普通话，音色明亮清甜，音调偏高但自然，轻盈灵动，元气可爱，有动漫少女的俏皮感。吐字清楚，语速轻快适中，句尾自然上扬。提醒时像关心朋友的小女仆，撒娇式小傲娇，假装生气时鼓着脸，可爱而不尖叫、不凶狠。自然说话，不唱歌，不用气声，不模仿任何真人。'
SEED = 20261106
CHARACTER_DESCRIPTIONS = {
    'claude': '原创二次元Q版橙发学者的年轻成年女性声线。标准普通话，女中音，中低音区，温暖圆润，带一点柔软的鼻腔共鸣，像温柔聪明的文学系学姐。声音可爱亲切但不幼童，不用尖细高音。语调从容而活泼，吐字清晰，语速适中，提醒时温柔又有主见，假装生气时俏皮地嗔怪，不喊叫。自然口语，不唱歌，不耳语，不模仿任何真人。',
    'chatgpt': '原创二次元Q版白发小龙的年轻成年女性声线。标准普通话，清脆明亮的高音区，像小铃铛一样轻巧通透，带一点点清甜鼻音，精灵般活泼，元气十足的动漫女主角。声音高而集中，发音短促利落，尾音俏皮跳跃，情绪变化明显，惊喜感强。假装生气时可爱地鼓脸撒娇，不尖叫。成年女性，不是幼童，自然口语，不唱歌，不耳语，不模仿任何真人。',
}
LINES = DESIGN / 'lines.json'

def write_json(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')

def clean_audio(pcm, sr):
    pcm = np.asarray(pcm, dtype=np.float32).reshape(-1)
    if not len(pcm) or not np.all(np.isfinite(pcm)):
        raise ValueError('Invalid generated waveform')
    active = np.flatnonzero(np.abs(pcm) > 10 ** (-48 / 20))
    if not len(active):
        raise ValueError('Generated waveform is silent')
    keep = int(sr * .065)
    pcm = pcm[max(0, active[0] - keep):min(len(pcm), active[-1] + keep)]
    pcm *= min(4, .89 / max(float(np.max(np.abs(pcm))), 1e-8))
    return pcm

def design_voice():
    import mlx.core as mx
    from mlx_audio.tts.utils import load_model
    model = load_model(QWEN)
    mx.random.seed(SEED)
    print('Designing original voice locally…', flush=True)
    started = time.monotonic()
    generated = model.generate_voice_design(text=REFERENCE_TEXT, instruct=DESCRIPTION,
        language='Chinese', temperature=.8, max_tokens=480, verbose=False)
    pcm = clean_audio(np.concatenate([np.asarray(result.audio) for result in generated]), model.sample_rate)
    sf.write(DESIGN / 'reference.wav', pcm, model.sample_rate, subtype='PCM_16')
    write_json(DESIGN / 'reference.json', {'text': REFERENCE_TEXT, 'description': DESCRIPTION,
        'seed': SEED, 'model': QWEN, 'sampleRate': model.sample_rate,
        'duration': round(len(pcm) / model.sample_rate, 3), 'elapsedSeconds': round(time.monotonic() - started, 2),
        'provenance': 'Original synthetic voice designed from text; no real person imitation or recording.'})
    print(f'Reference: {len(pcm) / model.sample_rate:.2f}s', flush=True)

def encode(wav, output):
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
        '-c:a', 'aac', '-b:a', '96k', '-ar', '24000', '-ac', '1', '-movflags', '+faststart', str(output)], check=True)

def fit_countdown(wav, limit):
    """Keep generated digits within their beat without cutting speech or changing pitch."""
    pcm, sr = sf.read(wav, dtype='float32')
    duration = len(pcm) / sr
    if duration <= limit:
        return
    original = wav.with_suffix('.unpaced.wav')
    if not original.exists():
        sf.write(original, pcm, sr, subtype='PCM_16')
    paced = wav.with_suffix('.paced.wav')
    subprocess.run(['ffmpeg', '-hide_banner', '-loglevel', 'error', '-y', '-i', str(wav),
        '-af', f'atempo={duration / (limit - .04):.6f}', str(paced)], check=True)
    paced.replace(wav)

def create_clips():
    import mlx.core as mx
    from mlx_audio.tts.utils import load_model
    if not (DESIGN / 'reference.wav').exists():
        raise SystemExit('Generate the reference with the design command first.')
    reference = json.loads((DESIGN / 'reference.json').read_text())
    lines = [line for line in json.loads(LINES.read_text())['clips'] if line['id'] != 'timer-start']
    if args.only:
        lines = [line for line in lines if line['id'] in args.only.split(',')]
    model = load_model(VOX)
    model.set_dtype(mx.float32)
    manifest_path = PUBLIC / 'manifest.json'
    manifest = json.loads(manifest_path.read_text()) if manifest_path.exists() else {
        'voice': f'Tide — original Mandarin {args.character}', 'character': args.character, 'language': 'zh-CN',
        'designModel': Path(QWEN).name, 'cloneModel': Path(VOX).name, 'clips': []}
    for line in lines:
        wav = DESIGN / f"{line['id']}.wav"
        seed = (int(hashlib.sha256(line['text'].encode()).hexdigest()[:8], 16) + args.seed_offset + (SEED if args.character != 'whale' else 0)) % (2 ** 32)
        started = time.monotonic()
        generated_now = not wav.exists()
        if not generated_now:
            seed = next((item.get('seed', seed) for item in manifest['clips'] if item['id'] == line['id']), seed)
        if generated_now:
            mx.random.seed(seed)
            synthesis_text = line['text'] + ('。' if args.terminal_punctuation and line['id'].startswith('numeral-') else '')
            generated = model.generate(text=synthesis_text, ref_audio=str(DESIGN / 'reference.wav'),
                prompt_audio=str(DESIGN / 'reference.wav'), prompt_text=reference['text'], max_tokens=250)
            pcm = clean_audio(np.concatenate([np.asarray(result.audio) for result in generated]), model.sample_rate)
            sf.write(wav, pcm, model.sample_rate, subtype='PCM_16')
            if args.character != 'whale' and line['id'].startswith(('countdown-', 'numeral-')):
                fit_countdown(wav, .75)
        pcm, sr = sf.read(wav, dtype='float32')
        if generated_now or not (PUBLIC / line['file']).exists():
            encode(wav, PUBLIC / line['file'])
        previous = next((item for item in manifest['clips'] if item['id'] == line['id']), {}) if not generated_now else {}
        record = {**previous, **line, 'duration': round(len(pcm) / sr, 3), 'seed': seed,
            'bytes': (PUBLIC / line['file']).stat().st_size, 'sampleRate': 24000}
        if generated_now:
            record['synthesisText'] = synthesis_text
        old_index = next((i for i, item in enumerate(manifest['clips']) if item['id'] == line['id']), None)
        if old_index is None:
            manifest['clips'].append(record)
        else:
            manifest['clips'][old_index] = record
        write_json(PUBLIC / 'manifest.json', manifest)
        print(f"{line['id']}: {len(pcm) / sr:.2f}s, {time.monotonic() - started:.1f}s compute", flush=True)

def countdown_demo():
    from scipy.signal import resample_poly
    sr = 24000
    demo = np.zeros(sr * 5, dtype=np.float32)
    entries = []
    for index, digit in enumerate(range(5, 0, -1)):
        pcm, source_sr = sf.read(DESIGN / f'countdown-{digit}.wav', dtype='float32')
        divisor = np.gcd(source_sr, sr)
        pcm = resample_poly(pcm, sr // divisor, source_sr // divisor).astype(np.float32)
        if len(pcm) > sr * .8:
            raise ValueError(f'Countdown {digit} is too long: {len(pcm) / sr:.3f}s')
        demo[index * sr:index * sr + len(pcm)] = pcm
        entries.append({'digit': digit, 'startsAt': index, 'duration': round(len(pcm) / sr, 3)})
    sf.write(DESIGN / 'countdown-demo.wav', demo, sr, subtype='PCM_16')
    write_json(DESIGN / 'countdown-demo.json', {'duration': 5, 'text': '五、四、三、二、一', 'clips': entries})
    print('Created five-second countdown audition, with each digit on a one-second boundary.', flush=True)

def warning_demos():
    from scipy.signal import resample_poly
    sr = 24000
    samples = {
        11: ('十一', ['numeral-10', 'countdown-1']),
        21: ('二十一', ['countdown-2', 'numeral-10', 'countdown-1']),
        101: ('一百零一', ['countdown-1', 'numeral-100', 'numeral-0', 'countdown-1']),
        789: ('七百八十九', ['numeral-7', 'numeral-100', 'numeral-8', 'numeral-10', 'numeral-9']),
        6000: ('六千', ['numeral-6', 'numeral-1000']),
        10001: ('一万零一', ['countdown-1', 'numeral-10000', 'numeral-0', 'countdown-1']),
        100000001: ('一亿零一', ['countdown-1', 'numeral-100000000', 'numeral-0', 'countdown-1']),
    }
    results = []
    for number, (ordinal, tokens) in samples.items():
        ids = ['warning-prefix', *tokens, 'warning-suffix']
        chunks = []
        for clip_id in ids:
            pcm, source_sr = sf.read(DESIGN / f'{clip_id}.wav', dtype='float32')
            divisor = np.gcd(source_sr, sr)
            chunks.append(resample_poly(pcm, sr // divisor, source_sr // divisor).astype(np.float32))
        pcm = np.concatenate(chunks)
        clip_id = f'warning-demo-{number}'
        sf.write(DESIGN / f'{clip_id}.wav', pcm, sr, subtype='PCM_16')
        results.append({'id': clip_id, 'text': f'超时了，这是第{ordinal}次警告！', 'parts': ids,
            'duration': round(len(pcm) / sr, 3)})
    write_json(DESIGN / 'warning-demos.json', results)
    print(f'Created stitched warnings {", ".join(map(str, samples))} from the reusable fragments.', flush=True)

def timer_start_intro():
    import mlx.core as mx
    from mlx_audio.tts.utils import load_model
    from scipy.signal import resample_poly
    reference = json.loads((DESIGN / 'reference.json').read_text())
    ending = DESIGN / 'timer-start-ending.wav'
    seed = int(hashlib.sha256('开始！'.encode()).hexdigest()[:8], 16)
    if not ending.exists():
        model = load_model(VOX)
        model.set_dtype(mx.float32)
        mx.random.seed(seed)
        generated = model.generate(text='开始！', ref_audio=str(DESIGN / 'reference.wav'),
            prompt_audio=str(DESIGN / 'reference.wav'), prompt_text=reference['text'], max_tokens=100)
        pcm = clean_audio(np.concatenate([np.asarray(result.audio) for result in generated]), model.sample_rate)
        sf.write(ending, pcm, model.sample_rate, subtype='PCM_16')
        if args.character != 'whale':
            fit_countdown(ending, .85)
    sr = 24000
    schedule = [('countdown-3', 0), ('countdown-2', .8), ('countdown-1', 1.6), ('timer-start-ending', 2.4)]
    intro = np.zeros(sr * 5, dtype=np.float32)
    length = 0
    for clip_id, at in schedule:
        pcm, source_sr = sf.read(DESIGN / f'{clip_id}.wav', dtype='float32')
        divisor = np.gcd(sr, source_sr)
        pcm = resample_poly(pcm, sr // divisor, source_sr // divisor).astype(np.float32)
        offset = round(at * sr)
        intro[offset:offset + len(pcm)] += pcm
        length = max(length, offset + len(pcm))
    intro = intro[:length]
    wav = DESIGN / 'timer-start.wav'
    sf.write(wav, intro, sr, subtype='PCM_16')
    encode(wav, PUBLIC / 'timer-start.m4a')
    record = {'id': 'timer-start', 'text': '三、二、一，开始！', 'file': 'timer-start.m4a',
        'duration': round(len(intro) / sr, 3), 'bytes': (PUBLIC / 'timer-start.m4a').stat().st_size,
        'sampleRate': sr, 'seed': seed, 'assembly': [{'id': name, 'at': at} for name, at in schedule]}
    manifest = json.loads((PUBLIC / 'manifest.json').read_text())
    manifest['clips'] = [clip for clip in manifest['clips'] if clip['id'] != 'timer-start'] + [record]
    write_json(PUBLIC / 'manifest.json', manifest)
    write_json(DESIGN / 'timer-start.json', record)
    print(f"timer-start: {record['duration']:.3f}s, paced digits at 0.0, 0.8, 1.6s, 开始 at 2.4s", flush=True)

def verify():
    import cn2an
    import zhconv
    from scipy.signal import resample_poly
    from pypinyin import lazy_pinyin
    from faster_whisper import WhisperModel
    model = WhisperModel(WHISPER, device='cpu', compute_type='int8', local_files_only=True)
    lines = [{'id': 'reference', 'text': REFERENCE_TEXT}] + json.loads(LINES.read_text())['clips']
    if (DESIGN / 'countdown-demo.wav').exists():
        lines.append({'id': 'countdown-demo', 'text': '五四三二一'})
    if (DESIGN / 'warning-demos.json').exists():
        lines.extend(json.loads((DESIGN / 'warning-demos.json').read_text()))
    if args.only:
        lines = [line for line in lines if line['id'] in args.only.split(',')]
    results = []
    def sounds(text):
        # Recognizers may write an ordinal as 第101次 rather than 第一百零一次.
        text = cn2an.transform(text, 'an2cn') if '第' in text else text.translate(str.maketrans('0123456789', '零一二三四五六七八九'))
        return lazy_pinyin(''.join(c for c in zhconv.convert(text, 'zh-cn') if '\u3400' <= c <= '\u9fff'))
    for line in lines:
        path = DESIGN / (line['id'] + '.wav')
        if not path.exists():
            continue
        # Match the existing studio runner: decode with soundfile and pass 16 kHz
        # samples, avoiding an incompatible local PyAV metadata_errors argument.
        pcm, sr = sf.read(path, dtype='float32')
        divisor = np.gcd(sr, 16000)
        samples = resample_poly(pcm, 16000 // divisor, sr // divisor).astype(np.float32)
        # Give recognizers context around very short utterances without letting
        # VAD discard soft opening interjections such as 开始啦 or 哼.
        samples = np.pad(samples, (8000, 8000))
        segs, _ = model.transcribe(samples, language='zh', condition_on_previous_text=False, vad_filter=False)
        heard = ''.join(s.text for s in segs).strip()
        score = difflib.SequenceMatcher(a=sounds(line['text']), b=sounds(heard), autojunk=False).ratio()
        result = {**line, 'heard': heard, 'phoneticMatch': round(score, 3),
            'duration': round(len(pcm) / sr, 3), 'peak': round(float(np.max(np.abs(pcm))), 4)}
        results.append(result)
        print(f"{line['id']}: {score:.3f} — {heard}", flush=True)
        verification_file = 'verification.json'
        if args.only:
            verification_file = ('countdown-verification.json' if args.only.startswith('countdown')
                else 'timer-start-verification.json' if args.only.startswith('timer-start')
                else 'reset-verification.json' if args.only == 'reset' else 'warning-verification.json')
        write_json(DESIGN / verification_file, results)

if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['design', 'clips', 'verify', 'countdown-demo', 'warning-demos', 'timer-start'])
    parser.add_argument('--only', help='Comma-separated clip IDs to generate or verify.')
    parser.add_argument('--character', choices=['whale', 'claude', 'chatgpt'], default='whale')
    parser.add_argument('--seed-offset', type=int, default=0, help='Deterministic alternate synthesis take; remove the selected WAV first.')
    parser.add_argument('--terminal-punctuation', action='store_true', help='Add a full stop to isolated numeral prompts for clearer articulation.')
    args = parser.parse_args()
    if args.character != 'whale':
        DESIGN = DESIGN / args.character
        PUBLIC = PUBLIC / args.character
        DESCRIPTION = CHARACTER_DESCRIPTIONS[args.character]
        SEED += 101 if args.character == 'claude' else 202
    DESIGN.mkdir(parents=True, exist_ok=True)
    PUBLIC.mkdir(parents=True, exist_ok=True)
    {'design': design_voice, 'clips': create_clips, 'verify': verify,
        'countdown-demo': countdown_demo, 'warning-demos': warning_demos, 'timer-start': timer_start_intro}[args.action]()
