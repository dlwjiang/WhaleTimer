# 伴刻 · 你的专注伙伴

伴刻 brings all three companions under one name. Existing saved settings and timer sessions retain their original storage key during the rename.

The companions now speak with three audio-driven mouth shapes. A cached 100 Hz amplitude envelope follows the actual decoded recording and playback clock; smoothing and hysteresis keep syllables lively without flickering. Silence closes the mouth, and pause, reset, mute and audio completion stop it immediately. All 18 poses have registered overlays, with friendly/scolding mouth sets, subtle speaking motion, and occasional idle/happy blinks. Switching characters keeps an ongoing phrase attached to its original speaker. Reduced motion disables facial animation. Browser system-voice fallback retains captions but has no mouth sync because its audio samples are unavailable.

Six generated mouth PNGs add about 14 KB; blinks reuse the existing closed-eye art. No extra voice files, model service, or animation library is needed. See [artwork provenance and pose previews](design/speech/README.md). To spot-check locally, enable sound, tap each companion, then use **计时设置 → 快速体验** to watch the opening countdown, final-three countdown and overtime warning. Check pause and mute midway through speech. No development or preview server was launched for this work.

A mobile-first Vite app with three swappable pixel-art companions: Deepseek, Claude, and ChatGPT. Vanilla JavaScript and CSS; no backend or account required.

On mobile, the character sits behind transparent liquid-glass controls. The dock and header use light translucent layers. The timer dock spans the available mobile width and meets the bottom of the screen, with larger clock cards and controls. Its clear glass has a top highlight and refraction along the top lip; the left, right, and bottom borders and edge shadows are removed. Padding keeps controls inside device safe areas. An embedded 4.5 KB displacement map bends the background without a runtime renderer; a light-blur treatment and opaque reduced-transparency mode provide fallbacks. Controls sit above the optical layers. The avatar is about 15% smaller with a narrow-screen size cap. The headline, quote box, stage row, status tag, and helper copy have been removed from the main screen; speech announcements remain available to screen readers. Small or landscape screens scroll so the face and controls remain accessible; reduced transparency and browsers without backdrop blur get opaque fallbacks.

## Run

Use Node.js 22.12+ (developed with Node 24).

```sh
cd /Users/davidjiang/Documents/GitHub/whaleTimer
npm install
npm run dev
```

Open the local URL printed by Vite. The dev command listens on the local network too, so Vite's network URL can be opened on a phone on the same Wi-Fi. No development or preview server was launched during implementation.

```sh
npm test
npm run build
```

The production app is in `dist/`. Deploy that directory to any static host. The relative Vite base also supports hosting under a subdirectory.

## What is included

- Focus countdown defaults to **3 minutes**, followed automatically by **2 minutes** of extra time. Before the focus timer, she says **“三、二、一，开始！”**; the full configured duration starts only when the voice finishes. Extra time starts immediately after the first-boundary reminder, without repeating the starting countdown. A normal pause/resume does not repeat the intro; interrupting an unfinished intro replays it on resume. Muted or unavailable audio gets a three-second lead-in before focus only; extra time starts without that delay.
- The interface, settings, accessibility labels, and asset studio use Simplified Chinese. Settings accept 0.1–180 minutes per timer and an overtime reminder interval of 1–86400 whole seconds (default 30). Presets include 3 + 2, 25 + 5, and **Quick try: 6 seconds + 12 seconds**. Saving settings resets the current session.
- **Settings → Your companion**, a left/right drag on the main character scene, or the side arrow buttons switch between Deepseek, Claude, and ChatGPT immediately, save the selection locally, and preserve the current timer. Left goes forward; right goes back, wrapping at either end. Dragging rotates the sprites around a three-stop cylinder while the painted backgrounds crossfade. Release snaps to a complete character in 280 ms; short drags and cancelled gestures snap back, while deliberate quick flicks advance. The same rotation accompanies buttons and arrow keys. Reduced motion keeps scenery blending but skips the spatial rotation. With the avatar focused, the left/right arrow keys also switch characters. Vertical scrolling, pinch zoom, greeting taps, and the reset slider retain their own behavior. Older or invalid selections default to Deepseek. Every companion has six distinct transparent expression sprites (idle, happy, cute, angry, frustrated, bell) paired with the existing movement animations; each character has an independently generated Mandarin voice.
- Each companion has six generated transparent pixel-art expressions: idle, happy, cute, angry, frustrated, and bell ringing. The avatar breathes, sways, bounces, rings, and stamps with CSS keyframes. Tapping her gets a reaction.
- A synthesized bell and Chinese speech at the first boundary: “时间到了，我们快一点吧！”
- An angry expression and Chinese speech at the second boundary: “时间真的到了！我要生气啦！”
- In the final three seconds of extra time, she counts **三、二、一**, synchronized with the displayed remaining time. These are three separate short recordings in the same character voice. Late callbacks skip stale numbers, and pause/reload do not replay a consumed digit.
- **重复超时提醒** in settings enables or disables recurring overtime warnings (enabled by default). Disabling keeps the one-time extra-time completion alert and overtime clock, but suppresses recurring speech, captions, and accumulating anger emojis. The preference survives resets and reloads; the disabled interval field retains its last saved value.
- The two progress sections are sized in proportion to their configured durations (3 + 2 minutes gives a 60/40 split), each filling independently. The labels beneath them have been removed.
- Numbered Chinese warnings at the configured interval while overdue (default 30 seconds): “超时了，这是第一次警告！”, then 第二次、第三次, and so on. Angry/frustrated expressions alternate. Numbering follows the elapsed configured overtime intervals, survives pause/reload, and starts over on reset. A late tab skips missed numbers instead of replaying a backlog.
- Slide right to reset. Incomplete or cancelled drags do nothing. The focused reset handle also supports Enter or Space.
- Pause/resume, a sound toggle, local settings and session persistence, keyboard controls, live status messages, and reduced-motion behavior.
- **Settings → Voices & images** opens the asset studio with every bundled voice clip and 18 avatar images. Choose 伙伴声线, search clips by text or ID, play them with native audio controls, and use Stop all. Inspect images on checker/light/dark backgrounds and toggle motion previews. Opening the studio pauses a running timer; closing leaves it paused until you choose Keep going. This is a local asset browser, with no backend or privileged admin operations.

