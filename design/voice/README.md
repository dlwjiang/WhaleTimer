# Tide’s local Mandarin voice

An original synthetic anime character voice: youthful adult female, bright and light, playful and sweet, with clear Mandarin diction. Impatient reminders should sound like cute, pretend scolding rather than aggressive shouting. The character does not imitate a real performer.

`lines.json` is the source of truth for exact Chinese phrases and public AAC filenames. The app can import its `clips` array without importing source recordings. `reference.wav` and `reference.json` hold the designed voice and its exact transcript, description and seed. Other WAV files are lossless source recordings; the app loads only the small `.m4a` clips in `public/voice/`.

## Local generation

The existing Python environment and model weights are reused. No API, server, or model download is involved:

```sh
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py design
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py clips
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py verify
```

Run these commands from the whaleTimer repository. MLX requires access to the Mac’s Metal GPU; a sandbox without GPU access cannot run the two synthesis steps. The script explicitly enables offline Hugging Face mode. The verification step uses the already cached Faster Whisper small model on CPU.

Models:

- `~/Models/tts/Qwen3-TTS-12Hz-1.7B-VoiceDesign-bf16`: creates the original voice from a written description.
- `~/Models/tts/VoxCPM2-bf16`: continues the same synthetic reference voice for every phrase, with a deterministic seed derived from the phrase.
- Cached `Systran/faster-whisper-small`: independently transcribes each WAV for pronunciation/content checks.

The synthesis script supports environment overrides for all three paths. It saves source WAV, then encodes mono AAC at 24 kHz / 96 kbit/s into `.m4a` containers with fast-start metadata. Cloning resumes from existing WAV files so interrupted batches do not discard completed work. Remove a specific generated WAV before regenerating that line with changed settings. If changing the reference voice, remove all derived phrase WAVs before running `clips` again.

The delivered clips were checked with the stronger, already cached Whisper **medium** model using `WHALE_VOICE_ASR_MODEL=~/.cache/huggingface/hub/models--Systran--faster-whisper-medium/snapshots/08e178d48790749d25932bbc082711ddcfdfbc4f`. The default runner remains the smaller cached model for quicker routine checks. Verification supplies decoded 16 kHz arrays with silence padding to avoid the local PyAV incompatibility and VAD dropping short opening words.

`verification.json` contains intended text, locally transcribed text, phonetic similarity, duration and peak amplitude. Transcription scores are useful content checks; they do not prove the subjective character style or replace listening approval.

The delivered set contains 17 clips, 36.30 seconds of speech and 478,000 bytes of AAC. Both timer transition lines transcribed exactly. Remaining recognition differences mostly involve final particles. One reminder (`reminder-finish`) was heard by Whisper as “此后一点点” instead of “最后一点点”; whether this is an ASR error needs a listening check. See `verification-notes.json` for the audit and this explicit limitation. Subjective kawaii voice quality has not been auditioned because the assistant runtime does not support audio input.

API syntax was checked against the installed mlx-audio 0.6.1 implementation and current upstream documentation via Context7:

- https://github.com/blaizzy/mlx-audio/blob/main/docs/guides/voice-cloning.md
- https://github.com/blaizzy/mlx-audio/blob/main/docs/models/tts/voxcpm2.md

## Final-five-second countdown

Five additional clips use the same designed reference voice: `countdown-5.m4a` (五, 0.326 s), `countdown-4.m4a` (四, 0.628 s), `countdown-3.m4a` (三, 0.378 s), `countdown-2.m4a` (二, 0.308 s), and `countdown-1.m4a` (一, 0.307 s). Their combined download size is 28,073 bytes. Every encoded AAC file is shorter than 0.8 seconds, so it fits a one-second timer boundary without overlap. The app now has 22 voice clips in total.

