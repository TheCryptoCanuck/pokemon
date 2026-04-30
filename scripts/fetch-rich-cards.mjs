#!/usr/bin/env node
// Pull rich card data (attacks + abilities) from
// hugoburguete/pokemon-tcg-pocket-card-database, normalize the cardId
// format to match our `${set}-${number}` convention, and write a single
// public/cards-rich.json the app fetches alongside cards.extra.json.
//
// Re-run when new TCGP sets ship:
//   node scripts/fetch-rich-cards.mjs
//
// Pinned to hugoburguete's main branch — bump only when you've verified
// the upstream schema hasn't drifted.

import { writeFileSync } from "node:fs";

const BASE =
  "https://raw.githubusercontent.com/hugoburguete/pokemon-tcg-pocket-card-database/main/cards/en";

const SETS = [
  "a1-genetic-apex",
  "a1a-mythical-island",
  "a2-space-time-smackdown",
  "a2a-triumphant-light",
  "a2b-shining-revelry",
  "a3-celestial-guardians",
  "a3a-extradimensional-crisis",
  "a3b-eevee-grove",
  "a4-wisdom-of-sea-and-sky",
  "a4a-secluded-springs",
  "a4b-deluxe-pack-ex",
  "b1-mega-rising",
  "b1a-crimson-blaze",
  "b2-fantastical-parade",
  "b2a-paldean-wonders",
  "b2b-mega-shine",
  "b3-pulsing-aura",
  "promo-a",
  "promo-b",
];

// hugoburguete uses ids like "a1-007" or "promo-a-001". Map to our
// canonical "A1-7" / "PROMO-A-1" format used by getCardId().
function canonicalId(rawId) {
  const parts = rawId.split("-");
  const num = parts.pop();
  const setSlug = parts.join("-").toUpperCase();
  return `${setSlug}-${parseInt(num, 10)}`;
}

const rich = {};
let totalCards = 0;
let withAttacks = 0;
let withAbilities = 0;

for (const slug of SETS) {
  const url = `${BASE}/${slug}.json`;
  process.stdout.write(`fetch ${slug.padEnd(36)} `);
  const res = await fetch(url);
  if (!res.ok) {
    console.log(`FAILED (${res.status})`);
    continue;
  }
  const cards = await res.json();
  let setHits = 0;
  for (const c of cards) {
    if (!c.id) continue;
    totalCards++;
    const hasAttacks = Array.isArray(c.attacks) && c.attacks.length > 0;
    const hasAbilities = Array.isArray(c.abilities) && c.abilities.length > 0;
    if (!hasAttacks && !hasAbilities) continue;
    const id = canonicalId(c.id);
    rich[id] = {
      ...(hasAttacks
        ? {
            attacks: c.attacks.map((a) => ({
              name: a.name,
              cost: Array.isArray(a.cost) ? a.cost : [],
              damage: a.damage ?? "",
              effect: a.effect ?? a.text ?? undefined,
            })),
          }
        : {}),
      ...(hasAbilities
        ? {
            abilities: c.abilities.map((a) => ({
              name: a.name,
              effect: a.effect ?? a.text ?? "",
            })),
          }
        : {}),
    };
    if (hasAttacks) withAttacks++;
    if (hasAbilities) withAbilities++;
    setHits++;
  }
  console.log(`${setHits}/${cards.length}`);
}

const output = {
  source: "hugoburguete/pokemon-tcg-pocket-card-database",
  generatedAt: new Date().toISOString(),
  cards: rich,
};

const outPath = "public/cards-rich.json";
writeFileSync(outPath, JSON.stringify(output));
const sizeKB = (JSON.stringify(output).length / 1024).toFixed(1);
console.log();
console.log(`Wrote ${outPath} (${sizeKB} KB)`);
console.log(`  total cards scanned : ${totalCards}`);
console.log(`  with attacks        : ${withAttacks}`);
console.log(`  with abilities      : ${withAbilities}`);
console.log(`  unique cardIds      : ${Object.keys(rich).length}`);
