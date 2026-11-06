import voiceLines from '../design/voice/lines.json' with { type: 'json' };

export const VOICE_SETS = [
  { id: 'whale', name: '鲸鱼女仆', description: '清甜元气', directory: '' },
  { id: 'claude', name: 'Claude', description: '温暖学姐', directory: 'claude/' },
  { id: 'chatgpt', name: 'ChatGPT', description: '清脆小龙', directory: 'chatgpt/' },
].map(voice => ({ ...voice, clips: voiceLines.clips.map(clip => ({ ...clip, file: `${voice.directory}${clip.file}` })) }));

export const CHARACTER_CLIPS = Object.fromEntries(VOICE_SETS.map(voice => [
  voice.id, Object.fromEntries(voice.clips.map(clip => [clip.text, clip.file])),
]));