The backgrounds are GPT-generated raster artwork, replacing the earlier SVG motifs and CSS floor rings. A shared watercolor-paper texture fills the page, with three softly painted scenes: pearlescent ocean, warm bookish courtyard, and lilac clouds. Each scene contains its own shaded circular floor platform. The artwork is anchored to the avatar's feet and fades into the surrounding paper; CSS only places the images. The four WebP assets total about 690 KB in `public/backgrounds/`. Original PNGs and the exact prompts are saved in `design/backgrounds/`.

The countdown uses a mechanical split-flap clock themed to the selected character: ocean blue for Deepseek, warm copper and ivory for Claude, and pearl with lilac numerals for ChatGPT. The primary button, progress bars, and selection accents follow the same palette. Only changed digits flip; pause and reduced-motion settings show stable tiles. Long durations and the overtime plus sign remain supported. Please spot-check the hinge animation and legibility on desktop and phone, including the 01:00 → 00:59 rollover.

## Timing and audio behavior

Elapsed time comes from timestamps, not interval counts. Returning to a delayed tab or reloading catches up within the active timer. The first boundary holds the extra timer at its full duration until its reminder finishes. Reloading during an intro leaves it paused until you press Keep going. A late callback emits the current transition/reminder without replaying a queue of old reminders. Backward clock corrections freeze elapsed time until the clock catches up; they never move the session to an earlier phase.

The default voice is an original bright, playful chibi-anime Mandarin character voice, designed with the locally installed Qwen3-TTS VoiceDesign model and continued consistently with VoxCPM2. Short AAC clips are bundled in `public/voice/`; phones need no model, model server, API key, or installed Chinese system voice. Web Audio preloads and caches the clips, and cancels stale playback on pause, reset, mute, or a newer reminder. Deepseek retains her original voice. Claude has a separately designed warm, lower-register anime scholar voice, and ChatGPT has a separately designed high, clear, lively dragon voice. Each has the complete set of 45 recordings, including warning fragments and a paced opening countdown. The new voices use neutral EQ; their identity comes from the recordings. Switching characters selects the next line from that character’s set without interrupting current playback. Clips are cached by their full path, and an unselected new character’s set is not preloaded. The asset studio’s 伙伴声线 selector exposes all three sets. The browser's Mandarin speech synthesis is a fallback if a clip cannot be loaded or decoded.

Warnings 1–10 have full recordings. Higher warning numbers are assembled into one audio buffer from the same voice's prefix, Mandarin numeral sounds, and suffix, so the count does not stop at ten or switch voices. These longer warnings have a more segmented delivery. Full recordings and reusable fragments are available in the asset studio; the older varied reminder clips remain available for review but are no longer used for overtime alerts.

Press Start or enable sound to unlock audio. Chinese speech announcements remain available to screen readers. Browsers may suspend background tabs or audio, especially on a locked phone, so keep this page open for timely spoken reminders. This is an in-page timer, not a system alarm.

