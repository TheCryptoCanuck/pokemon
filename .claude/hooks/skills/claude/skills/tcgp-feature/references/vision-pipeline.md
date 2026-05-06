# Anthropic Vision pipeline

The video-import flow lets the user upload a screen recording of their TCGP collection. The app extracts frames, sends each to Claude Vision, parses the recognized card names, and increments the user's collection. This file documents the pipeline.

## High-level flow

```
User picks video
  ↓
video-processor.ts: Canvas-based frame extraction every 2s
  ↓
For each frame:
  card-recognizer.ts: POST to api.anthropic.com/v1/messages
    model: claude-sonnet-4-6
    image: base64 frame
    prompt: "List every Pokémon TCG Pocket card visible..."
  ↓
Parse model response → array of recognized card names
  ↓
Match each name against cards.extra.json (curly-apostrophe-aware)
  ↓
useCollection.increment(cardId), capped at 2 per card
  ↓
Toast: "Imported N new cards"
```

No backend. The user's API key, the video, the frames, and the responses all flow through the user's own browser. The only outbound destination is `api.anthropic.com`.

## Configuration

Centralized in `src/services/card-recognizer.ts`:

- **Model**: `claude-sonnet-4-6`. This is the only constant the user might want to change in the future. If you change it, verify the new model supports vision.
- **Endpoint**: `https://api.anthropic.com/v1/messages`.
- **Headers**:
  - `x-api-key`: from `localStorage.getItem('tcgp-anthropic-key')`
  - `anthropic-version`: the current API version
  - `anthropic-dangerous-direct-browser-access: true` — required for browser CORS
  - `content-type: application/json`

## Why the cap at 2 copies per card

TCGP allows max 2 copies of any card in a deck. Importing more than 2 is wasted information — the deck builder will never use a 3rd copy.

The cap also makes re-importing safe. If the user re-records and re-imports the same collection, no double-counting happens. This is *the* reason the cap exists; don't remove it. The hook (`useCollection.increment`) enforces the cap; the recognizer just emits names without dedup.

## Frame extraction interval

Currently 2 seconds. The reasoning:

- Slower (e.g. 5s): may miss cards if the user scrolls fast.
- Faster (e.g. 0.5s): consecutive frames are nearly identical, wasting API calls and money.
- 2s: a reasonable scroll cadence shows ~4-6 cards per frame and changes the visible set every frame.

If you change this, run a real test on a 30-second recording and compare recognition recall.

## Prompt design

The recognizer prompt instructs the model to:

1. Look at the image.
2. Identify every TCGP card visible.
3. Return the card names, one per line, no commentary.

Keep the prompt deterministic. Don't ask the model to "be creative" or "infer" — we want the literal names visible on the cards. If the model returns commentary or formatting, the parser strips it; but cleaner prompts mean cleaner output.

If you change the prompt:

1. Test on at least 2 real videos before merging.
2. Check that names with curly apostrophes still come back correctly. Some prompts inadvertently lead the model to "normalize" the apostrophe.
3. Check the unrecognized-card rate (cards visible in frames but not matched).

## Error handling

Network errors are common on phones. The user might be on cellular, the connection drops, the API rate-limits. The recognizer's contract:

- A failed frame is skipped, not retried in-line. The import progresses.
- The toast at the end reports both successes (imported N cards) and failures (M frames failed) if any.
- On total failure (auth error, no network at all), the import aborts cleanly without partial commits to localStorage.

**Never lose a partial import.** If 100 of 150 frames succeeded, those 100 should be imported. The user can re-import the video later for the missing 50; the cap-at-2 means the original 100 won't double-count.

## API key handling

Three rules, no exceptions:

1. Read the key only at request time — `localStorage.getItem('tcgp-anthropic-key')` inside the function that's about to call the API. Don't cache it in a module variable.
2. Never log the key. Not in `console.log`, not in error messages, not in toasts, not in error reporting (there isn't any in this app, but if there ever is — the key is excluded).
3. The key is sent only to `api.anthropic.com`. If you ever add a different outbound destination (analytics, logging), the key must not appear in those requests' headers, body, or query string.

## Cost transparency for the user

Vision API calls aren't free. A 30-second video at 2s intervals is ~15 frames. At Sonnet 4.6 rates, that's a few cents per import. The user should not be surprised.

If you change anything that increases the call rate (lowering the interval, retrying failures, adding multi-shot prompts), update the README's "Video import" section to reflect the new cost ballpark, and surface it in the UI before the import runs.
