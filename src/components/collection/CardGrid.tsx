import { Card, getCardId } from "../../types/card";
import CardDisplay from "../shared/CardDisplay";

interface Props {
  cards: Card[];
  getCount: (cardId: string) => number;
  onAdd: (cardId: string) => void;
  onRemove: (cardId: string) => void;
  onCardClick?: (card: Card) => void;
}

export default function CardGrid({
  cards,
  getCount,
  onAdd,
  onRemove,
  onCardClick,
}: Props) {
  if (cards.length === 0) {
    return (
      <div className="text-center text-gray-500 py-12">
        No cards match your filters.
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
