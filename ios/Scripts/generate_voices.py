#!/usr/bin/env python3
"""Generate original offline companion voices using the already installed local VoxCPM2 model.
Run: ../SocraticMeowWoof/studio/.venv/bin/python ios/Scripts/generate_voices.py
Resumable by content hashes; no network or real-person voice references. Outputs stay in ios/.
"""
import os
os.environ.setdefault('HF_HUB_OFFLINE', '1')
os.environ.setdefault('TRANSFORMERS_OFFLINE', '1')
from pathlib import Path
import argparse, hashlib, json, subprocess, time, tempfile
import numpy as np
import soundfile as sf
import mlx.core as mx
from mlx_audio.tts.utils import load_model
from countdown_voices import generate as generate_countdown

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'Design/Voices'
OUT = ROOT / 'Banke/Audio/Voices'
MODEL = Path(os.environ.get('BANKE_VOICE_MODEL', str(Path.home() / 'Models/tts/VoxCPM2-bf16')))
REFERENCE = "Hello, I'm here with you. Let's take one small step together. A little focus, a little rest. You're doing well."

def write(path, value):
    # Keep staging files outside the bundled Audio directory during development builds.
    with tempfile.NamedTemporaryFile(mode='w',dir=SOURCE,suffix='.json.tmp',delete=False) as output:
        output.write(json.dumps(value, ensure_ascii=False, indent=2)+'\n')
        temp = Path(output.name)
    temp.replace(path)

def clean(pcm, sr):
    pcm = np.asarray(pcm, dtype=np.float32).reshape(-1)
    if not len(pcm) or not np.isfinite(pcm).all(): raise ValueError('Invalid waveform')
    active = np.flatnonzero(np.abs(pcm) > 10 ** (-45/20))
    if not len(active): raise ValueError('Silent output')
    pcm = pcm[max(0, active[0]-int(sr*.04)):min(len(pcm), active[-1]+int(sr*.07))]
    pcm *= min(4, .88 / max(float(np.max(np.abs(pcm))), 1e-8))
    return pcm

def encode(wav, dest, short=False):
    samples, sr = sf.read(wav)
    duration = len(samples)/sr
    # Short digits must fit one clock beat; no truncation or pitch shifting.
    args = ['ffmpeg','-hide_banner','-loglevel','error','-y','-i',str(wav)]
    if short and duration > .78:
        args += ['-af',f'atempo={duration/.76:.6f}']
    staged = wav.with_suffix('.m4a')
    args += ['-c:a','aac','-b:a','64k','-ar','24000','-ac','1','-movflags','+faststart',str(staged)]
    subprocess.run(args,check=True)
    staged.replace(dest)
    return .76 if short and duration > .78 else duration

def render(model, text, seed, *, reference=None, instruct=None, max_tokens=180):
    for attempt in range(4):
        actual_seed=(seed+attempt*1009)&0xffffffff
        mx.random.seed(actual_seed)
        try:
            chunks=[np.asarray(r.audio) for r in model.generate(text=text,ref_audio=str(reference) if reference else None,instruct=instruct,max_tokens=max_tokens)]
            pcm=clean(np.concatenate(chunks),model.sample_rate)
            duration=len(pcm)/model.sample_rate
            if not .15<=duration<=(12 if reference else 20):raise ValueError(f'Unexpected duration: {duration}')
            return pcm,actual_seed
        except ValueError as error:
            print(f'Rejected take {attempt+1}: {error}',flush=True)
            mx.clear_cache()
    return None,seed

