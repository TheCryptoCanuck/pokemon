// Hand-classified roles for known TCGP Trainer cards. Cards not listed here
// are treated as 'other' by the scorer. Update when new sets ship.

export type TrainerRole =
  | "search"
  | "draw"
  | "accel"
  | "switch"
  | "heal"
  | "disrupt"
  | "boost"
  | "other";

// Energy types that an "accel" trainer accelerates. Used by the
// Energy-Acceleration heuristic and the auto-builder. `null` means generic
// (no specific energy type, e.g. ramp via discard).
export const TRAINER_ROLES: Record<string, TrainerRole> = {
  // Universal draw / search
  "Professor's Research": "draw",
  "Pokédex": "draw",
  "Poké Ball": "search",
  "Pokémon Communication": "search",

  // Disruption
  "Sabrina": "disrupt",
  "Red Card": "disrupt",
  "Hand Scope": "disrupt",
  "Mars": "disrupt",
  "Iono": "disrupt",
  "Cyrus": "disrupt",

  // Switch (own active)
  "X Speed": "switch",
  "Pokémon Catcher": "switch",

  // Heal
  "Potion": "heal",
  "Pokémon Center Lady": "heal",

  // Damage boosters (situational, count as 'boost' not 'draw')
  "Giovanni": "boost",
  "Blaine": "boost",
  "Cynthia": "boost",
  "Leaf": "boost",
  "Koga": "boost",

  // Type-specific energy acceleration
  "Misty": "accel",
  "Erika": "accel",
  "Lt. Surge": "accel",
  "Brock": "accel",
  "Volkner": "accel",
};

// Maps an 'accel' trainer to the energy type it accelerates. Used by the
// auto-builder to pick the right ramp for the chosen energies.
export const ACCEL_TYPE: Record<string, string> = {
  "Misty": "water",
  "Erika": "grass",
  "Lt. Surge": "lightning",
  "Brock": "fighting",
  "Volkner": "lightning",
};

export function getTrainerRole(name: string): TrainerRole {
  return TRAINER_ROLES[name] ?? "other";
}
