"""Produce coherent five-number performances and split at verified word boundaries."""
from pathlib import Path
import hashlib, json, re, subprocess, unicodedata, itertools
import numpy as np
import soundfile as sf
from faster_whisper import WhisperModel

ASR = None
REVISION = 'context-countdown-v1'
LANGUAGES={'en':'English','zh-Hans':'Mandarin Chinese','ja':'Japanese','ko':'Korean','es':'Spanish','pt-BR':'Brazilian Portuguese','fr':'French','de':'German'}
WORDS={
 'en':[['five'],['four'],['three'],['two'],['one']],
 'zh-Hans':[['五'],['四'],['三'],['二'],['一']],
 'ja':[['五','ご'],['四','よん'],['三','さん'],['二','に'],['一','いち']],
 'ko':[['오','다섯'],['사','넷'],['삼','셋'],['이','둘'],['일','하나']],
 'es':[['cinco'],['cuatro'],['tres'],['dos'],['uno']],
 'pt-BR':[['cinco'],['quatro'],['três','tres'],['dois'],['um']],
 # Whisper small sometimes writes the sounds of isolated French numbers phonetically.
 # Recognition is a local wording/boundary diagnostic, not a style assessment.
 'fr':[['cinq','sank'],['quatre','katt','kat'],['trois','trah'],['deux','do'],['un','an']],
 'de':[['fünf','funf'],['vier'],['drei'],['zwei'],['eins']],
}

CONTEXT_NUMBERS={
 'en':{6:['six'],0:['zero']}, 'zh-Hans':{6:['六'],0:['零']},
 'ja':{6:['六','ろく'],0:['ゼロ','ぜろ','零','れい']}, 'ko':{6:['육','여섯'],0:['영','공']},
 'es':{6:['seis'],0:['cero']}, 'pt-BR':{6:['seis'],0:['zero']},
 'fr':{6:['six'],0:['zéro','zero']}, 'de':{6:['sechs'],0:['null']},
}


def number_words(lang, number):
    return WORDS[lang][5-number] if 1<=number<=5 else CONTEXT_NUMBERS[lang][number]


def word_key(text):
    text=unicodedata.normalize('NFKC',text).lower()
    text=''.join(chr(ord(c)-0x60) if '\u30a1' <= c <= '\u30f6' else c for c in text)
    return ''.join(c for c in text if c.isalnum())

def sequence_matches(words, lang, order=(5,4,3,2,1)):
    """ASR token boundaries need not coincide with the five spoken numbers."""
    heard=''.join(word_key(w) for w in words)
    choices=[[str(n)]+[word_key(w) for w in number_words(lang,n)] for n in order]
    return any(heard==''.join(candidate) for candidate in itertools.product(*choices))


def separated_number_words(pcm, sr, lang, order=(5,4,3,2,1)):
    """Conservative fallback after ASR confirms the exact complete sequence.

    Require one speech island per expected number, separated by >=100 ms of quiet.
    Never guess boundaries from equal durations or split an ambiguous island.
    """
    frame=max(1,round(sr*.01));samples=np.asarray(pcm,dtype=np.float32)
    if len(samples)<frame:return None
    padded=np.pad(samples,(0,(-len(samples))%frame))
    rms=np.sqrt(np.mean(padded.reshape(-1,frame)**2,axis=1))
    active=np.flatnonzero(rms>max(.004,float(rms.max())*.015))
    if not len(active):return None
    groups=[];start=last=int(active[0])
    for index in active[1:]:
        index=int(index)
        if index-last>10:
            groups.append((start,last));start=index
        last=index
    groups.append((start,last))
    if len(groups)!=len(order):return None
    if any(not .10<=(end-start+1)*frame/sr<=1.3 for start,end in groups):return None
    return [{'text':number_words(lang,order[i])[0],'start':start*frame/sr,'end':min(len(samples),(end+1)*frame)/sr,'alignment':f'{len(order)}-separated-speech-islands'} for i,(start,end) in enumerate(groups)]


def quiet_word_boundaries(pcm, sr, words):
    """Use actual inter-word silence near ASR boundaries, or reject ambiguity.

    Word timestamps can lag enough to include the next number. Require a quiet
    interval of at least 60 ms between adjacent word centers before cutting.
    """
    frame=max(1,round(sr*.01))
    samples=np.asarray(pcm,dtype=np.float32)
    padded=np.pad(samples,(0,(-len(samples))%frame))
    rms=np.sqrt(np.mean(padded.reshape(-1,frame)**2,axis=1))
    threshold=max(.003,float(rms.max())*.01)
    boundaries=[0.0]
    for left,right in zip(words,words[1:]):
        start=max(0,int(((left['start']+left['end'])/2)*sr/frame))
        end=min(len(rms),int(((right['start']+right['end'])/2)*sr/frame))
        target=(left['end']+right['start'])/2
        candidates=[];run=None
        for i in range(start,end+1):
            if i<end and rms[i]<=threshold:
                if run is None:run=i
            elif run is not None:
                if (i-run)*frame/sr>=.06:
                    middle=(run+i)*frame/(2*sr)
                    candidates.append((abs(middle-target),middle))
                run=None
        if not candidates:return None
        boundary=min(candidates)[1]
        if boundary<=boundaries[-1]:return None
        boundaries.append(boundary)
    boundaries.append(len(samples)/sr)
    return boundaries


