import { Card, getCardId } from "../../types/card";
import CardDisplay from "../shared/CardDisplay";

interface Props {
  cards: Card[];
  getCount: (cardId: string) => number;
  onAdd: (cardId: string) => void;
  onRemove: (cardId: string) => void;
  onCardClick?: (card: Card) => void;
  onClearFilters?: () => void;
}

export default function CardGrid({
  cards,
  getCount,
  onAdd,
  onRemove,
  onCardClick,
  onClearFilters,
}: Props) {
  if (cards.length === 0) {
    return (
      <div role="status" aria-live="polite" className="text-center py-16 animate-slide-up-fade">
        <div className="text-5xl mb-3" aria-hidden>🔍</div>
        <p className="text-lg text-gray-300">No cards match your filters</p>
        <p className="text-sm text-gray-500 mt-1">
          Try widening your search or pick a different element.
        </p>
        {onClearFilters && (
          <button
            onClick={onClearFilters}
            className="mt-5 bg-blue-600 hover:bg-blue-700 text-white px-5 h-10 rounded font-semibold text-sm active:scale-95 transition-transform"
          >
            Clear filters
          </button>
        )}
      </div>
    );
  }

  return (
    <div className="flex flex-wrap gap-3 justify-center">
      {cards.map((card) => {
        const id = getCardId(card);
        const count = getCount(id);
        return (
          <CardDisplay
            key={id}
            card={card}
            count={count}
            owned={count > 0}
            onClick={() => onCardClick?.(card)}
            onAdd={() => onAdd(id)}
            onRemove={count > 0 ? () => onRemove(id) : undefined}
          />
        );
      })}
    </div>
  );
}
