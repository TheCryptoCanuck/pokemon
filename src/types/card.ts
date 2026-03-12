export interface Card {
  set: string;
  number: number;
  name: string;
  rarity: string;
  image: string;
  packs?: string[];
  element?: string;
  type?: string;
  stage?: string | number;
  health?: number;
  retreatCost?: number;
  weakness?: string;
  evolvesFrom?: string;
}

export interface CollectionEntry {
  cardId: string;
  count: number;
}

export interface DeckCard {
  cardId: string;
  count: number;
}

export interface Deck {
  id: string;
  name: string;
  cards: DeckCard[];
  createdAt: string;
}

export interface MetaDeck {
  name: string;
  tier: "S" | "A" | "B" | "C";
  cards: { cardName: string; count: number }[];
  energyTypes: string[];
  strategy: string;
}

export type Tab = "collection" | "deck-builder" | "meta";

export function getCardId(card: Card): string {
  return `${card.set}-${card.number}`;
}

export function getCardImageUrl(card: Card): string {
  return `https://raw.githubusercontent.com/flibustier/pokemon-tcg-pocket-database/main/dist/images/${card.image}`;
}

export const ENERGY_TYPES = [
  "grass",
  "fire",
  "water",
  "lightning",
  "psychic",
  "fighting",
  "darkness",
  "metal",
  "colorless",
] as const;

export const RARITY_ORDER: Record<string, number> = {
  C: 0,
  U: 1,
  R: 2,
  RR: 3,
  AR: 4,
  SR: 5,
  SAR: 6,
  IM: 7,
  UR: 8,
};

export const RARITY_LABELS: Record<string, string> = {
  C: "Common",
  U: "Uncommon",
  R: "Rare",
  RR: "Double Rare",
  AR: "Art Rare",
  SR: "Super Rare",
  SAR: "Special Art Rare",
  IM: "Immersive Rare",
  UR: "Crown Rare",
};
