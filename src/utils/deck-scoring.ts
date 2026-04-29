import { Card, DeckCard, getCardId } from "../types/card";
import {
  HEAVY_ATTACKERS,
  POWER_PAIRINGS,
  SYNERGY_LAST_REVIEWED,
} from "../data/synergy";
import { ACCEL_TYPE, getTrainerRole } from "../data/trainer-roles";

export type HeuristicId =
  | "basicConsistency"
  | "trainerDensity"
  | "evolutionLines"
  | "energyAccel"
  | "powerPairings"
  | "weaknessConcentration"
  | "exDensity"
  | "benchMobility";

export type ScoreStatus = "good" | "warn" | "bad";

export interface HeuristicResult {
  id: HeuristicId;
  label: string;
  score: number; // 0-100
  weight: number; // 0-1, sums to 1 across all heuristics
  status: ScoreStatus;
  message: string;
  suggestion?: string;
}

export interface DeckScore {
  total: number; // 0-100
  grade: "S" | "A" | "B" | "C" | "D";
  breakdown: HeuristicResult[];
  lastReviewed: string;
}

// Resolved deck: each DeckCard joined with its Card record. Computed once
// and threaded through every heuristic so we don't re-scan allCards 8 times.
interface Resolved {
  card: Card;
  count: number;
}

function resolve(deck: DeckCard[], cards: Card[]): Resolved[] {
  const out: Resolved[] = [];
  for (const dc of deck) {
    const card = cards.find((c) => getCardId(c) === dc.cardId);
    if (card) out.push({ card, count: dc.count });
  }
  return out;
}

function isBasic(card: Card): boolean {
  return (
    card.type === "pokemon" && (card.stage === "basic" || card.stage === 0)
  );
}

function isPokemon(card: Card): boolean {
  return card.type === "pokemon";
}

function isEx(card: Card): boolean {
  return / ex$/i.test(card.name);
}

function statusFromScore(score: number): ScoreStatus {
  if (score >= 80) return "good";
  if (score >= 55) return "warn";
  return "bad";
}

function clamp(n: number, lo = 0, hi = 100): number {
  return Math.max(lo, Math.min(hi, n));
}

// ─── Heuristic helpers (also exported for tooltips) ──────────────────────

// P(at least one Basic in 5-card opening) given B Basics in 20-card deck.
// 1 − C(20−B, 5) / C(20, 5)
export function getMulliganProbability(basicCount: number): number {
  if (basicCount <= 0) return 0;
  if (basicCount >= 16) return 1; // can't draw 5 non-basics
  const choose = (n: number, k: number) => {
    if (k < 0 || k > n) return 0;
    let r = 1;
    for (let i = 0; i < k; i++) r = (r * (n - i)) / (i + 1);
    return r;
  };
  const denom = choose(20, 5);
  const numer = choose(20 - basicCount, 5);
  return 1 - numer / denom;
}

export function getStageCurve(
  deck: DeckCard[],
  cards: Card[]
): { basic: number; stage1: number; stage2: number } {
  const resolved = resolve(deck, cards);
  let basic = 0,
    stage1 = 0,
    stage2 = 0;
  for (const { card, count } of resolved) {
    if (!isPokemon(card)) continue;
    if (card.stage === "basic" || card.stage === 0) basic += count;
    else if (card.stage === 1) stage1 += count;
    else if (card.stage === 2) stage2 += count;
  }
  return { basic, stage1, stage2 };
}

