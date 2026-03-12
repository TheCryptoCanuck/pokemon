import { Card, CollectionEntry, getCardId } from "../types/card";
import { ExtractedFrame, frameToBase64 } from "./video-processor";

const API_URL = "https://api.anthropic.com/v1/messages";

interface RecognizedCard {
  name: string;
  confidence: "high" | "medium" | "low";
}

async function recognizeFrame(
  frame: ExtractedFrame,
  apiKey: string
): Promise<RecognizedCard[]> {
  const base64 = frameToBase64(frame);
  const mediaType = frame.dataUrl.startsWith("data:image/png")
    ? "image/png"
    : "image/jpeg";

  const response = await fetch(API_URL, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "anthropic-dangerous-direct-browser-access": "true",
    },
    body: JSON.stringify({
      model: "claude-sonnet-4-20250514",
      max_tokens: 1024,
      messages: [
        {
          role: "user",
          content: [
            {
              type: "image",
              source: { type: "base64", media_type: mediaType, data: base64 },
            },
            {
              type: "text",
              text: `This is a screenshot from the Pokémon TCG Pocket mobile game showing a card collection screen.
Identify ALL Pokémon TCG Pocket cards visible in this image.

For each card, provide:
- The exact card name as it appears (e.g., "Pikachu ex", "Professor's Research", "Charizard")

Respond in JSON format only:
{"cards": [{"name": "CardName", "confidence": "high"}, ...]}

If no cards are visible, respond: {"cards": []}
Only include cards you can clearly identify. Use "high" confidence for clearly readable names, "medium" for partially visible, "low" for guesses.`,
            },
          ],
        },
      ],
    }),
  });

  if (!response.ok) {
    const err = await response.text();
    throw new Error(`API error ${response.status}: ${err}`);
  }

  const data = await response.json();
  const text = data.content?.[0]?.text || "";

  try {
    const jsonMatch = text.match(/\{[\s\S]*\}/);
    if (!jsonMatch) return [];
    const parsed = JSON.parse(jsonMatch[0]);
    return parsed.cards || [];
  } catch {
    return [];
  }
}

export async function recognizeCards(
  frames: ExtractedFrame[],
  apiKey: string,
  allCards: Card[],
  onProgress?: (current: number, total: number) => void
): Promise<CollectionEntry[]> {
  const cardCounts = new Map<string, number>();

  // Process frames in batches of 3 for speed
  const batchSize = 3;
  for (let i = 0; i < frames.length; i += batchSize) {
    const batch = frames.slice(i, i + batchSize);
    const results = await Promise.all(
      batch.map((frame) => recognizeFrame(frame, apiKey).catch(() => []))
    );

    for (const recognized of results) {
      for (const card of recognized) {
        if (card.confidence === "low") continue;

        const matches = allCards.filter(
          (c) => c.name.toLowerCase() === card.name.toLowerCase()
        );

        for (const match of matches) {
          const id = getCardId(match);
          cardCounts.set(id, (cardCounts.get(id) || 0) + 1);
        }
      }
    }

    onProgress?.(Math.min(i + batchSize, frames.length), frames.length);
  }

  // Convert counts - cap at reasonable amounts (seeing a card in multiple frames
  // doesn't mean you own multiple copies, default to 1)
  return Array.from(cardCounts.entries()).map(([cardId]) => ({
    cardId,
    count: 1,
  }));
}

const API_KEY_STORAGE = "tcgp-anthropic-key";

export function getStoredApiKey(): string {
  return localStorage.getItem(API_KEY_STORAGE) || "";
}

export function setStoredApiKey(key: string) {
  if (key) {
    localStorage.setItem(API_KEY_STORAGE, key);
  } else {
    localStorage.removeItem(API_KEY_STORAGE);
  }
}