def main():
    global SOURCE, OUT
    parser=argparse.ArgumentParser()
    parser.add_argument('--source-root',type=Path,default=SOURCE,help='Separate design workspace for auditioning replacement voices.')
    parser.add_argument('--audio-root',type=Path,default=OUT,help='Separate encoded output directory; defaults to the bundled audio.')
    parser.add_argument('--redesign-references',action='store_true',help='Regenerate selected references whose description changed.')
    parser.add_argument('--references-only',action='store_true',help='Design reference voices without generating application cues.')
    parser.add_argument('--characters',default='mochi,pip,pebble,jun,bean,maple,luna,atlas,wisp,nova,orbit,comet')
    parser.add_argument('--languages',default='en,zh-Hans,ja,ko,es,pt-BR,fr,de')
    parser.add_argument('--only',default='')
    parser.add_argument('--retake',type=int,default=0,help='New deterministic take for selected cues; selecting a digit regenerates the coherent five-number performance.')
    args=parser.parse_args()
    SOURCE=args.source_root.resolve(); OUT=args.audio_root.resolve()
    SOURCE.mkdir(parents=True,exist_ok=True)
    if args.retake and not args.only: parser.error('--retake requires --only to protect the rest of the library')
    if args.retake < 0: parser.error('--retake must be nonnegative')
    lines=json.loads((ROOT/'Localization/voice-lines.json').read_text())
    profiles=json.loads((SOURCE/'profiles.json').read_text())
    pronunciations=json.loads((SOURCE/'pronunciations.json').read_text()) if (SOURCE/'pronunciations.json').exists() else {}
    model=load_model(str(MODEL)); model.set_dtype(mx.float32)
    sr=model.sample_rate
    OUT.mkdir(parents=True,exist_ok=True)
    manifest_path=OUT/'manifest.json'
    manifest=json.loads(manifest_path.read_text()) if manifest_path.exists() else {'model':MODEL.name,'provenance':'Original synthetic characters; no real person reference or imitation.','aliases':{'zh-Hant':'zh-Hans'},'clips':{}}
    for character in args.characters.split(','):
        folder=SOURCE/character; folder.mkdir(exist_ok=True)
        reference=folder/'reference.wav'
        metadata=folder/'reference.json'
        changed=reference.exists() and (not metadata.exists() or json.loads(metadata.read_text()).get('description')!=profiles[character])
        if changed and not args.redesign_references:
            raise SystemExit(f'{character}: profile differs from reference. Use --redesign-references or a separate --source-root to audition the new identity.')
        if not reference.exists() or changed:
            seed=int(hashlib.sha256(character.encode()).hexdigest()[:8],16)
            started=time.monotonic()
            pcm,seed=render(model,REFERENCE,seed,instruct=profiles[character],max_tokens=350)
            if pcm is None:
                raise SystemExit(f'NEEDS REVIEW: reference {character}; no cues generated from the previous identity.')
            sf.write(reference,pcm,sr,subtype='PCM_16')
            write(folder/'reference.json',{'model':MODEL.name,'text':REFERENCE,'description':profiles[character],'seed':seed,'seconds':len(pcm)/sr})
            print(f'REFERENCE {character} {len(pcm)/sr:.1f}s / {time.monotonic()-started:.1f}s compute',flush=True)
        if args.references_only: continue
        reference_digest=hashlib.sha256(reference.read_bytes()).hexdigest()
        for lang in args.languages.split(','):
            output=OUT/lang/character; output.mkdir(parents=True,exist_ok=True)
            source=folder/lang; source.mkdir(exist_ok=True)
            if not args.only or any(c.isdigit() for c in args.only.split(',')):
                success=generate_countdown(model,character,lang,reference,source,output,lines[lang],manifest,clean,encode,retake=args.retake)
                write(manifest_path,manifest)
                if not success: print(f'NEEDS REVIEW: countdown {lang}/{character}',flush=True)
                mx.clear_cache()
            for cue in ['go','pause','resume','reset','focusComplete','breakComplete','greeting','poke']:
                if args.only and cue not in args.only.split(','): continue
                text=lines[lang][character if cue=='greeting' else cue]
                key=f'{lang}/{character}/{cue}'
                pronunciation=pronunciations.get(key,text)
                spoken=pronunciation.get('text',text) if isinstance(pronunciation,dict) else pronunciation
                instruction_override=pronunciation.get('instruct') if isinstance(pronunciation,dict) else None
                fingerprint=hashlib.sha256((text+profiles[character]+MODEL.name+('spoken:'+spoken if spoken!=text else '')+('instruct:'+instruction_override if instruction_override else '')+'reference:'+reference_digest).encode()).hexdigest()
                dest=output/f'{cue}.m4a'; wav=source/f'{cue}.wav'
                if not args.retake and manifest['clips'].get(key,{}).get('hash')==fingerprint and dest.exists(): continue
                started=time.monotonic(); seed=(int(fingerprint[:8],16)+args.retake*1_000_003)&0xffffffff
                instruct=instruction_override or ('Speak Brazilian Portuguese naturally.' if lang=='pt-BR' else None)
                pcm,seed=render(model,spoken,seed,reference=reference,instruct=instruct)
                if pcm is None:
                    manifest['clips'].pop(key,None);dest.unlink(missing_ok=True)
                    write(manifest_path,manifest)
                    print(f'NEEDS REVIEW: {key}',flush=True)
                    continue
                sf.write(wav,pcm,sr,subtype='PCM_16')
                duration=encode(wav,dest,cue.isdigit())
                manifest['clips'][key]={'text':text,'hash':fingerprint,'seed':seed,'duration':round(duration,3),'sourceDuration':round(len(pcm)/sr,3),'bytes':dest.stat().st_size}
                manifest['clips'][key]['referenceSHA256']=reference_digest
                if spoken!=text:manifest['clips'][key]['spokenText']=spoken
                if instruction_override:manifest['clips'][key]['instruction']=instruction_override
                write(manifest_path,manifest)
                print(f'{key} {duration:.2f}s / {time.monotonic()-started:.1f}s compute',flush=True)
                mx.clear_cache()
    if args.references_only: return
    wanted=args.only.split(',') if args.only else ['go','pause','resume','reset','focusComplete','breakComplete','1','2','3','4','5','greeting','poke']
    missing=[f'{lang}/{character}/{cue}' for character in args.characters.split(',') for lang in args.languages.split(',') for cue in wanted if f'{lang}/{character}/{cue}' not in manifest['clips']]
    print(f'Generation finished: {len(manifest["clips"])}/{len(profiles)*8*13} clips. Run verify_release_resources.py before release.',flush=True)
    if missing: raise SystemExit(f'{len(missing)} requested clips still need review: '+', '.join(missing))
if __name__=='__main__': main()
