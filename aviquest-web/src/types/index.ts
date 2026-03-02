export interface Bird {
  name: string;
  scientificName: string;
  imageUrl: string;
  audioUrl: string;
  lore: string;
  habitat: string;
  conservationStatus: string;
  rarity: Rarity;
  baseXp: number;
}

export type Rarity = "common" | "uncommon" | "rare" | "legendary" | "unknown";

export interface Achievement {
  id: string;
  emoji: string;
  title: string;
  description: string;
}

export interface GameState {
  level: number;
  xp: number;
  streak: number;
  unlockedAchievements: string[];
  aviary: string[]; // bird names
}

export type TabId = "map" | "identify" | "aviary" | "guide" | "profile";
