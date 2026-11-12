"""Evidence checks for reviewed, original-engine voice production (no ML imports)."""
from pathlib import Path
import array
import hashlib
import json
import math
import subprocess
import sys
import unicodedata

ROOT = Path(__file__).resolve().parents[1]
CAST = ROOT / 'Design/Voices/VoiceCasting'
PILOT = ROOT / 'Verification/SelectedEnginePilot'
SOURCE = ROOT / 'Design/Voices/SelectedEngineProduction'
REVISION = 'selected-engine-v2'
BASE_MODEL = 'Qwen3-TTS-12Hz-1.7B-Base-bf16'
REFERENCE_LANGUAGES = {'en': 'auto', 'zh-Hans': 'Chinese', 'ja': 'Japanese', 'ko': 'Korean', 'es': 'Spanish', 'pt-BR': 'Portuguese', 'fr': 'French', 'de': 'German'}

def equivalent_wording(key, expected, heard):
    """Explicit complete-sentence variants, not a relaxed similarity threshold.

    These tap reactions differ only in an interjection / ending particle and
    retain the meaning 'you found me'. Keep the original score and transcript
    visible in the review; never label a variant as an exact transcript match.
    """
    def normalized(value):
        return ''.join(c for c in unicodedata.normalize('NFKC',value or '') if c.isalnum())
    language,_,cue=key.split('/')
    variants={
        ('ko','poke'):('앗나찾았네',{'아나찾았네'}),
        ('zh-Hans','poke'):('呀被你发现啦',{'呀被你发现了','呀被你發現了'}),
    }
    variant=variants.get((language,cue))
    return bool(variant and normalized(expected)==variant[0] and normalized(heard) in variant[1])

def reference_generation_options(language, reference, transcript):
    # MLX Audio's generic generate() uses lang_code. Unknown language= is
    # silently absorbed by **kwargs. English preserves the accepted pilot's auto.
    return {'ref_audio': str(reference), 'ref_text': transcript, 'lang_code': REFERENCE_LANGUAGES[language], 'temperature': .85}



def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def expected_model(selection, route):
    if route not in ('direct', 'reference'):
        raise ValueError(f'Unknown production route: {route}')
    return BASE_MODEL if route == 'reference' and selection['model'].startswith('Qwen') else selection['model']


def validate_review(review, characters, cast=CAST, pilot=PILOT):
    choices_path = cast / 'approved-choices.json'
    choices = json.loads(choices_path.read_text())
    pilots = json.loads((pilot / 'manifest.json').read_text())['clips']
    sources = json.loads((pilot / 'audition-source-check.json').read_text())['clips']
    if review.get('version') != 2 or review.get('choicesSHA256') != sha(choices_path):
        raise ValueError('Listening review does not match the current audition choices')
    for character in characters:
        if character not in choices['selectedVoices']:
            raise ValueError(f'Unknown companion: {character}')
        selected = choices['selectedVoices'][character]
        accepted = review.get('routes', {}).get(character, {})
        route = accepted.get('route')
        clip = pilots.get(f'{character}/{route}', {})
        if accepted.get('status') != 'approved' or route not in ('direct', 'reference'):
            raise ValueError(f'{character}: listening review is still pending or rejected')
        if (accepted.get('pilotSHA256') != clip.get('audioSHA256') or
                clip.get('voice') != selected['voice'] or
                clip.get('auditionSHA256') != selected['sha256'] or
                clip.get('model') != expected_model(selected, route)):
            raise ValueError(f'{character}: review does not identify the selected voice and engine')
        if sha(pilot / character / f'{route}.m4a') != accepted['pilotSHA256']:
            raise ValueError(f'{character}: pilot changed after listening review')
        if sha(cast / 'audio' / f'{selected["voice"]}.m4a') != selected['sha256']:
            raise ValueError(f'{character}: original audition changed')
        proof=sources.get(character,{})
        if (not proof.get('exactAuditionMatch') or proof.get('auditionSHA256')!=selected['sha256'] or
                proof.get('reencodedSHA256')!=selected['sha256'] or
                proof.get('sourceWAVSHA256')!=sha(cast/'audio'/f'{selected["voice"]}.wav')):
            raise ValueError(f'{character}: lossless source no longer matches the approved audition')
    return choices


