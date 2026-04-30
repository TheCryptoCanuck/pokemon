// Archetype framework adapted from a competitive 20-card-core guide
// (r/pkmntcg). TCGP adaptations:
//   1. Energy is auto-supplied from the Energy Zone — no in-deck energy
//      slots. The "Energy" slots in the original framework become extra
//      accel sources (Trainers + Pokémon abilities).
//   2. No Rare Candy in TCGP. Stage-2 evolutions stay turn-by-turn at
//      2-2-2 ratios.

import type { Card } from "../types/card";
import {
  hasAbilityKind,
  hasAttackPattern,
  isHeavyAttacker,
} from "../utils/card-classifier";

export type Archetype = "aggressive" | "evolution" | "control";

export interface RoleMix {
  search: number;
  draw: number;
  switch: number;
  disrupt: number;
  accel: number;
  heal: number;
}

export interface SlotTargets {
  pokemon: number;
  trainers: number;
  mix: RoleMix;
}

export const ARCHETYPE_TARGETS: Record<Archetype, SlotTargets> = {
  aggressive: {
    pokemon: 7, // 4 main + 2 support + 1 backup
    trainers: 13, // 4 search, 3 draw, 2 switch, 2 disrupt, 2 accel
    mix: { search: 4, draw: 3, switch: 2, disrupt: 2, accel: 2, heal: 0 },
  },
  evolution: {
    pokemon: 10, // 2-2-2 line + 2 backup basic + 2 support
    trainers: 10, // 4 search, 2 draw, 2 accel, 1 switch, 1 disrupt
    mix: { search: 4, draw: 2, switch: 1, disrupt: 1, accel: 2, heal: 0 },
  },
  control: {
    pokemon: 6, // 2 wall + 2 support + 1 backup + 1 utility
    trainers: 14, // 4 search, 3 disrupt, 2 heal, 2 switch, 3 draw
    mix: { search: 4, draw: 3, switch: 2, disrupt: 3, accel: 0, heal: 2 },
  },
};

export const ARCHETYPE_LABELS: Record<Archetype, string> = {
  aggressive: "Aggressive",
  evolution: "Evolution",
  control: "Control",
};

export const ARCHETYPE_DESCRIPTIONS: Record<Archetype, string> = {
  aggressive:
    "Fast Basic attackers. Hit turn 2, take the first 2 prizes, race the opponent.",
  evolution: "Set up a Stage-2 line safely, then overwhelm with a power attacker.",
  control:
    "Wall + disrupt + heal. Deny attacks and win by prize control or deck-out.",
};

// Heuristic: pick the archetype that best matches the seed Pokémon and
// what's available in the candidate pool.
//
//   evolution → seed has a full Stage-2 chain in the pool
//   control   → seed is a wall (high HP + low retreat) OR has a
//               disruption-style ability (move opponent's energy, etc.)
//   aggressive → everything else (default for fast Basics)
export function detectArchetype(seed: Card, pool: Card[]): Archetype {
  // Evolution: seed has a Stage-1 evolved form in the pool, AND a
  // Stage-2 above that. Walk the chain forward from a Basic.
  const currentName: string | undefined =
    seed.stage === "basic" || seed.stage === 0 ? seed.name : seed.evolvesFrom;
  let chainDepth = seed.stage === 2 ? 2 : seed.stage === 1 ? 1 : 0;
  if (currentName) {
    const stage1 = pool.find(
      (c) => c.stage === 1 && c.evolvesFrom === currentName
    );
    if (stage1) {
      chainDepth = Math.max(chainDepth, 1);
      const stage2 = pool.find(
        (c) => c.stage === 2 && c.evolvesFrom === stage1.name
      );
      if (stage2) chainDepth = 2;
    }
  }
  if (chainDepth >= 2) return "evolution";

  // Control: low retreat, high HP, disrupt-style abilities, or attacks
  // that don't reward fast prize trades.
  const isWall = (seed.health ?? 0) >= 130 && (seed.retreatCost ?? 99) <= 1;
  const hasDisrupt =
    hasAbilityKind(seed, "disrupt") || hasAttackPattern(seed, "discard");
  if ((isWall || hasDisrupt) && !isHeavyAttacker(seed)) return "control";

  return "aggressive";
}
