#!/usr/bin/env python3
"""Validate and install the staged approved cast, retaining a complete rollback copy."""
from pathlib import Path
import argparse, datetime, json, shutil, subprocess, sys
from selected_voice_contract import validate_transcripts, sha
ROOT=Path(__file__).resolve().parents[1]
def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--audio-root',type=Path,default=ROOT/'Verification/SelectedEngineVoices')
    parser.add_argument('--transcripts',type=Path,default=ROOT/'Verification/selected-engine-transcripts.json')
    args=parser.parse_args()
    source=args.audio_root.resolve()
    runtime=ROOT/'Banke/Audio/Voices'
    if source==runtime.resolve():raise SystemExit('Source must be a staged replacement, not the live bundle')
    staged_manifest=json.loads((source/'manifest.json').read_text())
    if staged_manifest.get('casting',{}).get('pipelineRevision') != 'selected-engine-v2':
        raise SystemExit('Refusing legacy cross-engine voice output: selected audition hashes alone do not approve regenerated sound. Use the reviewed selected-engine-v2 pipeline.')
    transcript_errors=validate_transcripts(staged_manifest,json.loads(args.transcripts.read_text()))
    if transcript_errors:raise SystemExit('Wording validation failed:\n'+'\n'.join(transcript_errors))
    # Full checks include completeness, selected-reference hashes, encoded hashes,
    # subtitle text, AAC decoding, sample rate, channel count and countdown length.
    subprocess.run([sys.executable,str(ROOT/'Scripts/verify_release_resources.py'),'--audio-root',str(source),'--decode'],check=True)
    stamp=datetime.datetime.now().strftime('%Y%m%d-%H%M%S')
    stage=ROOT/'Verification'/f'ApprovedVoiceInstall-{stamp}'
    backup=ROOT/'Verification/VoiceBackups'/f'before-approved-{stamp}'
    stage.mkdir()
    manifest=json.loads((source/'manifest.json').read_text())
    for key in manifest['clips']:
        target=stage/f'{key}.m4a';target.parent.mkdir(parents=True,exist_ok=True)
        shutil.copy2(source/f'{key}.m4a',target)
    shutil.copy2(source/'manifest.json',stage/'manifest.json')
    backup.parent.mkdir(parents=True,exist_ok=True)
    runtime.rename(backup)
    try:stage.rename(runtime)
    except BaseException:
        backup.rename(runtime)
        raise
    print(f'Installed {len(manifest["clips"])} approved clips. Previous bundle: {backup}')
    (ROOT/'Verification/approved-voice-install.json').write_text(json.dumps({
        'installedAt':datetime.datetime.now().isoformat(),'clips':len(manifest['clips']),
        'castingChoicesSHA256':manifest['casting']['choicesSHA256'],
        'reviewSHA256':manifest['casting']['reviewSHA256'],
        'transcriptsSHA256':sha(args.transcripts), 'pipelineRevision':manifest['casting']['pipelineRevision'],
        'backup':str(backup.relative_to(ROOT)), 'source':str(source.relative_to(ROOT))
    },indent=2)+'\n')
if __name__=='__main__':main()
