#!/usr/bin/env python3
"""Build a local-file audio review page. No server, network, or app changes needed."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
voices = ROOT / 'Banke/Audio/Voices'
manifest = json.loads((voices / 'manifest.json').read_text())
transcripts = json.loads((ROOT / 'Verification/voice-transcripts.json').read_text())['clips']
clips = [{'key': key, 'text': entry['text'], 'seconds': entry['duration'],
          'heard': transcripts.get(key, {}).get('heard', ''),
          'review': transcripts.get(key, {}).get('review', '')}
         for key, entry in manifest['clips'].items()]
page = r'''<!doctype html>
<html lang="en"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Tick &amp; Kin voice audition</title>
<style>
body{font:16px/1.5 system-ui,sans-serif;margin:32px auto;padding:0 20px;max-width:880px;color:#243445;background:#faf9f5}
h1{font-size:26px;margin-bottom:4px}p{margin-top:4px}label{display:inline-block;margin:8px 20px 16px 0}
select,button{font:inherit;padding:8px 12px;border:1px solid #ccd3d9;border-radius:8px;background:white;color:inherit}
button{cursor:pointer}button:focus-visible,select:focus-visible{outline:3px solid #286992;outline-offset:2px}
audio{width:100%;margin:8px 0}#now{min-height:48px;font-weight:600}#status{color:#75551c}
table{width:100%;border-collapse:collapse}th,td{text-align:left;vertical-align:top;padding:12px 8px;border-bottom:1px solid #ddd}
th:first-child{width:130px}.note{font-size:13px;color:#6a665e}.flag{color:#855b18}caption{text-align:left;font-weight:600;margin:8px}
@media(max-width:600px){body{margin-top:16px}th,td{padding:10px 4px}th:first-child{width:90px}}
</style>
<h1>Tick &amp; Kin voice audition</h1>
<p id="total"></p>
<p class="note">Local review tool. Open this file directly; recordings stay on this computer. Mandarin audio serves both Chinese writing systems. Transcripts are diagnostics, not pronunciation approval.</p>
<label>Companion <select id="character"></select></label>
<label>Spoken language <select id="language"></select></label>
<div id="now" aria-live="polite">Choose a cue to listen.</div>
<audio id="player" controls preload="none"></audio><p id="status" role="status"></p>
<table><caption id="selection"></caption><thead><tr><th>Cue</th><th>Script and diagnostic</th><th>Listen</th></tr></thead><tbody id="rows"></tbody></table>
<script>
'use strict';
const clips=__DATA__;
const languages={'en':'English','zh-Hans':'Mandarin · 中文','ja':'Japanese · 日本語','ko':'Korean · 한국어','es':'Spanish · Español','pt-BR':'Portuguese · Brasil','fr':'French · Français','de':'German · Deutsch'};
const characters=['mochi','pip','pebble','jun','bean','maple','luna','atlas','wisp','nova','orbit','comet'];
const cueNames={'greeting':'Greeting','5':'5','4':'4','3':'3','2':'2','1':'1','go':'Begin','pause':'Pause','resume':'Resume','reset':'Start over','focusComplete':'Focus complete','breakComplete':'Break complete'};
const cueOrder=['greeting','poke','5','4','3','2','1','go','pause','resume','reset','focusComplete','breakComplete'];
const character=document.querySelector('#character'),language=document.querySelector('#language'),player=document.querySelector('#player');
for(const name of characters)character.add(new Option(name[0].toUpperCase()+name.slice(1),name));
for(const [key,label] of Object.entries(languages))language.add(new Option(label,key));
document.querySelector('#total').textContent=`${clips.length} bundled recordings · ${characters.length} companions · 8 spoken languages`;
function render(){
  player.pause();player.removeAttribute('src');player.load();
  document.querySelector('#now').textContent='Choose a cue to listen.';
  document.querySelector('#status').textContent='';
  const rows=document.querySelector('#rows');rows.replaceChildren();
  document.querySelector('#selection').textContent=`${character.selectedOptions[0].text} — ${languages[language.value]}`;
  const selected=clips.filter(c=>c.key.startsWith(`${language.value}/${character.value}/`));
  selected.sort((a,b)=>cueOrder.indexOf(a.key.split('/')[2])-cueOrder.indexOf(b.key.split('/')[2]));
  for(const clip of selected){
    const cue=clip.key.split('/')[2],row=document.createElement('tr');
    const title=document.createElement('th');title.scope='row';title.textContent=cueNames[cue];
    const script=document.createElement('td');script.textContent=clip.text;
    const diagnostic=document.createElement('div');diagnostic.className='note'+(clip.review==='check'?' flag':'');
    diagnostic.textContent=clip.review==='check'?`Transcript differs; listen to judge: ${clip.heard}`:`${clip.seconds.toFixed(2)} seconds`;
    script.append(diagnostic);
    const action=document.createElement('td'),button=document.createElement('button');button.textContent='Play';
    button.setAttribute('aria-label',`Play ${cueNames[cue]}`);
    button.onclick=()=>{
      document.querySelector('#now').textContent=`${character.selectedOptions[0].text} · ${cueNames[cue]}: ${clip.text}`;
      document.querySelector('#status').textContent='';
      player.src='../Banke/Audio/Voices/'+clip.key+'.m4a';
      player.play().catch(()=>{document.querySelector('#status').textContent='Playback did not start. Use the audio controls, or check that this file remains in ios/Verification beside the app sources.';});
    };
    action.append(button);row.append(title,script,action);rows.append(row);
  }
}
character.onchange=render;language.onchange=render;render();
</script></html>
'''
page = page.replace('__DATA__', json.dumps(clips, ensure_ascii=False).replace('<', '\\u003c'))
output = ROOT / 'Verification/voices.html'
output.write_text(page)
print(f'{len(clips)} clips indexed in {output}')
