import { MetaDeckMatch } from "../../utils/collection-match";

interface Props {
  match: MetaDeckMatch;
}

export default function DeckComparison({ match }: Props) {
  return (
    <div className="space-y-2">
      <h4 className="text-xs text-gray-400 uppercase tracking-wider">
        Card Breakdown
      </h4>
      {match.ownedCards.map((card) => (
        <div key={card.cardName} className="flex items-center gap-2 text-sm">
          <span
            className={`w-2 h-2 rounded-full ${
              card.ownedCount >= card.count ? "bg-green-500" : "bg-red-500"
            }`}
          />
          <span
            className={
              card.ownedCount >= card.count ? "text-gray-300" : "text-red-400"
            }
          >
            {card.cardName}
          </span>
          <span className="text-gray-500 ml-auto">
            {card.ownedCount}/{card.count}
          </span>
        </div>
      ))}
    </div>
  );
}