def recognize(pcm, sr, lang, order=(5,4,3,2,1)):
    global ASR
    if ASR is None:
        path=Path.home()/'.cache/huggingface/hub/models--Systran--faster-whisper-small/snapshots/536b0662742c02347bc0e980a01041f333bce120'
        ASR=WhisperModel(str(path),device='cpu',compute_type='int8',local_files_only=True,cpu_threads=4)
    from scipy.signal import resample_poly
    divisor=np.gcd(sr,16000)
    samples=resample_poly(pcm,16000//divisor,sr//divisor).astype(np.float32)
    segments,_=ASR.transcribe(samples,language={'zh-Hans':'zh','pt-BR':'pt'}.get(lang,lang),word_timestamps=True,condition_on_previous_text=False,vad_filter=False,beam_size=3)
    words=[{'text':w.word,'start':float(w.start),'end':float(w.end)} for segment in segments for w in segment.words if word_key(w.word)]
    if lang=='ja' and len(words)>len(order) and not sequence_matches([w['text'] for w in words],lang,order):
        # Japanese uses a lead-in for coherent intonation. Any lead-in is
        # excluded by the first numeral's timestamp; only accept the remaining
        # five words if they match the exact 5–1 sequence below.
        words=words[-len(order):]
    valid=len(words)==len(order) and all(word_key(w['text']) in [str(order[i])]+[word_key(v) for v in number_words(lang,order[i])] for i,w in enumerate(words))
    if not valid and sequence_matches([w['text'] for w in words],lang,order):
        aligned=separated_number_words(pcm,sr,lang,order)
        if aligned:
            aligned[0]['recognizedSequence']=[w['text'] for w in words]
            return aligned,True
    return words,valid

def generate(model, character, lang, reference, source, output, lines, manifest, clean, encode, retake=0):
    import mlx.core as mx
    text=' '.join(lines[str(n)] for n in [5,4,3,2,1])
    if lang=='ja':text='それでは、五、四、三、二、一。'
    instruct='Speak Japanese naturally.' if lang=='ja' else f'Speak in {LANGUAGES[lang]} naturally. Clearly count down from five to one.'
    fingerprint=hashlib.sha256((REVISION+text+instruct+hashlib.sha256(reference.read_bytes()).hexdigest()).encode()).hexdigest()
    keys=[f'{lang}/{character}/{n}' for n in [5,4,3,2,1]]
    if not retake and all(manifest['clips'].get(k,{}).get('hash')==fingerprint and (output/f'{k.split("/")[-1]}.m4a').exists() for k in keys):return True
    for attempt in range(4):
        seed=(int(fingerprint[:8],16)+retake*1_000_003+attempt*1009)&0xffffffff;mx.random.seed(seed)
        try:
            pcm=clean(np.concatenate([np.asarray(r.audio) for r in model.generate(text=text,ref_audio=str(reference),instruct=instruct,max_tokens=180)]),model.sample_rate)
        except ValueError as error:
            print(f'COUNTDOWN {lang}/{character} rejected take {attempt+1}: {error}',flush=True)
            mx.clear_cache()
            continue
        words,valid=recognize(pcm,model.sample_rate,lang)
        print(f'COUNTDOWN {lang}/{character} take {attempt+1}: '+str([w['text'] for w in words]),flush=True)
        if not valid:continue
        boundaries=[max(0,words[0]['start']-.08)]+[(a['end']+b['start'])/2 for a,b in zip(words,words[1:])]+[len(pcm)/model.sample_rate]
        pieces=[clean(pcm[int(a*model.sample_rate):int(b*model.sample_rate)],model.sample_rate) for a,b in zip(boundaries,boundaries[1:])]
        if any(len(p)/model.sample_rate>1.5 for p in pieces):
            # A breath in a long inter-word gap is not part of the numeral. Fall back
            # to padded ASR word bounds, still clamped inside the inter-word midpoints.
            slices=[(max(boundaries[i],w['start']-.08), min(boundaries[i+1],w['end']+.12)) for i,w in enumerate(words)]
            pieces=[clean(pcm[int(a*model.sample_rate):int(b*model.sample_rate)],model.sample_rate) for a,b in slices]
        else:slices=list(zip(boundaries,boundaries[1:]))
        if any(not .12<=len(p)/model.sample_rate<=1.5 for p in pieces):
            sf.write(source/'countdown-review.wav',pcm,model.sample_rate,subtype='PCM_16')
            (source/'countdown-review.json').write_text(json.dumps({'words':words,'durations':[len(p)/model.sample_rate for p in pieces],'seed':seed},ensure_ascii=False,indent=2)+'\n')
            continue
        sf.write(source/'countdown.wav',pcm,model.sample_rate,subtype='PCM_16')
        (source/'countdown.json').write_text(json.dumps({'method':REVISION,'text':text,'instruct':instruct,'seed':seed,'words':words,'boundaries':boundaries,'recognizer':'faster-whisper-small','note':'Transcript and boundary check; not native-speaker approval.'},ensure_ascii=False,indent=2)+'\n')
        for index,(key,part) in enumerate(zip(keys,pieces)):
            cue=str(5-index);wav=source/f'{cue}.wav';dest=output/f'{cue}.m4a'
            sf.write(wav,part,model.sample_rate,subtype='PCM_16')
            duration=encode(wav,dest,True)
            manifest['clips'][key]={'text':lines[cue],'hash':fingerprint,'seed':seed,'duration':round(duration,3),'sourceDuration':round(len(part)/model.sample_rate,3),'bytes':dest.stat().st_size,'method':REVISION,'source':'countdown.wav','bounds':list(slices[index]),'referenceSHA256':hashlib.sha256(reference.read_bytes()).hexdigest(),'audioSHA256':hashlib.sha256(dest.read_bytes()).hexdigest()}
        return True
    # Do not ship old isolated takes when the replacement failed verification.
    for key in keys:
        manifest['clips'].pop(key,None)
        (output/f'{key.split("/")[-1]}.m4a').unlink(missing_ok=True)
    return False
