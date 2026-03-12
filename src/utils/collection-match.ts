import { Card, CollectionEntry, MetaDeck, getCardId } from "../types/card";

export interface MetaDeckMatch {
  deck: MetaDeck;
  ownedCards: { cardName: string; count: number; ownedCount: number }[];
  missingCards: { cardName: string; count: number }[];
  completeness: number;
  totalNeeded: number;
  totalOwned: number;
}

export function matchCollectionToMetaDeck(
  deck: MetaDeck,
  collection: CollectionEntry[],
  allCards: Card[]
): MetaDeckMatch {
  const ownedCards: MetaDeckMatch["ownedCards"] = [];
  const missingCards: MetaDeckMatch["missingCards"] = [];
  let totalNeeded = 0;
  let totalOwned = 0;

  for (const deckCard of deck.cards) {
    totalNeeded += deckCard.count;

    const matchingCards = allCards.filter(
      (c) => c.name.toLowerCase() === deckCard.cardName.toLowerCase()
    );

    let ownedCount = 0;
    for (const mc of matchingCards) {
      const entry = collection.find((ce) => ce.cardId === getCardId(mc));
      if (entry) ownedCount += entry.count;
    }

    const effective = Math.min(ownedCount, deckCard.count);
    totalOwned += effective;

    ownedCards.push({
      cardName: deckCard.cardName,
      count: deckCard.count,
      ownedCount: effective,
    });

    if (effective < deckCard.count) {
      missingCards.push({
        cardName: deckCard.cardName,
        count: deckCard.count - effective,
      });
    }
  }

  return {
    deck,
    ownedCards,
    missingCards,
    completeness: totalNeeded > 0 ? totalOwned / totalNeeded : 0,
    totalNeeded,
    totalOwned,
  };
}

export function rankMetaDecks(
  decks: MetaDeck[],
  collection: CollectionEntry[],
  allCards: Card[]
): MetaDeckMatch[] {
  const tierValue: Record<string, number> = { S: 4, A: 3, B: 2, C: 1 };

  return decks
    .map((d) => matchCollectionToMetaDeck(d, collection, allCards))
    .sort((a, b) => {
      if (Math.abs(a.completeness - b.completeness) > 0.01)
        return b.completeness - a.completeness;
      return (
        (tierValue[b.deck.tier] || 0) - (tierValue[a.deck.tier] || 0)
      );
    });
}