export function getEvolutionLines(
  deck: DeckCard[],
  cards: Card[]
): Array<{
  basic?: string;
  stage1?: string;
  stage2?: string;
  complete: boolean;
}> {
  const resolved = resolve(deck, cards);
  const names = new Set(resolved.filter((r) => isPokemon(r.card)).map((r) => r.card.name));

  // Find all non-basic Pokémon and walk their evolution chains.
  const lines: Array<{
    basic?: string;
    stage1?: string;
    stage2?: string;
    complete: boolean;
  }> = [];
  const seen = new Set<string>();

  for (const { card } of resolved) {
    if (!isPokemon(card)) continue;
    if (seen.has(card.name)) continue;

    // Walk upward via evolvesFrom; we may have a Stage 2 whose Stage 1's
    // evolvesFrom points to the Basic.
    if (card.stage === 2) {
      const stage2 = card.name;
      const stage1Name = card.evolvesFrom; // name string or undefined
      const stage1Card = cards.find(
        (c) => c.name === stage1Name && c.stage === 1
      );
      const basicName = stage1Card?.evolvesFrom;
      seen.add(stage2);
      if (stage1Name) seen.add(stage1Name);
      if (basicName) seen.add(basicName);
      lines.push({
        basic: basicName,
        stage1: stage1Name,
        stage2,
        complete: !!(basicName && names.has(basicName) && stage1Name && names.has(stage1Name)),
      });
    } else if (card.stage === 1) {
      const stage1 = card.name;
      if (seen.has(stage1)) continue;
      // Skip if we already covered this as part of a Stage-2 line above.
      const isUnderStage2 = lines.some((l) => l.stage1 === stage1);
      if (isUnderStage2) continue;
      const basicName = card.evolvesFrom;
      seen.add(stage1);
      if (basicName) seen.add(basicName);
      lines.push({
        basic: basicName,
        stage1,
        complete: !!(basicName && names.has(basicName)),
      });
    }
  }
  return lines;
}

// ─── Heuristics ──────────────────────────────────────────────────────────

function basicConsistency(resolved: Resolved[]): HeuristicResult {
  let basics = 0;
  for (const { card, count } of resolved) if (isBasic(card)) basics += count;
  const p = getMulliganProbability(basics);
  const score = clamp(Math.round(p * 100));
  const status = statusFromScore(score);
  let suggestion: string | undefined;
  if (basics < 6 && basics > 0) suggestion = `Add ${6 - basics} more Basic Pokémon for a 90%+ opening hand.`;
  else if (basics === 0) suggestion = `Every TCGP deck must have at least one Basic Pokémon.`;
  return {
    id: "basicConsistency",
    label: "Basic Consistency",
    score,
    weight: 0.15,
    status,
    message: `${basics} Basic${basics === 1 ? "" : "s"} → ${Math.round(p * 100)}% no-mulligan`,
    suggestion,
  };
}

function trainerDensity(resolved: Resolved[]): HeuristicResult {
  // Bucketed mix: ≥2 search, ≥2 draw, ≥1 disrupt, ≥1 accel matched to
  // the deck's energy types. Score = 25 per filled bucket.
  let search = 0,
    draw = 0,
    disrupt = 0,
    accel = 0;
  for (const { card, count } of resolved) {
    if (card.type !== "trainer") continue;
    const role = getTrainerRole(card.name);
    if (role === "search") search += count;
    else if (role === "draw") draw += count;
    else if (role === "disrupt") disrupt += count;
    else if (role === "accel") accel += count;
  }

  const buckets = [
    { ok: search >= 2, label: "search trainers (Poké Ball / Communication)" },
    { ok: draw >= 2, label: "draw trainers (Professor's Research / Pokédex)" },
    { ok: disrupt >= 1, label: "disruption (Sabrina / Red Card)" },
    { ok: accel >= 1, label: "energy acceleration (Misty / Erika / Lt. Surge)" },
  ];
  const filled = buckets.filter((b) => b.ok).length;
  const score = filled * 25;
  const status = statusFromScore(score);
  const missing = buckets.find((b) => !b.ok);
  return {
    id: "trainerDensity",
    label: "Trainer Mix",
    score,
    weight: 0.20,
    status,
    message: `${filled}/4 roles covered (search ${search}, draw ${draw}, disrupt ${disrupt}, accel ${accel})`,
    suggestion: missing ? `Missing ${missing.label}.` : undefined,
  };
}

