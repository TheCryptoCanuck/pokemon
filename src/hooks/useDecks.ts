import { useState, useEffect, useCallback } from "react";
import { Deck, DeckCard } from "../types/card";
import { storageGet, storageSet } from "../utils/storage";

const STORAGE_KEY = "tcgp-decks";

export function useDecks() {
  const [decks, setDecks] = useState<Deck[]>([]);
  const [loaded, setLoaded] = useState(false);
  const [activeDeckId, setActiveDeckId] = useState<string | null>(null);

  useEffect(() => {
    storageGet(STORAGE_KEY)
      .then((raw) => { if (raw) setDecks(JSON.parse(raw)); })
      .catch(() => {})
      .finally(() => setLoaded(true));
  }, []);

  useEffect(() => {
    if (!loaded) return;
    storageSet(STORAGE_KEY, JSON.stringify(decks));
  }, [decks, loaded]);

  const activeDeck = decks.find((d) => d.id === activeDeckId) || null;

  const createDeck = useCallback((name: string): string => {
    const id = crypto.randomUUID();
    const deck: Deck = { id, name, cards: [], createdAt: new Date().toISOString() };
    setDecks((prev) => [...prev, deck]);
    setActiveDeckId(id);
    return id;
  }, []);

  const deleteDeck = useCallback(
    (id: string) => {
      setDecks((prev) => prev.filter((d) => d.id !== id));
      if (activeDeckId === id) setActiveDeckId(null);
    },
    [activeDeckId]
  );

  const renameDeck = useCallback((id: string, name: string) => {
    setDecks((prev) =>
      prev.map((d) => (d.id === id ? { ...d, name } : d))
    );
  }, []);

  const duplicateDeck = useCallback((id: string): string | null => {
    const deck = decks.find((d) => d.id === id);
    if (!deck) return null;
    const newId = crypto.randomUUID();
    const newDeck: Deck = {
      ...deck,
      id: newId,
      name: `${deck.name} (copy)`,
      cards: deck.cards.map((c) => ({ ...c })),
      createdAt: new Date().toISOString(),
    };
    setDecks((prev) => [...prev, newDeck]);
    return newId;
  }, [decks]);

  const addCardToDeck = useCallback(
    (deckId: string, cardId: string) => {
      setDecks((prev) =>
        prev.map((d) => {
          if (d.id !== deckId) return d;
          const existing = d.cards.find((c) => c.cardId === cardId);
          if (existing) {
            return {
              ...d,
              cards: d.cards.map((c) =>
                c.cardId === cardId ? { ...c, count: c.count + 1 } : c
              ),
            };
          }
          return { ...d, cards: [...d.cards, { cardId, count: 1 }] };
        })
      );
    },
    []
  );

  const removeCardFromDeck = useCallback(
    (deckId: string, cardId: string) => {
      setDecks((prev) =>
        prev.map((d) => {
          if (d.id !== deckId) return d;
          const existing = d.cards.find((c) => c.cardId === cardId);
          if (!existing) return d;
          if (existing.count <= 1) {
            return { ...d, cards: d.cards.filter((c) => c.cardId !== cardId) };
          }
          return {
            ...d,
            cards: d.cards.map((c) =>
              c.cardId === cardId ? { ...c, count: c.count - 1 } : c
            ),
          };
        })
      );
    },
    []
  );

  const setDeckCards = useCallback(
    (deckId: string, cards: DeckCard[]) => {
      setDecks((prev) =>
        prev.map((d) => (d.id === deckId ? { ...d, cards } : d))
      );
    },
    []
  );

  const togglePinDeck = useCallback((id: string) => {
    setDecks((prev) =>
      prev.map((d) =>
        d.id === id
          ? { ...d, pinnedAt: d.pinnedAt ? undefined : new Date().toISOString() }
          : d
      )
    );
  }, []);

  // Pinned decks first (oldest pin first so the order is stable when you
  // pin a new one), then unpinned (newest first).
  const sortedDecks = [...decks].sort((a, b) => {
    if (a.pinnedAt && !b.pinnedAt) return -1;
    if (!a.pinnedAt && b.pinnedAt) return 1;
    if (a.pinnedAt && b.pinnedAt) return a.pinnedAt.localeCompare(b.pinnedAt);
    return b.createdAt.localeCompare(a.createdAt);
  });

  return {
    decks: sortedDecks,
    activeDeck,
    activeDeckId,
    setActiveDeckId,
    createDeck,
    deleteDeck,
    renameDeck,
    duplicateDeck,
    addCardToDeck,
    removeCardFromDeck,
    setDeckCards,
    togglePinDeck,
  };
}
