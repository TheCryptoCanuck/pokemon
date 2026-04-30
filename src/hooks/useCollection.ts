import { useState, useEffect, useCallback } from "react";
import { CollectionEntry } from "../types/card";

const STORAGE_KEY = "tcgp-collection";

function loadCollection(): CollectionEntry[] {
  try {
    const raw = localStorage.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : [];
  } catch {
    return [];
  }
}

export function useCollection() {
  const [collection, setCollection] = useState<CollectionEntry[]>(loadCollection);

  useEffect(() => {
    localStorage.setItem(STORAGE_KEY, JSON.stringify(collection));
  }, [collection]);

  const addCard = useCallback((cardId: string) => {
    setCollection((prev) => {
      const existing = prev.find((e) => e.cardId === cardId);
      if (existing) {
        return prev.map((e) =>
          e.cardId === cardId ? { ...e, count: e.count + 1 } : e
        );
      }
      return [...prev, { cardId, count: 1 }];
    });
  }, []);

  const removeCard = useCallback((cardId: string) => {
    setCollection((prev) => {
      const existing = prev.find((e) => e.cardId === cardId);
      if (!existing) return prev;
      if (existing.count <= 1) {
        return prev.filter((e) => e.cardId !== cardId);
      }
      return prev.map((e) =>
        e.cardId === cardId ? { ...e, count: e.count - 1 } : e
      );
    });
  }, []);

  const setCardCount = useCallback((cardId: string, count: number) => {
    setCollection((prev) => {
      if (count <= 0) return prev.filter((e) => e.cardId !== cardId);
      const existing = prev.find((e) => e.cardId === cardId);
      if (existing) {
        return prev.map((e) => (e.cardId === cardId ? { ...e, count } : e));
      }
      return [...prev, { cardId, count }];
    });
  }, []);

  const getCount = useCallback(
    (cardId: string): number => {
      return collection.find((e) => e.cardId === cardId)?.count || 0;
    },
    [collection]
  );

  // Merge import results into the collection. Imports are cumulative —
  // each call adds entry.count to the existing count — but capped at
  // OWNED_CAP_PER_IMPORT (2) since TCGP decks allow at most 2 copies of
  // any card. Manual addCard calls above the cap are preserved (a user
  // who clicked +3 keeps 3; future imports won't reduce it).
  const OWNED_CAP_PER_IMPORT = 2;
  const mergeCollection = useCallback((entries: CollectionEntry[]) => {
    setCollection((prev) => {
      const merged = [...prev];
      for (const entry of entries) {
        const existing = merged.find((e) => e.cardId === entry.cardId);
        if (existing) {
          existing.count = Math.max(
            existing.count,
            Math.min(OWNED_CAP_PER_IMPORT, existing.count + entry.count)
          );
        } else {
          merged.push({
            ...entry,
            count: Math.min(OWNED_CAP_PER_IMPORT, entry.count),
          });
        }
      }
      return merged;
    });
  }, []);

  const clearCollection = useCallback(() => {
    setCollection([]);
  }, []);

  return {
    collection,
    addCard,
    removeCard,
    setCardCount,
    getCount,
    mergeCollection,
    clearCollection,
  };
}
