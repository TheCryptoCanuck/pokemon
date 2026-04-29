import { Card, CollectionEntry, DeckCard, getCardId, isTrainerCard } from "../types/card";
import { canAddCard } from "./deck-rules";
import { scoreDeck, type DeckScore } from "./deck-scoring";
import {
  ACCEL_BY_TYPE,
  BEST_BASICS_BY_TYPE,
  POWER_PAIRINGS,
  STAPLE_TRAINERS,
} from "../data/synergy";

export interface AutoBuildOptions {
  energyTypes: string[]; // 1–3 from ENERGY_TYPES (excluding 'colorless')
  pool: "all" | "owned";
  collection?: CollectionEntry[]; // required when pool === 'owned'
}

export interface AutoBuildResult {
  cards: DeckCard[];
  score: DeckScore;
  warnings: string[];
}

const DECK_SIZE = 20;
const COPY_LIMIT = 2;

function totalCards(deck: DeckCard[]): number {
  return deck.reduce((s, dc) => s + dc.count, 0);
}

// Filter the global pool to (a) cards legal to put in a deck of these
// energy types and (b) cards the user owns if pool === 'owned'.
function buildPool(
  allCards: Card[],
  opts: AutoBuildOptions
): { pool: Card[]; ownedSet: Set<string> | null } {
  const energySet = new Set(opts.energyTypes);
  const ownedSet =
    opts.pool === "owned"
      ? new Set((opts.collection ?? []).filter((e) => e.count > 0).map((e) => e.cardId))
      : null;

  const pool = allCards
    .filter((card) => {
      if (isTrainerCard(card)) return true;
      // Pokémon: keep if its element matches one of our chosen energies, or
      // it's colourless (universal).
      if (!card.element || card.element === "colorless") return true;
      return energySet.has(card.element);
    })
    .filter((card) => (ownedSet ? ownedSet.has(getCardId(card)) : true));

  // Stable sort by set, number for deterministic tie-breaking.
  pool.sort((a, b) => (a.set === b.set ? a.number - b.number : a.set.localeCompare(b.set)));
  return { pool, ownedSet };
}

// Try to add `count` copies of a card to the deck. Returns the number
// actually added (respects 2-copy + deck-size + 3-energy + canAddCard).
function tryAdd(deck: DeckCard[], card: Card, count: number, allCards: Card[]): number {
  const id = getCardId(card);
  let added = 0;
  for (let i = 0; i < count; i++) {
    if (totalCards(deck) >= DECK_SIZE) break;
    const existing = deck.find((dc) => dc.cardId === id);
    if ((existing?.count ?? 0) >= COPY_LIMIT) break;
    if (canAddCard(deck, id, card, allCards)) break;
    if (existing) existing.count += 1;
    else deck.push({ cardId: id, count: 1 });
    added += 1;
  }
  return added;
}

// Look up a card by exact name in the candidate pool (returns first match).
function findInPool(pool: Card[], name: string): Card | undefined {
  return pool.find((c) => c.name === name);
}

// Walk an evolution chain rooted at the given Pokémon, returning the
// Basic / Stage-1 / Stage-2 cards if present in the pool. Works for any
// stage of the input card.
function evolutionChain(
  card: Card,
  allCards: Card[],
  pool: Card[]
): { basic?: Card; stage1?: Card; stage2?: Card } {
  let stage2: Card | undefined;
  let stage1: Card | undefined;
  let basic: Card | undefined;

  if (card.stage === 2) {
    stage2 = card;
    stage1 = allCards.find(
      (c) => c.name === card.evolvesFrom && c.stage === 1
    );
    basic = stage1
      ? allCards.find((c) => c.name === stage1!.evolvesFrom && (c.stage === "basic" || c.stage === 0))
      : undefined;
  } else if (card.stage === 1) {
    stage1 = card;
    basic = allCards.find(
      (c) => c.name === card.evolvesFrom && (c.stage === "basic" || c.stage === 0)
    );
    // Search forward for a Stage-2 that evolves from this Stage-1.
    stage2 = allCards.find((c) => c.stage === 2 && c.evolvesFrom === card.name);
  } else {
    basic = card;
    stage1 = allCards.find((c) => c.stage === 1 && c.evolvesFrom === card.name);
    stage2 = stage1
      ? allCards.find((c) => c.stage === 2 && c.evolvesFrom === stage1!.name)
      : undefined;
  }

  // Constrain to pool membership.
  return {
    basic: basic && pool.includes(basic) ? basic : undefined,
    stage1: stage1 && pool.includes(stage1) ? stage1 : undefined,
    stage2: stage2 && pool.includes(stage2) ? stage2 : undefined,
  };
}

// Pick the seed Basic for the chosen energy types: scan
// BEST_BASICS_BY_TYPE in declaration order across the chosen types,
// returning the first present in the pool. Falls back to the
// highest-HP Basic of the primary type.
function pickSeed(opts: AutoBuildOptions, pool: Card[]): Card | undefined {
  for (const type of opts.energyTypes) {
    const candidates = BEST_BASICS_BY_TYPE[type] ?? [];
    for (const name of candidates) {
      const c = findInPool(pool, name);
      if (c) return c;
    }
  }
  // Fallback: highest-HP Basic of the primary type.
  const primary = opts.energyTypes[0];
  const basics = pool.filter(
    (c) =>
      c.type === "pokemon" &&
      (c.stage === "basic" || c.stage === 0) &&
      c.element === primary
  );
  basics.sort((a, b) => (b.health ?? 0) - (a.health ?? 0));
  return basics[0];
}

