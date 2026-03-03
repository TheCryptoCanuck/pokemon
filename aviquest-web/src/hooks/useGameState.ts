"use client";

import { useState, useEffect, useCallback } from "react";
import { Bird, GameState } from "@/types";
import { xpForNextLevel, getBirdXp } from "@/lib/progression";

const STORAGE_KEY = "aviquest_state";

const defaultState: GameState = {
  level: 1,
  xp: 0,
  streak: 1,
  unlockedAchievements: [],
  aviary: [],
};

function loadState(): GameState {
  if (typeof window === "undefined") return defaultState;
  try {
    const saved = localStorage.getItem(STORAGE_KEY);
    if (saved) return JSON.parse(saved);
  } catch {
    // ignore parse errors
  }
  return defaultState;
}

function saveState(state: GameState) {
  if (typeof window === "undefined") return;
  try {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state));
  } catch {
    // ignore storage errors
  }
}

export function useGameState() {
  const [state, setState] = useState<GameState>(defaultState);
  const [mounted, setMounted] = useState(false);
  const [notification, setNotification] = useState<{
    type: "levelUp" | "achievement";
    message: string;
    detail?: string;
  } | null>(null);

  useEffect(() => {
    setState(loadState());
    setMounted(true);
  }, []);

  useEffect(() => {
    if (mounted) {
      saveState(state);
    }
  }, [state, mounted]);

  const showNotification = useCallback(
    (type: "levelUp" | "achievement", message: string, detail?: string) => {
      setNotification({ type, message, detail });
      setTimeout(() => setNotification(null), 4000);
    },
    []
  );

  const addBird = useCallback(
    (bird: Bird) => {
      setState((prev) => {
        const newAviary = [...prev.aviary, bird.name];
        let newXp = prev.xp + getBirdXp(bird.baseXp, bird.rarity);
        let newLevel = prev.level;

        while (newXp >= xpForNextLevel(newLevel)) {
          newXp -= xpForNextLevel(newLevel);
          newLevel++;
        }

        const newAchievements = [...prev.unlockedAchievements];
        const collected = newAviary.length;

        function tryUnlock(key: string) {
          if (!newAchievements.includes(key)) {
            newAchievements.push(key);
          }
        }

        if (collected >= 1) tryUnlock("first_bird");
        if (collected >= 5) tryUnlock("five_species");
        if (collected >= 10) tryUnlock("ten_species");
        if (collected >= 20) tryUnlock("twenty_species");
        if (bird.rarity === "rare" || bird.rarity === "legendary")
          tryUnlock("rare_find");
        if (bird.rarity === "legendary") tryUnlock("legendary_find");
        if (newLevel >= 5) tryUnlock("level_5");
        if (newLevel >= 10) tryUnlock("level_10");
        if (newLevel >= 20) tryUnlock("level_20");

        if (newLevel > prev.level) {
          showNotification("levelUp", `Level ${newLevel}!`);
        }

        const newAchievementIds = newAchievements.filter(
          (a) => !prev.unlockedAchievements.includes(a)
        );
        if (newAchievementIds.length > 0) {
          setTimeout(() => {
            showNotification(
              "achievement",
              "Achievement Unlocked!",
              newAchievementIds[0]
            );
          }, 500);
        }

        return {
          ...prev,
          level: newLevel,
          xp: newXp,
          aviary: newAviary,
          unlockedAchievements: newAchievements,
        };
      });
    },
    [showNotification]
  );

  const resetState = useCallback(() => {
    setState(defaultState);
  }, []);

  return {
    ...state,
    mounted,
    notification,
    addBird,
    resetState,
    dismissNotification: () => setNotification(null),
  };
}