function evolutionLines(deck: DeckCard[], cards: Card[]): HeuristicResult {
  const lines = getEvolutionLines(deck, cards);
  if (lines.length === 0) {
    return {
      id: "evolutionLines",
      label: "Evolution Lines",
      score: 100,
      weight: 0.18,
      status: "good",
      message: "All-Basic deck (no evolution lines to validate)",
    };
  }
  const incomplete = lines.filter((l) => !l.complete).length;
  const score = clamp(100 - incomplete * 30);
  const status = statusFromScore(score);
  const broken = lines.find((l) => !l.complete);
  let suggestion: string | undefined;
  if (broken) {
    if (broken.stage2 && broken.stage1 && !broken.basic)
      suggestion = `Add the Basic that evolves into ${broken.stage1} for the ${broken.stage2} line.`;
    else if (broken.stage2 && !broken.stage1)
      suggestion = `Add ${broken.stage2}'s Stage-1 to complete the evolution line.`;
    else if (broken.stage1 && !broken.basic)
      suggestion = `Add the Basic that evolves into ${broken.stage1}.`;
  }
  return {
    id: "evolutionLines",
    label: "Evolution Lines",
    score,
    weight: 0.18,
    status,
    message: `${lines.length} line${lines.length === 1 ? "" : "s"}, ${incomplete} incomplete`,
    suggestion,
  };
}

function energyAccel(resolved: Resolved[]): HeuristicResult {
  let heavy = 0;
  for (const { card, count } of resolved) {
    if (!isPokemon(card)) continue;
    if (HEAVY_ATTACKERS.has(card.name) || (card.retreatCost ?? 0) >= 2)
      heavy += count;
  }
  let accelTrainers = 0;
  const accelTypes: string[] = [];
  for (const { card, count } of resolved) {
    if (card.type !== "trainer") continue;
    if (getTrainerRole(card.name) === "accel") {
      accelTrainers += count;
      const t = ACCEL_TYPE[card.name];
      if (t) accelTypes.push(t);
    }
  }

  if (heavy === 0) {
    return {
      id: "energyAccel",
      label: "Energy Acceleration",
      score: 100,
      weight: 0.15,
      status: "good",
      message: "No heavy attackers — no acceleration needed",
    };
  }
  const ratio = Math.min(accelTrainers / heavy, 1);
  const score = clamp(Math.round(ratio * 100));
  const status = statusFromScore(score);
  return {
    id: "energyAccel",
    label: "Energy Acceleration",
    score,
    weight: 0.15,
    status,
    message: `${heavy} heavy attacker${heavy === 1 ? "" : "s"}, ${accelTrainers} accel trainer${accelTrainers === 1 ? "" : "s"}${accelTypes.length ? ` (${[...new Set(accelTypes)].join(", ")})` : ""}`,
    suggestion: accelTrainers === 0
      ? `Heavy attackers stall without ramp — add Misty (water), Erika (grass), or Lt. Surge (lightning).`
      : undefined,
  };
}

function powerPairings(resolved: Resolved[]): HeuristicResult {
  const names = new Set(resolved.map((r) => r.card.name));
  const matched = POWER_PAIRINGS.filter(
    (p) => names.has(p.a) && names.has(p.b)
  );
  const score = clamp(matched.reduce((s, p) => s + p.bonus, 0));
  const status = matched.length > 0 ? statusFromScore(Math.max(score, 60)) : "warn";
  return {
    id: "powerPairings",
    label: "Power Pairings",
    score,
    weight: 0.12,
    status,
    message: matched.length === 0
      ? "No top-tier pairings detected"
      : matched.map((m) => `${m.a} + ${m.b}`).join(", "),
    suggestion: matched.length === 0
      ? "Try Mewtwo ex + Gardevoir, Gyarados ex + Misty, or Charizard ex + Moltres ex."
      : undefined,
  };
}

