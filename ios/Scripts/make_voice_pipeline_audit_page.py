from pathlib import Path
import json,base64,html
r=Path(__file__).resolve().parents[1];cast=r/'Design/Voices/VoiceCasting';choices=json.loads((cast/'approved-choices.json').read_text());m=json.loads((r/'Banke/Audio/Voices/manifest.json').read_text())
def uri(p,mime):return 'data:'+mime+';base64,'+base64.b64encode(p.read_bytes()).decode()
def audio(p,mime):return '<audio controls preload="none" src="'+uri(p,mime)+'"></audio>'
def e(v):return html.escape(v,quote=True)
parts=[]
for c,sel in choices['selectedVoices'].items():
 ref=audio(cast/'audio'/f'{sel["voice"]}.m4a','audio/mp4')
 raw='';encoded=''
 for cue in ['greeting','poke']:
  label='<p><b>'+cue.title()+'</b> · '+e(m['clips'][f'en/{c}/{cue}']['text'])+'</p>'
  raw+=label+audio(r/'Design/Voices/ApprovedProduction'/c/'en'/f'{cue}.wav','audio/wav')
  encoded+=label+audio(r/'Banke/Audio/Voices/en'/c/f'{cue}.m4a','audio/mp4')
 parts.append('<article><header><img alt="" src="'+uri(cast/'images'/f'{c}.png','image/png')+'"><div><h2>'+c.title()+'</h2><p>'+e(sel['name'])+' · '+e(sel['model'])+'</p></div></header><div class="columns"><section><h3>A · Chosen audition</h3><p>'+e(choices['auditionText'])+'</p>'+ref+'</section><section><h3>B · Generated WAV before encoding</h3>'+raw+'</section><section><h3>C · Actual bundled AAC</h3>'+encoded+'</section></div></article>')
page='''<!doctype html><html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>Tick & Kin · Voice pipeline audit</title><style>*{box-sizing:border-box}body{background:#f7f4ed;color:#243c40;font:16px/1.5 system-ui;margin:0}main{max-width:1250px;margin:32px auto;padding:24px}h1{font:40px Georgia}h2{margin:0}h3{font-size:16px}article{margin:24px 0;background:#fffefa;border:1px solid #ddd8ca;border-radius:20px;padding:24px}header{display:flex;gap:20px;align-items:center}header img{width:96px;height:96px;object-fit:contain;image-rendering:pixelated}.columns{display:grid;grid-template-columns:repeat(3,minmax(0,1fr));gap:24px}audio{width:100%}p{color:#5b6c6d}.notice{background:#eee6d6;border-radius:12px;padding:16px}@media(max-width:850px){.columns{grid-template-columns:1fr}h1{font-size:30px}}</style><main><h1>Where did the voice change?</h1><p class="notice">These are existing files from the production pipeline. No new voices were generated. A is your exact selection; B and C say the same app lines. Compare B against C to isolate encoding changes. A uses different words, so it is a character/timbre reference, not a controlled same-sentence comparison. This page covers English greetings and pokes for all 12 characters; the machine audit covers all 1,248 clips.</p>'''+''.join(parts)+'''<p>All media is embedded. Open this file directly; no server or upload is needed. The report distinguishes reference provenance from human-approved sound quality.</p></main><script>document.addEventListener('play',e=>{if(e.target.tagName==='AUDIO')document.querySelectorAll('audio').forEach(a=>{if(a!==e.target)a.pause()})},true)</script></html>'''
out=r/'Verification/VoicePipelineAudit/compare.html';out.write_text(page);print(out,round(out.stat().st_size/1024/1024,1),'MB',page.count('<audio controls'),'audio clips')
