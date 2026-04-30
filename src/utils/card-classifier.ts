// Strategy-classification helpers built on the rich attacks + abilities
// fields. All functions are pure and tolerate missing data — Cards
// without rich fields just fall through as "no signal", which means the
// scorer / auto-builder behaves the same as the v1 hardcoded heuristics.

import type { Card } from "../types/card";

export type AbilityKind =
  | "energy-accel"
  | "draw"
  | "heal"
  | "search"
  | "disrupt"
  | "boost"
  | "other";

export type AttackPattern =
  | "spread" // damages multiple bench targets at once
  | "snipe" // targets a single benched opponent
  | "scaling" // damage scales with bench count, energy count, etc.
  | "discard" // forces opponent to discard
  | "self-damage" // damages the attacker
  | "none";

// ─── Attack cost & damage extraction ────────────────────────────────────

// Energy cost of an attack is the length of the cost array. Returns 0
// for free-attack abilities (rare).
export function getAttackCost(card: Card, idx = 0): number {
  return card.attacks?.[idx]?.cost?.length ?? 0;
}

// Highest energy cost across all of the card's attacks. Used to detect
// "heavy attackers" that need ramp to function.
export function getMaxAttackCost(card: Card): number {
  if (!card.attacks?.length) return 0;
  return Math.max(...card.attacks.map((a) => a.cost?.length ?? 0));
}

// Cheapest attack cost — useful for "can I attack on turn 1?".
export function getMinAttackCost(card: Card): number {
  if (!card.attacks?.length) return Infinity;
  return Math.min(...card.attacks.map((a) => a.cost?.length ?? 0));
}

// Parse the upstream damage string ("60", "60+", "20×", "30+") into a
// numeric base. Returns 0 if no numeric prefix.
export function getAttackDamage(card: Card, idx = 0): number {
  const raw = card.attacks?.[idx]?.damage ?? "";
  const m = /^(\d+)/.exec(raw);
  return m ? parseInt(m[1], 10) : 0;
}

export function getMaxAttackDamage(card: Card): number {
  if (!card.attacks?.length) return 0;
  return Math.max(...card.attacks.map((_, i) => getAttackDamage(card, i)));
}

// ─── Ability classification ─────────────────────────────────────────────

// Hand-picked patterns. Order matters — first match wins.
const ABILITY_PATTERNS: Array<{ kind: AbilityKind; re: RegExp }> = [
  // Move/attach Energy onto a Pokémon. Catches Gardevoir Psy Shadow,
  // Hydreigon Forced Tribute, Charizard ex Combustion Burst etc.
  { kind: "energy-accel", re: /(attach|move).+\b(energy|\{[a-z]\})/i },
  // Draw cards. Catches Bibarel-style "draw a card" abilities.
  { kind: "draw", re: /draw\b.{0,40}\bcards?/i },
  // Heal damage off your own Pokémon.
  { kind: "heal", re: /heal\b.{0,30}\bdamage/i },
  // Search deck for a card.
  { kind: "search", re: /\bsearch your deck\b/i },
  // Force opponent to discard / shuffle / lose hand.
  { kind: "disrupt", re: /(opponent.+discard|shuffle.+opponent.+hand|opponent.+reveal)/i },
  // Damage / power boosts (e.g. +20 damage to attacks).
  { kind: "boost", re: /(damage|attack).{0,30}(\+\d+|increase)/i },
];

export function classifyAbility(text: string): AbilityKind {
  for (const p of ABILITY_PATTERNS) if (p.re.test(text)) return p.kind;
  return "other";
}

// True if the card's ability text matches any of the given kinds.
export function hasAbilityKind(card: Card, ...kinds: AbilityKind[]): boolean {
  if (!card.abilities?.length) return false;
  const wanted = new Set(kinds);
  return card.abilities.some((a) => wanted.has(classifyAbility(a.effect)));
}

// ─── Attack-pattern classification ──────────────────────────────────────

const ATTACK_PATTERNS: Array<{ pattern: AttackPattern; re: RegExp }> = [
  // "to each of your opponent's Benched Pokémon" / "to all benched"
  { pattern: "spread", re: /(each of your opponent.+bench|to all .+benched)/i },
  // "1 of your opponent's Benched Pokémon" — single-target snipe
  { pattern: "snipe", re: /\b1 of your opponent[’']s benched\b/i },
  // "X damage for each ..." — scaling damage
  { pattern: "scaling", re: /(damage for each|×\s*\d+|x\s*the number)/i },
  // "your opponent discards" / "opponent reveals their hand"
  { pattern: "discard", re: /(opponent.+discard|opponent.+reveal)/i },
  // "this Pokémon also does N damage to itself"
  { pattern: "self-damage", re: /damage to itself|damage to this Pok/i },
];

export function classifyAttack(text: string | undefined): AttackPattern {
  if (!text) return "none";
  for (const p of ATTACK_PATTERNS) if (p.re.test(text)) return p.pattern;
  return "none";
}

export function hasAttackPattern(
  card: Card,
  ...patterns: AttackPattern[]
): boolean {
  if (!card.attacks?.length) return false;
  const wanted = new Set(patterns);
  return card.attacks.some((a) => wanted.has(classifyAttack(a.effect)));
}

// ─── High-level classifications used by scorer + auto-build ─────────────

// "Heavy attacker": needs 3+ energy on a single attack. Falls back to
// the v1 retreatCost-based heuristic when attacks aren't loaded yet.
export function isHeavyAttacker(card: Card): boolean {
  if (card.attacks?.length) return getMaxAttackCost(card) >= 3;
  return (card.retreatCost ?? 0) >= 2;
}

// "Has energy acceleration" via an ability — Gardevoir, Hydreigon, etc.
// These count as accel sources alongside Trainer cards in the Trainer
// Mix heuristic.
export function hasEnergyAccel(card: Card): boolean {
  return hasAbilityKind(card, "energy-accel");
}

// "Has soft draw" via an ability — Pokémon that draw cards.
export function hasSoftDraw(card: Card): boolean {
  return hasAbilityKind(card, "draw");
}

// Does the card's primary attack scale with bench count? If so, the deck
// rewards filling the bench wide.
export function rewardsWideBench(card: Card): boolean {
  return hasAttackPattern(card, "scaling");
}
