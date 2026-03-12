import { Card, CollectionEntry, getCardId } from "../types/card";
import { ExtractedFrame, frameToBase64 } from "./video-processor";

const API_URL = "https://api.anthropic.com/v1/messages";

interface RecognizedCard {
  name: string;
  confidence: "high" | "medium" | "low";
}

export interface RecognizeResult {
  entries: CollectionEntry[];
  warnings: string[];
}

function normalize(s: string): string {
  return s.toLowerCase().replace(/[^a-z0-9]/g, "");
}

function matchCard(name: string, allCards: Card[]): Card[] {
  // Tier 1: Exact case-insensitive match
  const exact = allCards.filter(
    (c) => c.name.toLowerCase() === name.toLowerCase()
  );
  if (exact.length > 0) return exact;

  // Tier 2: Normalized match (strip punctuation, spaces, etc.)
  const norm = normalize(name);
  const normalized = allCards.filter((c) => normalize(c.name) === norm);
  if (normalized.length > 0) return normalized;

  // Tier 3: Substring match (handles truncated or extended names)
  if (norm.length >= 5) {
    const substring = allCards.filter((c) => {
      const cardNorm = normalize(c.name);
      return cardNorm.includes(norm) || norm.includes(cardNorm);
    });
    if (substring.length > 0) return substring;
  }

  return [];
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
): Promise<RecognizeResult> {
  const cardCounts = new Map<string, number>();
  const errors: string[] = [];
  let successCount = 0;

  // Process frames in batches of 3 for speed
  const batchSize = 3;
  for (let i = 0; i < frames.length; i += batchSize) {
    const batch = frames.slice(i, i + batchSize);
    const results = await Promise.all(
      batch.map((frame) =>
        recognizeFrame(frame, apiKey).catch((err: Error) => {
          errors.push(err.message);
          return [] as RecognizedCard[];
        })
      )
    );

    for (const recognized of results) {
      if (recognized.length > 0) successCount++;
      for (const card of recognized) {
        if (card.confidence === "low") continue;

        const matches = matchCard(card.name, allCards);
        for (const match of matches) {
          const id = getCardId(match);
          cardCounts.set(id, (cardCounts.get(id) || 0) + 1);
        }
      }
    }

    onProgress?.(Math.min(i + batchSize, frames.length), frames.length);
  }

  // If ALL frames errored, throw so the UI shows the error
  if (successCount === 0 && errors.length > 0) {
    throw new Error(`Card recognition failed: ${errors[0]}`);
  }

  const warnings: string[] = [];
  if (errors.length > 0) {
    warnings.push(
      `${errors.length} of ${frames.length} frames failed to process`
    );
  }

  // Convert counts - cap at reasonable amounts (seeing a card in multiple frames
  // doesn't mean you own multiple copies, default to 1)
  const entries = Array.from(cardCounts.entries()).map(([cardId]) => ({
    cardId,
    count: 1,
  }));

  return { entries, warnings };
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
