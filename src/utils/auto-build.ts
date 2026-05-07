import { Card, CollectionEntry, DeckCard, getCardId, isTrainerCard } from "../types/card";
import { canAddCard } from "./deck-rules";
import { scoreDeck, type DeckScore } from "./deck-scoring";
import {
  getCapabilities,
  getMaxAttackDamage,
  getMinAttackCost,
} from "./card-classifier";
import {
  ACCEL_BY_TYPE,
  BEST_BASICS_BY_TYPE,
  POWER_PAIRINGS,
  STAPLE_TRAINERS,
} from "../data/synergy";
import {
  ARCHETYPE_TARGETS,
  type Archetype,
  detectArchetype,
} from "../data/archetypes";
import { getTrainerRole, type TrainerRole } from "../data/trainer-roles";

export interface AutoBuildOptions {
  energyTypes: string[]; // 1–3 from ENERGY_TYPES
  pool: "all" | "owned";
  collection?: CollectionEntry[]; // required when pool === 'owned'
  archetype?: Archetype | "auto"; // default 'auto' (detect from seed)
}

export interface AutoBuildResult {
  cards: DeckCard[];
  score: DeckScore;
  warnings: string[];
  archetype: Archetype; // resolved archetype (auto-detected or user-chosen)
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

// Pick the seed Basic for the chosen energy types. Strategy:
//   1. Scan BEST_BASICS_BY_TYPE for a hand-curated meta seed.
//   2. Fall back to the Basic with the best damage-per-energy ratio
//      across the chosen types (uses real attack data when present).
//   3. Final fallback: highest-HP Basic of the primary type.
function pickSeed(opts: AutoBuildOptions, pool: Card[]): Card | undefined {
  for (const type of opts.energyTypes) {
    const candidates = BEST_BASICS_BY_TYPE[type] ?? [];
    for (const name of candidates) {
      const c = findInPool(pool, name);
      if (c) return c;
    }
  }
  const energySet = new Set(opts.energyTypes);
  const basics = pool.filter(
    (c) =>
      c.type === "pokemon" &&
      (c.stage === "basic" || c.stage === 0) &&
      c.element &&
      energySet.has(c.element)
  );

  // damage-per-energy ratio when attacks data is available, else HP.
  basics.sort((a, b) => {
    const aDmg = getMaxAttackDamage(a);
    const bDmg = getMaxAttackDamage(b);
    if (aDmg && bDmg) {
      const aCost = Math.max(1, getMinAttackCost(a));
      const bCost = Math.max(1, getMinAttackCost(b));
      return bDmg / bCost - aDmg / aCost;
    }
    return (b.health ?? 0) - (a.health ?? 0);
  });
  return basics[0];
}

// Find Pokémon in the pool with energy-acceleration abilities matching
// the chosen energy types (Gardevoir for psychic, Hydreigon for darkness,
// etc.). Returns up to two such cards in pool order. Auto-builder pulls
// these so abilities-driven decks get built even without a power-pair
// match.
function pickAbilityPartners(
  pool: Card[],
  energyTypes: string[],
  excludeNames: Set<string>,
  limit = 2
): Card[] {
  const energySet = new Set(energyTypes);
  const out: Card[] = [];
  for (const card of pool) {
    if (out.length >= limit) break;
    if (excludeNames.has(card.name)) continue;
    if (!card.element || !energySet.has(card.element)) continue;
    const caps = getCapabilities(card);
    if (caps.hasEnergyAccel || caps.hasSoftDraw) {
      out.push(card);
      excludeNames.add(card.name);
    }
  }
  return out;
}

// Count Pokémon vs Trainers currently in the deck (excluding any not
// found in the card pool — shouldn't happen but be defensive).
function countByKind(deck: DeckCard[], pool: Card[]): { pokemon: number; trainers: number } {
  let pokemon = 0;
  let trainers = 0;
  for (const dc of deck) {
    const c = pool.find((p) => getCardId(p) === dc.cardId);
    if (!c) continue;
    if (isTrainerCard(c)) trainers += dc.count;
    else pokemon += dc.count;
  }
  return { pokemon, trainers };
}

// Add up to `target` copies (across distinct cards) of trainers in a
// given role from the pool that aren't already in the deck. Returns the
// number actually added.
function fillRole(
  deck: DeckCard[],
  pool: Card[],
  role: TrainerRole,
  target: number,
  allCards: Card[]
): number {
  if (target <= 0) return 0;
  const present = deck.reduce((sum, dc) => {
    const c = pool.find((p) => getCardId(p) === dc.cardId);
    if (c && isTrainerCard(c) && getTrainerRole(c.name) === role) return sum + dc.count;
    return sum;
  }, 0);
  let needed = target - present;
  if (needed <= 0) return 0;
  let added = 0;
  for (const card of pool) {
    if (needed <= 0) break;
    if (!isTrainerCard(card)) continue;
    if (getTrainerRole(card.name) !== role) continue;
    const want = Math.min(2, needed);
    const got = tryAdd(deck, card, want, allCards);
    added += got;
    needed -= got;
  }
  return added;
}

// Pick a backup attacker: a Basic Pokémon of one of the chosen energies,
// not already in the deck, with the best damage-per-energy ratio.
// Different from the seed by name.
function pickBackupAttacker(
  pool: Card[],
  energyTypes: string[],
  excludeNames: Set<string>
): Card | undefined {
  const energySet = new Set(energyTypes);
  const candidates = pool.filter(
    (c) =>
      c.type === "pokemon" &&
      (c.stage === "basic" || c.stage === 0) &&
      c.element &&
      energySet.has(c.element) &&
      !excludeNames.has(c.name)
  );
  candidates.sort((a, b) => {
    const aDmg = getMaxAttackDamage(a);
    const bDmg = getMaxAttackDamage(b);
    if (aDmg && bDmg) {
      const aCost = Math.max(1, getMinAttackCost(a));
      const bCost = Math.max(1, getMinAttackCost(b));
      return bDmg / bCost - aDmg / aCost;
    }
    return (b.health ?? 0) - (a.health ?? 0);
  });
  return candidates[0];
}

// Find the highest-HP, lowest-retreat Basic Pokémon in the pool to use
// as a wall in Control archetypes.
function pickWall(pool: Card[], energyTypes: string[]): Card | undefined {
  const energySet = new Set(energyTypes);
  const basics = pool.filter(
    (c) =>
      c.type === "pokemon" &&
      (c.stage === "basic" || c.stage === 0) &&
      c.element &&
      energySet.has(c.element)
  );
  basics.sort(
    (a, b) =>
      (b.health ?? 0) - (a.health ?? 0) ||
      (a.retreatCost ?? 99) - (b.retreatCost ?? 99)
  );
  return basics[0];
}

export function autoBuild(allCards: Card[], opts: AutoBuildOptions): AutoBuildResult {
  const warnings: string[] = [];
  const requestedArchetype = opts.archetype ?? "auto";

  if (opts.energyTypes.length === 0) {
    return {
      cards: [],
      score: scoreDeck([], allCards),
      warnings: ["Pick at least one energy type before auto-building."],
      archetype: "aggressive",
    };
  }
  if (opts.energyTypes.length > 3) {
    return {
      cards: [],
      score: scoreDeck([], allCards),
      warnings: ["TCGP decks allow at most 3 energy types."],
      archetype: "aggressive",
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
      archetype: "aggressive",
    };
  }

  const deck: DeckCard[] = [];

  // 1. Seed: control wants a wall, evolution/aggressive want a damage seed.
  let seed: Card | undefined;
  if (requestedArchetype === "control") {
    seed = pickWall(pool, opts.energyTypes);
  }
  if (!seed) seed = pickSeed(opts, pool);
  if (!seed) {
    warnings.push(`No anchor Basic available for ${opts.energyTypes.join(", ")}.`);
    return {
      cards: deck,
      score: scoreDeck(deck, allCards),
      warnings,
      archetype: requestedArchetype === "auto" ? "aggressive" : requestedArchetype,
    };
  }

  // 2. Resolve the archetype now that we have a seed.
  const archetype: Archetype =
    requestedArchetype === "auto" ? detectArchetype(seed, pool) : requestedArchetype;
  const targets = ARCHETYPE_TARGETS[archetype];

  // 3. Seed Pokémon line.
  tryAdd(deck, seed, 2, allCards);
  if (archetype === "evolution") {
    const chain = evolutionChain(seed, allCards, pool);
    if (chain.stage1) tryAdd(deck, chain.stage1, 2, allCards);
    if (chain.stage2) tryAdd(deck, chain.stage2, 2, allCards);
  } else if (archetype === "aggressive" || archetype === "control") {
    // Don't pull Stage-1/2 in aggressive/control — keep the line short
    // so we don't waste deck slots on cards that don't attack on T1.
  }

  // 4. Power-pair partner (still a meaningful tactical bonus).
  const pairing = POWER_PAIRINGS.find((p) => p.a === seed!.name || p.b === seed!.name);
  const partnerName = pairing
    ? pairing.a === seed.name
      ? pairing.b
      : pairing.a
    : undefined;
  const partner = partnerName ? findInPool(pool, partnerName) : undefined;
  if (partner) {
    tryAdd(deck, partner, 2, allCards);
    if (archetype === "evolution") {
      const chain = evolutionChain(partner, allCards, pool);
      if (chain.basic && chain.basic !== partner) tryAdd(deck, chain.basic, 2, allCards);
      if (chain.stage1 && chain.stage1 !== partner) tryAdd(deck, chain.stage1, 2, allCards);
      if (chain.stage2 && chain.stage2 !== partner) tryAdd(deck, chain.stage2, 2, allCards);
    }
  }

  // 5. Ability-driven partners (energy-accel / draw on Pokémon). In
  // evolution archetype the seed already consumed 6+ Pokémon slots for
  // its chain; cap ability partners at 1 and don't pull their evolution
  // chain or we blow the Pokémon budget (14P/6T → 10P/10T target).
  const exclude = new Set(
    deck.map((dc) => {
      const c = allCards.find((a) => getCardId(a) === dc.cardId);
      return c?.name ?? "";
    })
  );
  const partnerLimit =
    archetype === "evolution" ? 1 : archetype === "control" ? 1 : 2;
  for (const p of pickAbilityPartners(pool, opts.energyTypes, exclude, partnerLimit)) {
    tryAdd(deck, p, 2, allCards);
    // Only pull the partner's chain in aggressive archetype, where we
    // have headroom; evolution needs trainer slots, control wants room
    // for walls/heal.
    if (archetype === "aggressive") {
      const chain = evolutionChain(p, allCards, pool);
      if (chain.basic && chain.basic !== p) tryAdd(deck, chain.basic, 2, allCards);
    }
  }

  // 6. Backup attacker — different name from seed/partner, same energy.
  // Aggressive archetype calls for 1, evolution for 1 backup Basic, control for 1.
  if (countByKind(deck, pool).pokemon < targets.pokemon) {
    const backup = pickBackupAttacker(pool, opts.energyTypes, exclude);
    if (backup) {
      tryAdd(deck, backup, archetype === "aggressive" ? 1 : 2, allCards);
      exclude.add(backup.name);
    }
  }

  // 7. Type-matched accel trainers (2× per matched type) when the
  // archetype calls for accel coverage.
  if (targets.mix.accel > 0) {
    for (const type of opts.energyTypes) {
      const accelName = ACCEL_BY_TYPE[type];
      if (!accelName) continue;
      const accel = findInPool(pool, accelName);
      if (accel) tryAdd(deck, accel, 2, allCards);
    }
  }

  // 8. Fill role buckets to archetype targets in priority order.
  // Search first (most universal), then draw, then disrupt/heal/switch.
  fillRole(deck, pool, "search", targets.mix.search, allCards);
  fillRole(deck, pool, "draw", targets.mix.draw, allCards);
  fillRole(deck, pool, "disrupt", targets.mix.disrupt, allCards);
  fillRole(deck, pool, "heal", targets.mix.heal, allCards);
  fillRole(deck, pool, "switch", targets.mix.switch, allCards);

  // 9. Universal staples — ensures Professor's Research and Poké Ball
  // land even if role-filling didn't pick them (priority issues).
  for (const { name, copies } of STAPLE_TRAINERS) {
    const staple = findInPool(pool, name);
    if (staple) tryAdd(deck, staple, copies, allCards);
  }

  // 10. Greedy fill to 20: pick the candidate that most increases the
  // score. Stop early if no improving move and total ≥ 18 — better than
  // padding with bad cards.
  let safety = 30;
  while (totalCards(deck) < DECK_SIZE && safety-- > 0) {
    let bestCard: Card | null = null;
    let bestDelta = -Infinity;
    let bestKind = 2;

    const baseScore = scoreDeck(deck, allCards).total;
    const { pokemon: pInDeck, trainers: tInDeck } = countByKind(deck, pool);

    for (const card of pool) {
      const id = getCardId(card);
      if (canAddCard(deck, id, card, allCards)) continue;

      // Skip cards that would push past archetype slot targets unless
      // we're more than 2 over budget on the other kind (a soft bias,
      // not a hard cap).
      const wouldBePokemon = card.type === "pokemon";
      if (wouldBePokemon && pInDeck >= targets.pokemon + 2) continue;
      if (!wouldBePokemon && tInDeck >= targets.trainers + 2) continue;

      const existing = deck.find((dc) => dc.cardId === id);
      if (existing) existing.count += 1;
      else deck.push({ cardId: id, count: 1 });
      const delta = scoreDeck(deck, allCards).total - baseScore;
      if (existing) existing.count -= 1;
      else deck.pop();

      const kind = wouldBePokemon ? 0 : 1;
      if (delta > bestDelta || (delta === bestDelta && kind < bestKind)) {
        bestDelta = delta;
        bestCard = card;
        bestKind = kind;
      }
    }

    if (!bestCard) break;
    if (bestDelta <= 0 && totalCards(deck) >= 18) break;
    tryAdd(deck, bestCard, 1, allCards);
  }

  if (totalCards(deck) < DECK_SIZE) {
    warnings.push(
      `Stopped at ${totalCards(deck)}/20 cards — pool too thin to legally fill the deck.`
    );
  }

  return {
    cards: deck,
    score: scoreDeck(deck, allCards),
    warnings,
    archetype,
  };
}
