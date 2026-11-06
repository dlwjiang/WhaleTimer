# Speech artwork

The six mouth sprites in `public/avatars/speech/` were generated with the built-in GPT image tool. `prompt.txt` contains the generation and cleanup prompts; `mouth-sheet.png` is the untouched selected output. Row order: friendly closed/small/open, then stern closed/small/open.

Preparation used deterministic 512px grid crops, alpha cleanup at 50% to remove stray almost-transparent pixels, centered 256×192 canvases, and downsampling to 64×48 PNGs. The six deployed files total 13,742 bytes. Original character and voice files are unchanged.

The generated eyelid experiment is retained in `blink-sheet.png`, `blink-prompt.txt`, and `unused-blinks/`, but is **not deployed**. Its flat skin covers were too obvious. Final blinks reuse small, registered eye regions from each character's existing `cute.webp` so eyelashes, shading and hair match. Blinks only run on idle/happy faces; other expressions retain their original eyes.

`src/portrait.js` contains the 512px registration and skin samples for all 18 poses. The portrait and base image share one animated wrapper and the same contain scaling, including during carousel rotation. Missing mouth images leave the original face intact.

`previews/whale.png`, `claude.png` and `chatgpt.png` are inspected static composites. Rows: idle, happy, cute, angry, frustrated, bell. Columns: original, closed mouth, small mouth, open mouth, blink. They verify registration and masking, not browser playback timing. Run `node scripts/preview-portraits.mjs` to regenerate standalone SVG contact sheets in the system temporary directory, or supply an output directory argument. This does not launch a server.