function weaknessConcentration(resolved: Resolved[]): HeuristicResult {
  const counts = new Map<string, number>();
  let total = 0;
  for (const { card, count } of resolved) {
    if (!isPokemon(card) || !card.weakness) continue;
    counts.set(card.weakness, (counts.get(card.weakness) ?? 0) + count);
    total += count;
  }
  if (total === 0) {
    return {
      id: "weaknessConcentration",
      label: "Weakness Coverage",
      score: 100,
      weight: 0.10,
      status: "good",
      message: "No weakness exposure (no attackers yet)",
    };
  }
  const max = Math.max(...counts.values());
  const share = max / total;
  // share ≤0.4 → 100, ≥0.8 → 30, linear in between.
  let score: number;
  if (share <= 0.4) score = 100;
  else if (share >= 0.8) score = 30;
  else score = Math.round(100 - ((share - 0.4) / 0.4) * 70);
  const status = statusFromScore(score);
  const dominant = [...counts.entries()].find(([, n]) => n === max)?.[0];
  return {
    id: "weaknessConcentration",
    label: "Weakness Coverage",
    score,
    weight: 0.10,
    status,
    message: `${Math.round(share * 100)}% of attackers weak to ${dominant}`,
    suggestion: share > 0.6
      ? `Diversify with an attacker not weak to ${dominant}.`
      : undefined,
  };
}

function exDensity(resolved: Resolved[]): HeuristicResult {
  let exes = 0;
  for (const { card, count } of resolved) if (isEx(card)) exes += count;
  let score: number;
  if (exes >= 2 && exes <= 4) score = 100;
  else if (exes === 0) score = 50;
  else if (exes === 1) score = 80;
  else if (exes === 5) score = 80;
  else score = 60; // 6+
  const status = statusFromScore(score);
  return {
    id: "exDensity",
    label: "Prize Math (ex Density)",
    score,
    weight: 0.05,
    status,
    message: `${exes} ex Pokémon`,
    suggestion: exes === 0
      ? `Add 1–2 ex attackers for finishing power.`
      : exes >= 6
      ? `Each ex KO gives the opponent 2 prizes — consider trimming one.`
      : undefined,
  };
}

function benchMobility(resolved: Resolved[]): HeuristicResult {
  let totalCost = 0;
  let pokes = 0;
  for (const { card, count } of resolved) {
    if (!isPokemon(card)) continue;
    totalCost += (card.retreatCost ?? 0) * count;
    pokes += count;
  }
  if (pokes === 0) {
    return {
      id: "benchMobility",
      label: "Bench Mobility",
      score: 50,
      weight: 0.05,
      status: "warn",
      message: "No Pokémon to evaluate",
    };
  }
  const avg = totalCost / pokes;
  let score: number;
  if (avg <= 1.3) score = 100;
  else if (avg >= 2.5) score = 40;
  else score = Math.round(100 - ((avg - 1.3) / 1.2) * 60);
  const status = statusFromScore(score);
  const hasSwitch = resolved.some(
    (r) => r.card.type === "trainer" && getTrainerRole(r.card.name) === "switch"
  );
  return {
    id: "benchMobility",
    label: "Bench Mobility",
    score,
    weight: 0.05,
    status,
    message: `Avg retreat cost ${avg.toFixed(1)}`,
    suggestion: avg > 2 && !hasSwitch
      ? `Add 1× X Speed — heavy retreat costs strand attackers.`
      : undefined,
  };
}

// ─── Orchestrator ────────────────────────────────────────────────────────

export function scoreDeck(deck: DeckCard[], cards: Card[]): DeckScore {
  if (deck.length === 0) {
    return {
      total: 0,
      grade: "D",
      breakdown: [],
      lastReviewed: SYNERGY_LAST_REVIEWED,
    };
  }
  const resolved = resolve(deck, cards);
  const breakdown: HeuristicResult[] = [
    basicConsistency(resolved),
    trainerDensity(resolved),
    evolutionLines(deck, cards),
    energyAccel(resolved),
    powerPairings(resolved),
    weaknessConcentration(resolved),
    exDensity(resolved),
    benchMobility(resolved),
  ];
  const total = Math.round(
    breakdown.reduce((s, h) => s + h.weight * h.score, 0)
  );
  const grade: DeckScore["grade"] =
    total >= 85 ? "S" : total >= 75 ? "A" : total >= 60 ? "B" : total >= 45 ? "C" : "D";

  return { total, grade, breakdown, lastReviewed: SYNERGY_LAST_REVIEWED };
}
