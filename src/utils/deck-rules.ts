import { Card, DeckCard, getCardId } from "../types/card";

export interface ValidationError {
  type: "card_limit" | "deck_size" | "basic_pokemon" | "energy_types";
  message: string;
}

export function validateDeck(
  deckCards: DeckCard[],
  allCards: Card[]
): ValidationError[] {
  const errors: ValidationError[] = [];
  const totalCards = deckCards.reduce((sum, dc) => sum + dc.count, 0);

  if (totalCards > 20) {
    errors.push({
      type: "deck_size",
      message: `Deck has ${totalCards}/20 cards (${totalCards - 20} over limit)`,
    });
  }

  for (const dc of deckCards) {
    if (dc.count > 2) {
      const card = allCards.find((c) => getCardId(c) === dc.cardId);
      errors.push({
        type: "card_limit",
        message: `${card?.name || dc.cardId} has ${dc.count} copies (max 2)`,
      });
    }
  }

  const resolvedCards = deckCards
    .map((dc) => ({
      ...dc,
      card: allCards.find((c) => getCardId(c) === dc.cardId),
    }))
    .filter((dc) => dc.card);

  const hasBasic = resolvedCards.some(
    (dc) =>
      dc.card!.type === "pokemon" &&
      (dc.card!.stage === "basic" || dc.card!.stage === 0)
  );
  if (!hasBasic && totalCards > 0) {
    errors.push({
      type: "basic_pokemon",
      message: "Deck must have at least 1 Basic Pokémon",
    });
  }

  const energyTypes = new Set(
    resolvedCards
      .filter((dc) => dc.card!.element && dc.card!.element !== "colorless")
      .map((dc) => dc.card!.element)
  );
  if (energyTypes.size > 3) {
    errors.push({
      type: "energy_types",
      message: `Deck has ${energyTypes.size} energy types (max 3): ${[...energyTypes].join(", ")}`,
    });
  }

  return errors;
}

export function canAddCard(
  deckCards: DeckCard[],
  cardId: string,
  card: Card,
  allCards: Card[]
): string | null {
  const totalCards = deckCards.reduce((sum, dc) => sum + dc.count, 0);
  if (totalCards >= 20) return "Deck is full (20/20 cards)";

  const existing = deckCards.find((dc) => dc.cardId === cardId);
  if (existing) {
    const sameNameCards = deckCards.filter((dc) => {
      const c = allCards.find((ac) => getCardId(ac) === dc.cardId);
      return c && c.name === card.name;
    });
    const totalSameName = sameNameCards.reduce((sum, dc) => sum + dc.count, 0);
    if (totalSameName >= 2)
      return `Already have 2 copies of ${card.name}`;
  }

  if (card.element && card.element !== "colorless") {
    const currentTypes = new Set(
      deckCards
        .map((dc) => allCards.find((c) => getCardId(c) === dc.cardId))
        .filter((c) => c?.element && c.element !== "colorless")
        .map((c) => c!.element)
    );
    if (!currentTypes.has(card.element) && currentTypes.size >= 3) {
      return "Deck already has 3 energy types";
    }
  }

  return null;
}

export function getDeckStats(deckCards: DeckCard[], allCards: Card[]) {
  const resolved = deckCards
    .map((dc) => ({
      ...dc,
      card: allCards.find((c) => getCardId(c) === dc.cardId),
    }))
    .filter((dc) => dc.card);

  const totalCards = resolved.reduce((sum, dc) => sum + dc.count, 0);

  const pokemonCount = resolved
    .filter((dc) => dc.card!.type === "pokemon")
    .reduce((sum, dc) => sum + dc.count, 0);

  const trainerCount = resolved
    .filter((dc) => dc.card!.type === "trainer")
    .reduce((sum, dc) => sum + dc.count, 0);

  const energyTypes = [
    ...new Set(
      resolved
        .filter((dc) => dc.card!.element && dc.card!.element !== "colorless")
        .map((dc) => dc.card!.element!)
    ),
  ];

  const typeBreakdown: Record<string, number> = {};
  for (const dc of resolved) {
    const el = dc.card!.element || "colorless";
    typeBreakdown[el] = (typeBreakdown[el] || 0) + dc.count;
  }

  return { totalCards, pokemonCount, trainerCount, energyTypes, typeBreakdown };
}