export function autoBuild(allCards: Card[], opts: AutoBuildOptions): AutoBuildResult {
  const warnings: string[] = [];
  if (opts.energyTypes.length === 0) {
    return {
      cards: [],
      score: scoreDeck([], allCards),
      warnings: ["Pick at least one energy type before auto-building."],
    };
  }
  if (opts.energyTypes.length > 3) {
    return {
      cards: [],
      score: scoreDeck([], allCards),
      warnings: ["TCGP decks allow at most 3 energy types."],
    };
  }

  const { pool } = buildPool(allCards, opts);
  if (pool.length === 0) {
    return {
      cards: [],
      score: scoreDeck([], allCards),
      warnings: [
        opts.pool === "owned"
          ? "Your collection has no cards matching those energies. Try unchecking 'Use only cards I own'."
          : "No cards match those energies.",
      ],
    };
  }

  const deck: DeckCard[] = [];

  // 1. Seed Basic (2 copies).
  const seed = pickSeed(opts, pool);
  if (!seed) {
    warnings.push(`No anchor Basic available for ${opts.energyTypes.join(", ")}.`);
  } else {
    tryAdd(deck, seed, 2, allCards);
    // 2. Seed's evolution chain (2 copies of each stage in pool).
    const chain = evolutionChain(seed, allCards, pool);
    if (chain.stage1) tryAdd(deck, chain.stage1, 2, allCards);
    if (chain.stage2) tryAdd(deck, chain.stage2, 2, allCards);
  }

  // 3. Power-pair partner and its chain.
  const seedName = seed?.name;
  if (seedName) {
    const pairing = POWER_PAIRINGS.find(
      (p) => p.a === seedName || p.b === seedName
    );
    const partnerName = pairing
      ? pairing.a === seedName
        ? pairing.b
        : pairing.a
      : undefined;
    const partner = partnerName ? findInPool(pool, partnerName) : undefined;
    if (partner) {
      tryAdd(deck, partner, 2, allCards);
      const chain = evolutionChain(partner, allCards, pool);
      if (chain.basic && chain.basic !== partner) tryAdd(deck, chain.basic, 2, allCards);
      if (chain.stage1 && chain.stage1 !== partner) tryAdd(deck, chain.stage1, 2, allCards);
      if (chain.stage2 && chain.stage2 !== partner) tryAdd(deck, chain.stage2, 2, allCards);
    }
  }

  // 4. Type-matched accel trainers (2x).
  for (const type of opts.energyTypes) {
    const accelName = ACCEL_BY_TYPE[type];
    if (!accelName) continue;
    const accel = findInPool(pool, accelName);
    if (accel) tryAdd(deck, accel, 2, allCards);
  }

  // 5. Universal staples in priority order.
  for (const { name, copies } of STAPLE_TRAINERS) {
    const staple = findInPool(pool, name);
    if (staple) tryAdd(deck, staple, copies, allCards);
  }

  // 6. Greedy fill to 20: at each open slot, pick the candidate that
  // most increases the deck score. Tie-break by Pokémon-then-Trainer,
  // then by sorted pool order (already deterministic).
  let safety = 30; // upper bound on iterations
  while (totalCards(deck) < DECK_SIZE && safety-- > 0) {
    let bestCard: Card | null = null;
    let bestDelta = -Infinity;
    let bestKind = 2; // 0 = pokemon, 1 = trainer; lower wins on tie

    const baseScore = scoreDeck(deck, allCards).total;

    for (const card of pool) {
      const id = getCardId(card);
      if (canAddCard(deck, id, card, allCards)) continue;

      // Tentative add → evaluate → undo.
      const existing = deck.find((dc) => dc.cardId === id);
      if (existing) existing.count += 1;
      else deck.push({ cardId: id, count: 1 });
      const delta = scoreDeck(deck, allCards).total - baseScore;
      if (existing) existing.count -= 1;
      else deck.pop();

      const kind = card.type === "pokemon" ? 0 : 1; // ties: Pokémon win
      if (delta > bestDelta || (delta === bestDelta && kind < bestKind)) {
        bestDelta = delta;
        bestCard = card;
        bestKind = kind;
      }
    }

    if (!bestCard) break;
    // Stop early if no remaining card improves the score and we already
    // have at least 18 — better than padding with noise.
    if (bestDelta <= 0 && totalCards(deck) >= 18) break;
    tryAdd(deck, bestCard, 1, allCards);
  }

  if (totalCards(deck) < DECK_SIZE) {
    warnings.push(
      `Stopped at ${totalCards(deck)}/20 cards — pool too thin to legally fill the deck.`
    );
  }

  return { cards: deck, score: scoreDeck(deck, allCards), warnings };
}
