'use client';

import { createContext, useContext, useState, useCallback, useEffect, ReactNode } from 'react';
import { GameState, Bird } from '../lib/types';
import { getBirdXp, xpForNextLevel, checkAchievements } from '../lib/game';

interface GameContextValue extends GameState {
  addBird: (bird: Bird) => { newAchievements: string[]; leveledUp: boolean };
  hasBird: (name: string) => boolean;
}

const STORAGE_KEY = 'aviquest_game_state';

const defaultState: GameState = {
  level: 1,
  xp: 0,
  streak: 1,
  collectedBirds: [],
  unlockedAchievements: [],
};

const GameContext = createContext<GameContextValue | null>(null);

function loadState(): GameState {
  if (typeof window === 'undefined') return defaultState;
  try {
    const stored = localStorage.getItem(STORAGE_KEY);
    if (stored) return JSON.parse(stored);
  } catch {
    // Corrupted storage, start fresh
  }
  return defaultState;
}

function saveState(state: GameState) {
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // Storage full or unavailable
  }
}

export function GameProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<GameState>(defaultState);
  const [hydrated, setHydrated] = useState(false);

  useEffect(() => {
    setState(loadState());
    setHydrated(true);
  }, []);

  useEffect(() => {
    if (hydrated) saveState(state);
  }, [state, hydrated]);

  const addBird = useCallback((bird: Bird) => {
    let leveledUp = false;
    let newAchievements: string[] = [];

    setState(prev => {
      let { level, xp, collectedBirds, unlockedAchievements } = prev;

      collectedBirds = [...collectedBirds, bird.name];
      xp += getBirdXp(bird);

      while (xp >= xpForNextLevel(level)) {
        xp -= xpForNextLevel(level);
        level++;
        leveledUp = true;
      }

      newAchievements = checkAchievements(
        collectedBirds.length,
        bird.rarity,
        level,
        unlockedAchievements
      );

      return {
        ...prev,
        level,
        xp,
        collectedBirds,
        unlockedAchievements: [...unlockedAchievements, ...newAchievements],
      };
    });

    return { newAchievements, leveledUp };
  }, []);

  const hasBird = useCallback((name: string) => {
    return state.collectedBirds.includes(name);
  }, [state.collectedBirds]);

  return (
    <GameContext.Provider value={{ ...state, addBird, hasBird }}>
      {children}
    </GameContext.Provider>
  );
}

export function useGame() {
  const ctx = useContext(GameContext);
  if (!ctx) throw new Error('useGame must be used within a GameProvider');
  return ctx;
}
