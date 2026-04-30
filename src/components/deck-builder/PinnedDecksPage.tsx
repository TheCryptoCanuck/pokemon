import { useMemo } from "react";
import { Card, Deck, getCardId, getCardImageUrl } from "../../types/card";
import { scoreDeck, type DeckScore } from "../../utils/deck-scoring";

interface Props {
  decks: Deck[];
  allCards: Card[];
  onOpenDeck: (id: string) => void;
  onUnpin: (id: string) => void;
  onGoToBuilder: () => void;
}

const GRADE_COLORS: Record<DeckScore["grade"], string> = {
  S: "bg-emerald-500 text-white",
  A: "bg-emerald-600 text-white",
  B: "bg-amber-500 text-white",
  C: "bg-amber-600 text-white",
  D: "bg-rose-600 text-white",
};

export default function PinnedDecksPage({
  decks,
  allCards,
  onOpenDeck,
  onUnpin,
  onGoToBuilder,
}: Props) {
  // Memoise the score+thumb computation so re-renders don't re-score
  // every pinned deck unnecessarily.
  const pinned = useMemo(() => {
    return decks
      .filter((d) => d.pinnedAt)
      .sort((a, b) => (a.pinnedAt! < b.pinnedAt! ? -1 : 1))
      .map((deck) => {
        const total = deck.cards.reduce((s, c) => s + c.count, 0);
        const score = scoreDeck(deck.cards, allCards);
        const thumbs = deck.cards
          .map((dc) => allCards.find((c) => getCardId(c) === dc.cardId))
          .filter((c): c is Card => !!c)
          .slice(0, 3);
        return { deck, total, score, thumbs };
      });
  }, [decks, allCards]);

  if (pinned.length === 0) {
    return (
      <div className="text-center py-16 animate-slide-up-fade">
        <div className="text-5xl mb-3 text-yellow-400" aria-hidden>★</div>
        <p className="text-lg text-gray-300">No pinned decks yet</p>
        <p className="text-sm text-gray-500 mt-2 max-w-sm mx-auto">
          Tap ★ on any deck in Deck Builder to save it here. Pinned decks
          float to the top and survive bulk operations.
        </p>
        <button
          onClick={onGoToBuilder}
          className="mt-6 bg-blue-600 hover:bg-blue-700 text-white px-5 h-10 rounded font-semibold text-sm active:scale-95 transition-transform"
        >
          Go to Deck Builder
        </button>
      </div>
    );
  }

  return (
    <div className="space-y-3">
      <div>
        <h2 className="text-lg font-semibold text-white">Pinned Decks</h2>
        <p className="text-xs text-gray-400">
          {pinned.length} saved
        </p>
      </div>
      {pinned.map(({ deck, total, score, thumbs }) => (
        <div
          key={deck.id}
          className="bg-slate-800 border border-slate-700 rounded-lg p-3 animate-slide-up-fade"
        >
          <div className="flex items-start justify-between gap-2">
            <div className="flex items-center gap-1 min-w-0 flex-1">
              <span className="text-yellow-400 shrink-0">★</span>
              <h3 className="text-white font-semibold truncate">{deck.name}</h3>
            </div>
            <span
              className={`${GRADE_COLORS[score.grade]} text-xs font-bold px-2 py-0.5 rounded shrink-0`}
            >
              {score.grade}
            </span>
          </div>
          <p className="text-xs text-gray-400 mt-1">
            {total}/20 cards · score {score.total}/100
          </p>
          <div className="flex gap-1 mt-2">
            {thumbs.map((c) => (
              <img
                key={getCardId(c)}
                src={getCardImageUrl(c)}
                alt=""
                loading="lazy"
                className="w-10 h-14 rounded object-cover"
              />
            ))}
            {total > 3 && (
              <span className="text-xs text-gray-500 self-end ml-1">
                +{total - 3}
              </span>
            )}
          </div>
          <div className="flex gap-2 mt-3">
            <button
              onClick={() => onOpenDeck(deck.id)}
              className="flex-1 h-10 bg-blue-600 hover:bg-blue-700 text-white text-sm font-semibold rounded"
            >
              Open in Builder
            </button>
            <button
              onClick={() => onUnpin(deck.id)}
              aria-label={`Unpin ${deck.name}`}
              className="h-10 px-4 bg-slate-700 hover:bg-slate-600 text-gray-200 text-sm rounded"
            >
              Unpin
            </button>
          </div>
        </div>
      ))}
    </div>
  );
}
