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

// Upstream data splits non-Pokémon cards into 'supporter', 'item', 'tool',
// and 'Fossil' instead of using 'trainer' as a single bucket. Treat all
// non-Pokémon cards as Trainers for UI/scoring purposes (Fossils are
// played from hand like Trainers and live in the same deck slots).
export function isTrainerCard(card: Card): boolean {
  return !!card.type && card.type !== "pokemon";
}

export function getCardImageUrl(card: Card): string {
  // Card images live in the sibling pokemon-tcg-exchange repo at
  // public/images/cards-by-set/{set}/{number}.webp. Routed through
  // jsDelivr (CDN, CORS, no GitHub rate limit) for mobile speed.
  return `https://cdn.jsdelivr.net/gh/flibustier/pokemon-tcg-exchange@main/public/images/cards-by-set/${card.set}/${card.number}.webp`;
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
  S: 8,
  SSR: 9,
  UR: 10,
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
  S: "Shiny",
  SSR: "Shiny Super Rare",
  UR: "Crown Rare",
};
