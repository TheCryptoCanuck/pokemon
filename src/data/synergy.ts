// Hand-curated TCGP synergy data. Date-stamped because the meta turns over
// every few weeks; revisit ~quarterly and bump SYNERGY_LAST_REVIEWED.

export const SYNERGY_LAST_REVIEWED = "2026-04-29";

// Pokémon that need 3+ energy to attack effectively. Used by the
// Energy-Acceleration heuristic to flag decks lacking ramp. Approximate —
// the upstream card data has no attack-cost field, so this is curated.
export const HEAVY_ATTACKERS: ReadonlySet<string> = new Set([
  "Charizard ex",
  "Blastoise ex",
  "Venusaur ex",
  "Mega Charizard ex",
  "Mega Mewtwo ex",
  "Mega Gardevoir ex",
  "Mega Altaria ex",
  "Mega Absol ex",
  "Gyarados ex",
  "Articuno ex",
  "Lapras ex",
  "Rayquaza ex",
  "Aerodactyl ex",
  "Pidgeot ex",
  "Hydreigon",
  "Gardevoir",
]);

// Top-tier two-card synergies. Bonus is added once per pairing matched,
// regardless of how many copies are present.
export interface PowerPairing {
  a: string;
  b: string;
  bonus: number;
  note: string;
}

export const POWER_PAIRINGS: ReadonlyArray<PowerPairing> = [
  {
    a: "Mewtwo ex",
    b: "Gardevoir",
    bonus: 30,
    note: "Gardevoir accelerates psychic energy onto Mewtwo ex",
  },
  {
    a: "Mega Mewtwo ex",
    b: "Gardevoir",
    bonus: 30,
    note: "Gardevoir powers Mega Mewtwo ex's heavy attack",
  },
  {
    a: "Gengar ex",
    b: "Gardevoir",
    bonus: 25,
    note: "Spread damage with Gengar, accelerated by Gardevoir",
  },
  {
    a: "Charizard ex",
    b: "Moltres ex",
    bonus: 25,
    note: "Moltres ex ramps fire energy for Charizard ex's late game",
  },
  {
    a: "Gyarados ex",
    b: "Misty",
    bonus: 20,
    note: "Misty turbos water energy onto Gyarados ex",
  },
  {
    a: "Greninja ex",
    b: "Misty",
    bonus: 20,
    note: "Greninja ex snipes bench while Misty fuels the attacker",
  },
  {
    a: "Celebi ex",
    b: "Erika",
    bonus: 20,
    note: "Erika piles grass energy for Celebi ex's scaling damage",
  },
  {
    a: "Pikachu ex",
    b: "Zapdos ex",
    bonus: 15,
    note: "Zapdos ex applies early pressure while Pikachu ex sets up",
  },
];

// Auto-build seeds: best Basic Pokémon to anchor a deck per energy type,
// in priority order. The auto-builder picks the first one present in the
// candidate pool.
export const BEST_BASICS_BY_TYPE: Record<string, string[]> = {
  grass: ["Celebi ex", "Exeggcute", "Bulbasaur"],
  fire: ["Charmander", "Moltres ex", "Growlithe"],
  water: ["Squirtle", "Magikarp", "Staryu", "Froakie"],
  lightning: ["Pikachu ex", "Pikachu", "Voltorb"],
  psychic: ["Mewtwo ex", "Ralts", "Gastly"],
  fighting: ["Hitmonlee", "Hitmonchan", "Machop", "Buzzwole"],
  darkness: ["Murkrow", "Houndour"],
  metal: ["Skarmory", "Magnemite"],
};

// Canonical energy-acceleration trainer per type. Auto-builder pulls 2x
// of this if the chosen energy types have a match.
export const ACCEL_BY_TYPE: Record<string, string> = {
  water: "Misty",
  grass: "Erika",
  lightning: "Lt. Surge",
  fighting: "Brock",
};

// Universal Trainer staples in priority order. Auto-builder adds them
// after the seed Pokémon and its evolution chain.
export const STAPLE_TRAINERS: ReadonlyArray<{ name: string; copies: number }> = [
  { name: "Professor’s Research", copies: 2 },
  { name: "Poké Ball", copies: 2 },
  { name: "X Speed", copies: 1 },
  { name: "Sabrina", copies: 1 },
  { name: "Giovanni", copies: 1 },
  { name: "Pokédex", copies: 1 },
];