The voice reference and generation metadata are in `design/voice/`. `scripts/generate_voice.py` reuses the existing local models and studio Python environment; its header contains regeneration commands. The final character voice should be judged by listening, since transcript verification does not establish perceived cuteness or delivery style.

## Spot check

Automated timer, sand geometry, audio playback/cancellation, and DOM interaction tests pass. The earlier layout was user-reviewed; the revised mobile glass layout and new character voice need a spot check. No server or browser was launched for this revision.

1. Drag left/right across the character on phone and desktop. Confirm the character, scene, clock colors, and control accents switch together. Check a vertical scroll, a normal greeting tap, the side arrows, and the reset slider. In Settings → **Your companion**, confirm the same selection, then close Settings. Confirm the character fits on desktop and phone. Switch during a countdown and confirm it keeps running; reload and confirm the choice persists. Use Quick try with each character to check the bell, countdown pout, angry reminder, and alternating overtime reactions. Switch back to Deepseek and check that her expressions return.
2. Check the page at desktop size and on a phone: mobile should show the smaller avatar behind a more transparent control dock, with her face and hair below the header and no side clipping. The headline, quote box, stage row, status tag, and helper text should be absent. Short screens scroll vertically, and all controls should remain usable without horizontal scrolling.
3. Open Settings → **Quick try** → **Save & reset timer**, then Start. Confirm “三、二、一，开始！” plays while the display holds at 00:06. After six seconds of focus, confirm the bell and reminder, then extra time should start from 00:12 without another starting cue. Then confirm 五、四、三、二、一 as the display shows 00:05 through 00:01, followed by the angry reminder at zero. Pause or reset during an intro to confirm it cannot start later on its own.
4. Wait another 30 seconds for “超时了，这是第一次警告！”, then another 30 seconds for “超时了，这是第二次警告！”. Reload and verify the next warning continues the count; reset should begin again with 第一次.
5. Pause and resume; the countdown or overdue counter should freeze while paused. Mute and verify the timer and avatar still update.
6. Drag the reset handle partway and release (no reset), then all the way (fresh idle timer). Also try Enter on the focused handle.
7. Set 3 + 2 again, start, and reload. The running session should continue accurately. Saving new settings should reset it.
8. Open **Voices & images** while running. Confirm the timer pauses, each clip plays, starting a different clip stops the first, and closing the panel stops playback. Inspect all 18 images and motion previews. Resume the timer manually when done.

## Project map

- `src/ui.js`: interface, captions, expressions, settings, persistence, and drag interactions.
- `src/flip-clock.js` and `src/flip-clock.css`: accessible split-flap clock rendering and hinge animation, independent of timer timing.
- `src/timer.js`: clock-driven timer state machine.
- `src/audio.js`: bell synthesis, bundled character-voice playback, and system-voice fallback.
- `src/warnings.js`: Mandarin warning-number formatting and reusable speech segments.
- `src/admin.js` and `src/admin.css`: local voice and image asset studio.
- `src/style.css`: responsive layout and avatar keyframes.
- `src/character-swipe.js`: horizontal pointer gestures with direction locking, flick detection, cancellation, click suppression, and scroll preservation.
- `src/character-carousel.js`: three-stop cylinder rotation, drag-linked scenery crossfades, 280 ms snap settling, expression previews, and reduced-motion support.
- `src/character-theme.css`: character-specific clock/control palettes and swipe/navigation styles.
- `src/characters.js`: shared character catalog, image paths, and idle-pose fallback for characters without separate expressions.
- `public/avatars/`: 18 transparent 512×512 lossless WebP expression sprites; Claude and ChatGPT have their own folders.
- `design/avatars/`: generated source sheets, contact sheets, prompts, and asset manifests. Claude and ChatGPT state sheets and extraction records are in their respective subfolders. Generated using built-in image generation from the approved `whale-maid-avatar-concept-v2.png`; excluded from production assets.
- `public/voice/`: compact AAC character voice clips and manifest.
- `design/voice/`: original voice reference, source WAVs, text map, generation metadata, and transcript verification.
- `scripts/generate_voice.py`: reproducible local voice design, synthesis, encoding, and verification.
- `tests/`: Node tests for timer boundaries, delayed callbacks, restoration, clock corrections, sand volume, and DOM interactions.

