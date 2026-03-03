export type Rarity = 'common' | 'uncommon' | 'rare' | 'legendary' | 'unknown';

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

export interface Achievement {
  key: string;
  emoji: string;
  title: string;
  description: string;
}

export interface GameState {
  level: number;
  xp: number;
  streak: number;
  collectedBirds: string[];
  unlockedAchievements: string[];
}

export type TabId = 'map' | 'identify' | 'aviary' | 'field-guide' | 'profile';