def validate_bundle(audio_root, manifest, decode=False, source=SOURCE, cast=CAST, pilot=PILOT):
    """Return actionable failures. Hash/format success is never a sound-quality claim."""
    errors = []
    casting = manifest.get('casting', {})
    if casting.get('pipelineRevision') != REVISION:
        return ['Legacy production cannot be installed as repaired voices']
    review = manifest.get('productionReview', {})
    try:
        choices = validate_review(review, json.loads((cast / 'approved-choices.json').read_text())['selectedVoices'], cast, pilot)
        review_path = source / 'routes.json'
        if json.loads(review_path.read_text()) != review or sha(review_path) != casting.get('reviewSHA256'):
            raise ValueError('Production review differs from the retained listening review')
        if casting.get('choicesSHA256') != sha(cast / 'approved-choices.json') or casting.get('selectedVoices') != choices['selectedVoices']:
            raise ValueError('Production choices differ from the approved cast')
    except (ValueError, OSError, KeyError) as exc:
        return [str(exc)]
    for key, entry in manifest.get('clips', {}).items():
        try:
            lang, character, cue = key.split('/')
            selected = choices['selectedVoices'][character]
            accepted = review['routes'][character]
            wav = source / character / lang / f'{cue}.wav'
            encoded = audio_root / f'{key}.m4a'
            required = {
                'pipelineRevision': REVISION, 'castingVoice': selected['voice'],
                'auditionSHA256': selected['sha256'],
                'auditionWAVSHA256': sha(cast / 'audio' / f'{selected["voice"]}.wav'),
                'route': accepted['route'], 'pilotSHA256': accepted['pilotSHA256'],
                'model': expected_model(selected, accepted['route']),
                'rawSHA256': sha(wav), 'audioSHA256': sha(encoded),
            }
            if selected['model'].startswith('Qwen') and accepted['route']=='reference' and lang!='en':
                required['languageConditioning']=REFERENCE_LANGUAGES[lang]
            for field, value in required.items():
                if entry.get(field) != value:
                    raise ValueError(f'Incorrect {field}')
            if entry.get('packagedCheckSHA256',entry['audioSHA256'])!=entry['audioSHA256']:
                raise ValueError('Encoded countdown differs from its packaged wording check')
            settings = entry.get('encoding', {})
            for field, value in {'speed': 1, 'pitch': 1, 'bitrateTarget': 128000, 'sampleRate': 24000, 'channels': 1, 'codec': 'aac'}.items():
                if settings.get(field) != value:
                    raise ValueError(f'Incorrect encoding {field}')
            if cue.isdigit() and entry.get('method')=='contextual-number-v2':
                context=source/character/lang/f'{cue}-context.wav'
                metadata=json.loads(context.with_suffix('.json').read_text())
                if (metadata.get('method')!='contextual-number-v2' or metadata.get('number')!=int(cue) or
                        metadata.get('speed')!=1 or metadata.get('pitch')!=1 or
                        metadata.get('sourceSHA256')!=sha(context) or entry.get('contextSHA256')!=sha(context) or
                        metadata.get('bounds')!=entry.get('bounds') or metadata.get('seed')!=entry.get('seed')):
                    raise ValueError('Numeral context source or word boundary changed')
            elif cue.isdigit():
                countdown = source / character / lang / 'countdown.wav'
                metadata = json.loads((countdown.with_suffix('.json')).read_text())
                if (entry.get('method') != 'natural-countdown-v2' or
                        metadata.get('method') != 'natural-countdown-v2' or
                        metadata.get('speed') != 1 or metadata.get('pitch') != 1 or
                        metadata.get('sourceSHA256') != sha(countdown) or
                        entry.get('countdownSHA256') != sha(countdown)):
                    raise ValueError('Countdown source changed or used time/pitch transforms')
                index = 5 - int(cue)
                boundaries = metadata['boundaries']
                if len(boundaries) != 6 or len(metadata['words']) != 5 or entry.get('bounds') != boundaries[index:index+2]:
                    raise ValueError('Countdown boundaries do not match the retained performance')
            if decode:
                raw = subprocess.check_output(['ffmpeg', '-v', 'error', '-i', str(encoded), '-f', 'f32le', '-ar', '24000', '-ac', '1', '-'])
                samples = array.array('f', raw)
                if sys.byteorder != 'little':
                    samples.byteswap()
                if not samples or not all(math.isfinite(v) for v in samples):
                    raise ValueError('Invalid decoded waveform')
                peak = max(abs(v) for v in samples)
                if peak > .95 or abs(peak - settings.get('decodedPeak', -1)) > .00001:
                    raise ValueError('Decoded headroom check failed')
                if abs(len(samples) / 24000 - entry['duration']) > .001:
                    raise ValueError('Decoded duration differs from manifest')
                info = json.loads(subprocess.check_output(['ffprobe', '-v', 'error', '-show_entries', 'format=duration:stream=sample_rate', '-of', 'json', str(wav)]))
                if int(info['streams'][0]['sample_rate']) != entry['sourceSampleRate']:
                    raise ValueError('Source sample rate differs from manifest')
                if abs(float(info['format']['duration']) - entry['sourceDuration']) > .001:
                    raise ValueError('Source duration differs from manifest')
                # AAC may expose a partial trailing packet; permit one 1024-sample packet.
                if abs(len(samples) / 24000 - float(info['format']['duration'])) > 1024 / 24000 + .001:
                    raise ValueError('Encoding changed playback duration')
        except (ValueError, OSError, KeyError, TypeError, IndexError, subprocess.CalledProcessError) as exc:
            errors.append(f'{key}: {exc}')
    return errors


def validate_transcripts(manifest, report):
    """Require up-to-date wording diagnostics for every staged recording."""
    errors = []
    for key, entry in manifest['clips'].items():
        checked = report.get('clips', {}).get(key, {})
        allowed = {'encoded-countdown-match'} if key.split('/')[-1].isdigit() else {'transcript-match','equivalent-wording'}
        if checked.get('sha256') != entry.get('audioSHA256'):
            errors.append(f'{key}: missing or stale wording check')
        elif checked.get('expected') != entry.get('text'):
            errors.append(f'{key}: wording check used different expected text')
        elif checked.get('review') not in allowed:
            errors.append(f'{key}: wording needs review')
        elif checked.get('review')=='equivalent-wording':
            if not equivalent_wording(key,entry.get('text'),checked.get('heard')):
                errors.append(f'{key}: unrecognized wording variant')
        elif not key.split('/')[-1].isdigit() and checked.get('similarity', 0) < (.95 if key.startswith('en/') else .85):
            errors.append(f'{key}: insufficient wording match')
    return errors