Vite setup follows the current [official Vite guide](https://github.com/vitejs/vite/blob/main/docs/guide/index.md), retrieved via Context7.

Latest spot check: in **计时设置**, change **超时提醒间隔** from 30 to 10 seconds, save, and use **快速体验**. After extra time ends, verify warnings at 10-second intervals. Reload to check the setting persists. Switch all three companions and inspect the themed scenery and perspective ring under their feet on mobile. No development or preview server was started for these changes.

Background spot check: refresh on mobile and switch all three companions. Check the paper texture, painted details, and alignment of feet with the generated platform. All scenery was generated with the built-in GPT image tool; no local development or preview server was started.


Speech now appears beside the active character’s mouth as outlined Chinese lettering, without a quote box. Individual glyphs pop in with a small stagger; the final three countdown digits get a larger bounce, and warning lines get a brief emphasis. The opening 三、二、一、开始！ uses that same countdown bounce one beat at a time, starting with audio playback and following its clock. Muted sessions use the same animation with a local clock. Speech, countdowns, and warnings keep one consistent color per character: ocean blue for Deepseek, amber for Claude, and lilac for ChatGPT, with matching shadows and a light outline. Captions replace one another, fade away after a short hold, and stay visible without motion when reduced motion is enabled. Positioning follows the contained sprite and clamps text inside the phone width.

The speech font is **站酷快乐体 / ZCOOL KuaiLe**, downloaded from the [official Google Fonts repository](https://github.com/google/fonts/tree/main/ofl/zcoolkuaile) and bundled at `public/fonts/ZCOOLKuaiLe-Regular.ttf`; its original OFL license is included alongside it. The font is served locally, with system Chinese fallbacks while loading. It also styles the brand and settings heading. Please spot-check mouth placement for all three characters and the 五、四、三、二、一 animation using 快速体验. No development or preview server was started.


To regenerate the new voices with the installed local models, run `scripts/generate_voice.py` with `--character claude` or `--character chatgpt` for each action: `design`, `clips`, `timer-start`, and `verify`. Use the studio Python environment documented in the script. The references, source WAVs, prompts, seeds, and transcript checks are under `design/voice/<character>/`; the AAC recordings and manifests are under `public/voice/<character>/`. New countdown digits are paced to fit their slots without truncating speech or changing pitch, and original unpaced WAVs are retained when adjustment is needed. The opening uses the same 0 / 0.8 / 1.6 / 2.4-second visual beats for every voice.

The new sets add about 2 MB in total. Both assembled countdowns and opening cues passed local transcript checks. Claude’s 五 and ChatGPT’s tenth warning and 万 were regenerated after unclear first takes. ChatGPT’s 百 was extracted from its own naturally spoken counting phrase; `design/voice/chatgpt/numeral-100-extraction.json` records the exact source, boundaries, padding, and fades. The reference pitch measurements are diagnostics, not a substitute for listening to the character delivery. Some isolated one-syllable ASR results are ambiguous; final countdown and assembled warning checks provide the relevant context.

Glass spot check: refresh on your phone and switch companions. The scenery should remain visible through the timer dock, with a narrow top lens edge and a diagonal reflection, and no side or bottom frame; digits and controls should stay sharp. The enhanced SVG backdrop refraction was visually checked in local-file Chrome. Please check the appearance in your phone browser too; no server was started. The map can be regenerated with `python3 scripts/generate-glass-map.py`. Implementation references: [MDN backdrop-filter](https://developer.mozilla.org/en-US/docs/Web/CSS/Reference/Properties/backdrop-filter) and [SVG displacement maps](https://developer.mozilla.org/en-US/docs/Web/SVG/Reference/Element/feDisplacementMap).

Desktop layout: above 700 px, the character, painted platform, name, and timer dock form one centered column. Navigation arrows flank the character; start and reset share a row below the clock. Scene height follows the viewport with a minimum size so short windows can scroll. The upper-right helper text and reset chevrons are removed. Mobile keeps its existing arrangement with roughly 20% more vertical glass area, extending the dock upward. Local-file Chrome was used for visual checks without starting a server.

Glass tuning: open **计时设置 → 磨砂玻璃调节** for a floating, non-modal live preview panel. Adjust blur, saturation, tint, sheen, top highlight, and top refraction, then use **复制 JSON** to export the versioned recipe. Drafts are saved separately from timer state and restored on reload; **恢复默认** restores the starting mobile recipe. Clipboard failures reveal selectable JSON for manual copying. The tuning recipe previews on both desktop and mobile. The companion name/helper text at the avatar’s feet has been removed.

Refraction correction: Portfolio’s `portfolio/app/components/HeroParticleText.tsx` clears each lens area before redrawing its refracted stars. This app now uses one unmasked backdrop filter on the dock for refraction and blur; the reflection/tint layer does not filter a second background copy. The top-edge fade is encoded in the map, not opacity. `src/glass-lens.js` sizes the embedded map in actual dock pixels with ResizeObserver, avoiding percentage dimensions resolving against the zero-size SVG defs viewport. A local-file black/white stripe comparison verified that the top bends without ghosting and the lower pane remains registered. Existing tuning JSON remains compatible.
