export function xpForNextLevel(level: number): number {
  return Math.round(1000 * Math.pow(level, 1.4));
}

export function levelTitle(level: number): string {
  if (level < 3) return "Fledgling";
  if (level < 6) return "Nestling";
  if (level < 10) return "Sparrow";
  if (level < 15) return "Warbler";
  if (level < 20) return "Songweaver";
  if (level < 30) return "Falconer";
  if (level < 40) return "Eagle Scout";
  return "Master Birder";
}

export const RARITY_COLORS: Record<string, string> = {
  common: "rgba(255, 255, 255, 0.7)",
  uncommon: "#4CAF50",
  rare: "#2196F3",
  legendary: "#F59E0B",
  unknown: "#CE93D8",
};

export function getRarityColor(rarity: string): string {
  return RARITY_COLORS[rarity] ?? "rgba(255, 255, 255, 0.7)";
}

export function getBirdXp(baseXp: number, rarity: string): number {
  switch (rarity) {
    case "uncommon":
      return Math.round(baseXp * 1.5);
    case "rare":
      return baseXp * 2;
    case "legendary":
      return baseXp * 5;
    default:
      return baseXp;
  }
}

export const ACHIEVEMENTS = [
  { id: "first_bird", emoji: "🐦", title: "First Feather", description: "Identify your first bird" },
  { id: "five_species", emoji: "🌿", title: "Nature Curious", description: "Collect 5 different species" },
  { id: "ten_species", emoji: "🏆", title: "Avid Birder", description: "Collect 10 different species" },
  { id: "twenty_species", emoji: "🦅", title: "Wing Watcher", description: "Collect 20 different species" },
  { id: "rare_find", emoji: "💎", title: "Rare Encounter", description: "Identify a rare bird" },
  { id: "legendary_find", emoji: "✨", title: "Legend Spotter", description: "Identify a legendary bird" },
  { id: "level_5", emoji: "⭐", title: "Rising Birder", description: "Reach level 5" },
  { id: "level_10", emoji: "🌟", title: "Expert Nester", description: "Reach level 10" },
  { id: "level_20", emoji: "🌠", title: "Sky Master", description: "Reach level 20" },
];
