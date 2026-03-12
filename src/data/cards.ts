import { Card } from "../types/card";

const CARDS_URL =
  "https://raw.githubusercontent.com/flibustier/pokemon-tcg-pocket-database/main/dist/cards.extra.json";

let cachedCards: Card[] | null = null;

export async function fetchCards(): Promise<Card[]> {
  if (cachedCards) return cachedCards;

  const res = await fetch(CARDS_URL);
  if (!res.ok) throw new Error(`Failed to fetch cards: ${res.status}`);
  const data: Card[] = await res.json();
  cachedCards = data;
  return data;
}

export function getCardById(cards: Card[], cardId: string): Card | undefined {
  const [set, numStr] = cardId.split("-");
  const number = parseInt(numStr, 10);
  return cards.find((c) => c.set === set && c.number === number);
}

export function getCardsByName(cards: Card[], name: string): Card[] {
  return cards.filter((c) => c.name.toLowerCase() === name.toLowerCase());
}

export function getSets(cards: Card[]): string[] {
  return [...new Set(cards.map((c) => c.set))];
}

export function getElements(cards: Card[]): string[] {
  return [...new Set(cards.filter((c) => c.element).map((c) => c.element!))];
}
