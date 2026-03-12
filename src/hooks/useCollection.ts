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

  const mergeCollection = useCallback((entries: CollectionEntry[]) => {
    setCollection((prev) => {
      const merged = [...prev];
      for (const entry of entries) {
        const existing = merged.find((e) => e.cardId === entry.cardId);
        if (existing) {
          existing.count = Math.max(existing.count, entry.count);
        } else {
          merged.push({ ...entry });
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
