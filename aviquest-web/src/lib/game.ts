import { Bird, Achievement, Rarity } from './types';

export const RARITY_COLORS: Record<Rarity, string> = {
  common: 'rgb(180, 180, 180)',
  uncommon: '#4CAF50',
  rare: '#2196F3',
  legendary: '#FFC107',
  unknown: '#CE93D8',
};

export const RARITY_BG: Record<Rarity, string> = {
  common: 'rgba(180, 180, 180, 0.15)',
  uncommon: 'rgba(76, 175, 80, 0.15)',
  rare: 'rgba(33, 150, 243, 0.15)',
  legendary: 'rgba(255, 193, 7, 0.15)',
  unknown: 'rgba(206, 147, 216, 0.15)',
};

export const RARITY_BORDER: Record<Rarity, string> = {
  common: 'border-gray-400/40',
  uncommon: 'border-green-500/40',
  rare: 'border-blue-500/40',
  legendary: 'border-amber-400/40',
  unknown: 'border-purple-300/40',
};

export const RARITY_TEXT: Record<Rarity, string> = {
  common: 'text-gray-300',
  uncommon: 'text-green-400',
  rare: 'text-blue-400',
  legendary: 'text-amber-400',
  unknown: 'text-purple-300',
};

export function levelTitle(level: number): string {
  if (level < 3) return 'Fledgling';
  if (level < 6) return 'Nestling';
  if (level < 10) return 'Sparrow';
  if (level < 15) return 'Warbler';
  if (level < 20) return 'Songweaver';
  if (level < 30) return 'Falconer';
  if (level < 40) return 'Eagle Scout';
  return 'Master Birder';
}

export function xpForNextLevel(level: number): number {
  return Math.round(1000 * Math.pow(level, 1.4));
}

export function getBirdXp(bird: Bird): number {
  switch (bird.rarity) {
    case 'uncommon': return Math.round(bird.baseXp * 1.5);
    case 'rare': return bird.baseXp * 2;
    case 'legendary': return bird.baseXp * 5;
    default: return bird.baseXp;
  }
}

export const ACHIEVEMENTS: Achievement[] = [
  { key: 'first_bird', emoji: '🐦', title: 'First Feather', description: 'Identify your first bird' },
  { key: 'five_species', emoji: '🌿', title: 'Nature Curious', description: 'Collect 5 different species' },
  { key: 'ten_species', emoji: '🏆', title: 'Avid Birder', description: 'Collect 10 different species' },
  { key: 'twenty_species', emoji: '🦅', title: 'Wing Watcher', description: 'Collect 20 different species' },
  { key: 'rare_find', emoji: '💎', title: 'Rare Encounter', description: 'Identify a rare bird' },
  { key: 'legendary_find', emoji: '✨', title: 'Legend Spotter', description: 'Identify a legendary bird' },
  { key: 'level_5', emoji: '⭐', title: 'Rising Birder', description: 'Reach level 5' },
  { key: 'level_10', emoji: '🌟', title: 'Expert Nester', description: 'Reach level 10' },
  { key: 'level_20', emoji: '🌠', title: 'Sky Master', description: 'Reach level 20' },
];

export function weightedRandomBird(birds: Bird[]): Bird {
  const r = Math.random();
  let rarity: Rarity;
  if (r < 0.60) rarity = 'common';
  else if (r < 0.85) rarity = 'uncommon';
  else if (r < 0.97) rarity = 'rare';
  else rarity = 'legendary';

  const pool = birds.filter(b => b.rarity === rarity);
  return pool[Math.floor(Math.random() * pool.length)];
}

export function checkAchievements(
  collectedCount: number,
  birdRarity: Rarity,
  level: number,
  currentAchievements: string[]
): string[] {
  const newAchievements: string[] = [];

  const tryUnlock = (key: string) => {
    if (!currentAchievements.includes(key) && !newAchievements.includes(key)) {
      newAchievements.push(key);
    }
  };

  if (collectedCount >= 1) tryUnlock('first_bird');
  if (collectedCount >= 5) tryUnlock('five_species');
  if (collectedCount >= 10) tryUnlock('ten_species');
  if (collectedCount >= 20) tryUnlock('twenty_species');
  if (birdRarity === 'rare' || birdRarity === 'legendary') tryUnlock('rare_find');
  if (birdRarity === 'legendary') tryUnlock('legendary_find');
  if (level >= 5) tryUnlock('level_5');
  if (level >= 10) tryUnlock('level_10');
  if (level >= 20) tryUnlock('level_20');

  return newAchievements;
}

export function unknownBird(name: string): Bird {
  return {
    name,
    scientificName: 'Species not yet in database',
    imageUrl: '',
    audioUrl: '',
    lore: "You found something we've never seen before! This species isn't in our database yet. Your discovery has been logged and will help us grow AviQuest.",
    habitat: 'Unknown',
    conservationStatus: 'Unknown',
    rarity: 'unknown',
    baseXp: 100,
  };
}
