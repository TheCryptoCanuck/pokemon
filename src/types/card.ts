export interface Attack {
  name: string;
  cost: string[]; // capitalized energy names from upstream: ["Psychic", "Colorless"]
  damage: string; // upstream is a string ("60", "60+", "20×")
  effect?: string;
}

export interface Ability {
  name: string;
  effect: string;
}

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
  // Populated from the rich data fetch (hugoburguete) and merged in
  // fetchCards. Pokémon may have multiple attacks; abilities are rare.
  attacks?: Attack[];
  abilities?: Ability[];
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
  pinnedAt?: string; // ISO timestamp; undefined = unpinned
}

export interface MetaDeck {
  name: string;
  tier: "S" | "A" | "B" | "C";
  cards: { cardName: string; count: number }[];
  energyTypes: string[];
  strategy: string;
}

export type Tab = "collection" | "deck-builder" | "pinned" | "meta";

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

// Card categories we expose as filter options. Mirrors the upstream
// `card.type` field. "trainer" is a virtual catch-all that matches any
// non-Pokémon card (supporter / item / tool / Fossil).
export const CARD_CATEGORIES = [
  "pokemon",
  "trainer",
  "supporter",
  "item",
  "tool",
  "Fossil",
] as const;
export type CardCategory = (typeof CARD_CATEGORIES)[number];

const CATEGORY_SET = new Set<string>(CARD_CATEGORIES);

// Combined type/element filter. Accepts either an element name (e.g.
// "grass") or a category name (e.g. "trainer", "supporter"). Empty
// string means "no filter".
export function matchesTypeFilter(card: Card, value: string): boolean {
  if (!value) return true;
  if (CATEGORY_SET.has(value)) {
    if (value === "trainer") return isTrainerCard(card);
    return card.type === value;
  }
  return card.element === value;
}

export const CATEGORY_LABELS: Record<CardCategory, string> = {
  pokemon: "Pokémon",
  trainer: "Trainers (any)",
  supporter: "Supporter",
  item: "Item",
  tool: "Tool",
  Fossil: "Fossil",
};

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
  "dragon",
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
