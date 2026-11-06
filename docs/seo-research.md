# Banke search and AI-answer research

Researched 2026-11-06. This is a qualitative search-intent assessment, not a keyword-volume report. Public posts show community language and product interest; they do not establish what employees of DeepSeek, Anthropic, or OpenAI privately search for.

## Positioning and query priorities

Lead with **DeepSeek anime maid focus timer**. The product connects an identifiable fan character to a concrete task: finishing a coding, study, or writing session. Retain **伴刻 / Banke** as the product name.

| Priority | Query cluster | Evidence and intended use |
| --- | --- | --- |
| Primary | DeepSeek-chan, DeepSeek anime maid, DeepSeek whale girl, Whale-chan | Community fan art and desktop-pet posts establish these terms. Explain the character, show the actual app artwork, and offer the timer. |
| Primary, Chinese | DeepSeek 鲸鱼娘, DeepSeek 娘, 大肥鱼; combinations with 专注计时器 / 番茄钟 | Chinese fan names appear in community material. The productivity combinations are hypotheses to measure, not proven search demand. |
| Secondary | anime focus timer, anime companion timer, AI avatar Pomodoro, AI study buddy | Strong fit with the experience; exact-phrase demand is unverified. Explain the current focus + wrap-up behavior instead of promising automatic Pomodoro work/rest cycles. |
| Secondary | coding companion, focus timer for developers, vibe-coding timer | Developer companion projects connect mascots with focus reminders. Use concrete examples such as one bug fix, paper section, or eval review. |
| Supporting | Claude anime avatar, ChatGPT anime avatar, Claude companion | These are actual selectable fan characters. Include them as choices, with accurate artwork descriptions. |
| Context only | Clawd, Claudia, GPT-chan, DeepSeek rice meme, desktop pet | Useful neighboring interests, but distinct characters/features. Avoid labeling Banke as Clawd, a chatbot, an agent integration, or an always-on-top desktop pet. |

Avoid broad “DeepSeek” or “ChatGPT” acquisition copy that suggests this is the official model service. Avoid “meme generator,” “avatar generator,” or “sticker download”: this page does not provide those functions. “Animedoro” often means watching anime during breaks and is not a close match to this timer.

## Observations and sources

1. [DeepSeek whale-girl fan sticker repository](https://github.com/DejavuMoe/deepseek_wale_girl) documents the fan-made whale-girl visual vocabulary, including maid and rice-related expressions. It supports the character terminology, not claims of official branding.
2. [Big Whale coding companion announcement](https://github.com/deepseek-ai/deepseek-harness/discussions/11557), posted October 30, 2026, combines a whale-girl companion with voice, expressions, focus reminders, and rice imagery. This is direct developer-community evidence for the mascot/productivity overlap.
3. [DeepSeek-chan desktop pet creator post](https://www.reddit.com/r/DeepSeek/comments/1xmo5vh/made_a_deepseekchan_desktop_pet_that_eats_rice/) describes a rice-eating, conversational pet. The connection to a browser focus companion is an inference; Banke does not implement that post's voice-chat features.
4. [X.PIN's November 2 culture roundup](https://www.thexpin.com/p/weekly-dose-of-china-tech-110226) discusses the blue-haired whale maid, rice/work-avoidance jokes, and neighboring Claude/Claudia and GPT fan characters. Use it for broad cultural context, not definitive artwork provenance or endorsements.
5. [Clawd desktop buddy creator post](https://www.reddit.com/r/vibecodingcommunity/comments/1xglqrc/clawd_desktop_buddy/) shows adjacent interest in pixel-art coding companions in the Claude community. It does not establish Anthropic employee search habits or justify calling Banke's scholar avatar “Clawd.”
6. [GPT-chan community example](https://www.reddit.com/r/ChatGPT/comments/1tuyjwl/gpt_chan_create_an_image_of_how_i_see_you_and/) shows the fan nickname in use. Evidence here is thinner than the DeepSeek cluster, so it is not the lead target.
7. Public results for anime Pomodoro and “study with me” indicate an adjacent productivity theme. No search-volume, click-through, conversion, or competition claims are made from those results.

## Keyword-volume limitation

Treg's Serpstat endpoint was checked for 20 terms against its US Google database (`g_us`). The request was rejected before data retrieval: estimated cost $0.01, available balance approximately $0.006. No volume data was returned. Missing numbers must remain unknown, not zero. Funding Treg would allow the measurement; Chinese-market demand needs separate research and cannot be inferred from a US database.

## Implementation rationale

- Put the guide in the delivered `index.html`, outside the JavaScript-owned app root. Search and answer engines can read definitions, feature facts, limitations, and citations without executing the timer.
- Preserve the full-height timer as the first screen. The guide below it is visible content, including on phones; it is not hidden keyword text.
- Use one descriptive H1, concise title and description, bilingual paragraphs with language attributes, descriptive image alt text, and linked source context.
- Provide direct answers to the main intent mismatches: Pomodoro versus wrap-up time, AI theme versus live inference, browser companion versus desktop pet, free access, saved settings, and language availability.
- Describe the actual app with `WebApplication` JSON-LD. Do not invent reviews, ratings, endorsements, or an English interface. The markup describes the product; it does not promise a Google software-app rich result.
- Allow crawling with `robots.txt`. The canonical URL, sitemap, and absolute social-image URLs use `https://whaletimer.vercel.app/`, discovered in the repository's GitHub homepage metadata and checked to return HTTP 200 on November 6, 2026. The social preview reuses the actual 512 × 512 whale-maid sprite. If a custom domain becomes primary, update these URLs together in `index.html`, `public/robots.txt`, and `public/sitemap.xml`.
- No special “GEO schema” or `llms.txt` is necessary for Google AI features. Google's [AI features guidance](https://developers.google.com/search/docs/appearance/ai-features) emphasizes crawlability, useful textual content, internal links, and structured data that matches the visible page.
- Visible FAQs help answer specific questions. Do not promise FAQ rich results: Google's [FAQ eligibility guidance](https://developers.google.com/search/blog/2023/08/howto-faq-changes) restricts those displays to authoritative government and health sites.

## Verification and follow-up

`npm test` passed all 135 existing tests. `npm run build` succeeded. No development or preview server was started. Inspect the production HTML for the guide and valid JSON-LD; check local image and CSS paths. The user should spot-check the first-screen timer and the guide at desktop and phone widths, FAQ disclosure controls, and the links back to the timer.

After deployment, confirm public 200 responses, the selected canonical, and crawler access through the host/CDN; inspect the URL in Search Console and submit the sitemap. Compare query impressions and clicks for the clusters above over several weeks. Do not infer a ranking win from merely shipping metadata. Measure engagement with the timer before creating more pages; avoid thin keyword-variant landing pages.