`countdown-demo.wav` is a five-second audition artifact with the digits placed exactly at seconds zero through four. Locally cached Whisper-medium transcribed it as “五 四 三 二 一”, an exact phonetic match; see `countdown-verification.json`. The original 17 AAC files were preserved.

```sh
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py clips --only countdown-5,countdown-4,countdown-3,countdown-2,countdown-1
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py countdown-demo
../SocraticMeowWoof/studio/.venv/bin/python scripts/generate_voice.py verify --only countdown-demo
```

The `--only` generation option merges selected clips into the existing public manifest. Previously encoded clips are left untouched unless their source WAV is newly regenerated. Selective verification writes `countdown-verification.json` so the original full-phrase verification remains available.

## Numbered overtime warnings

`warning-1.m4a` through `warning-10.m4a` contain natural full-sentence recordings of “超时了，这是第…次警告！”, using 一 through 十. Later counts can use the same voice through these reusable fragments:

- `warning-prefix.m4a`: 超时了，这是第
- `warning-suffix.m4a`: 次警告！
- `numeral-0.m4a`, `numeral-6.m4a` through `numeral-9.m4a`: 零、六、七、八、九
- `numeral-10.m4a`, `numeral-100.m4a`, `numeral-1000.m4a`, `numeral-10000.m4a`, `numeral-100000000.m4a`: 十、百、千、万、亿
- Existing `countdown-1.m4a` through `countdown-5.m4a` supply 一 through 五.

The app's number formatter is responsible for selecting Mandarin numeral tokens in order. `warning-generation.json` lists the 22 new asset IDs; together with the preserved earlier assets, the complete manifest contains 44 clips. Long ordinals use separately generated fragments and may have a more segmented cadence than the first ten full recordings.

Generate only the warning IDs with the existing `clips --only` action. Run `warning-demos` to construct local audition WAVs for the eleventh, twenty-first and one-hundred-and-first warnings using exactly the reusable fragments. `warning-demos.json` records their part order. Selective non-countdown checks write `warning-verification.json`, preserving earlier verification reports.

All ten final full warnings and the three stitched demos transcribed exactly with locally cached Whisper-medium. The sixth warning uses a deterministic alternate take (`--only warning-6 --seed-offset 1`), after the first take’s “警告” was recognized incorrectly. That rejected take remains clearly named in `design/voice/` for provenance. The new 22 AAC clips add 406,756 bytes. See `warning-verification.json` and `warning-verification-notes.json` for final evidence; `warning-first-takes-verification.json` is the historical first-pass report.

## Before-timer countdown

`timer-start.m4a` says “三、二、一，开始！” in 2.879 seconds. It reuses the verified 三、二、一 recordings and a new locally generated “开始！” ending in the same voice. The digits start at 0.0, 0.8, and 1.6 seconds; “开始” starts at 2.4 seconds. The resulting AAC clip is 22,188 bytes at 24 kHz mono. Both the complete phrase and its `timer-start` ID appear in the app’s standard mapping and manifest (45 clips total).

The reproducible `timer-start` action in `scripts/generate_voice.py` creates this paced composition. `timer-start.json` records the exact assembly; `timer-start.wav` is the lossless source. The internal ending recording remains in `design/voice/` and is not separately exposed as an app phrase. `timer-start-verification.json` holds the local transcript check.

## Short reset cue

The reset cue is now “重新开始吧”. All three characters' `reset.wav` and deployed `reset.m4a` files were regenerated with their existing voice references using local VoxCPM2 (`clips --only reset --character …`). Durations: Deepseek 0.979 s, Claude 0.949 s, ChatGPT 0.988 s. Each character directory contains `reset-verification.json`; local Whisper transcribed all three exactly. The previous longer WAV, AAC and manifest entry are preserved under each design directory's `reset-original/` folder. Selective reset verification writes its own report rather than overwriting warning checks.

Reset now cancels previous speech and plays this cue when sound is enabled, including drag, keyboard and settings-save resets. Muting still leaves the visible caption without audio.
