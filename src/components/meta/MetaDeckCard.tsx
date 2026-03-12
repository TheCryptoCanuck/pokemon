import { useState } from "react";
import { MetaDeckMatch } from "../../utils/collection-match";
import DeckComparison from "./DeckComparison";

interface Props {
  match: MetaDeckMatch;
  onBuildDeck?: () => void;
}

const TIER_COLORS: Record<string, string> = {
  S: "bg-red-600",
  A: "bg-orange-600",
  B: "bg-blue-600",
  C: "bg-gray-600",
};

const TYPE_COLORS: Record<string, string> = {
  grass: "bg-green-600",
  fire: "bg-red-600",
  water: "bg-blue-600",
  lightning: "bg-yellow-500",
  psychic: "bg-purple-600",
  fighting: "bg-orange-700",
  darkness: "bg-gray-700",
  metal: "bg-gray-500",
};

export default function MetaDeckCard({ match, onBuildDeck }: Props) {
  const [expanded, setExpanded] = useState(false);
  const pct = Math.round(match.completeness * 100);

  return (
    <div className="bg-slate-800 rounded-lg overflow-hidden">
      <div
        className="p-4 cursor-pointer hover:bg-slate-750"
        onClick={() => setExpanded(!expanded)}
      >
        <div className="flex items-center gap-3">
          <span
            className={`${
              TIER_COLORS[match.deck.tier] || "bg-gray-600"
            } text-white text-xs font-bold px-2 py-1 rounded`}
          >
            {match.deck.tier}
          </span>

          <div className="flex-1 min-w-0">
            <h3 className="text-white font-semibold truncate">
              {match.deck.name}
            </h3>
            <div className="flex gap-1 mt-1">
              {match.deck.energyTypes.map((type) => (
                <span
                  key={type}
                  className={`${
                    TYPE_COLORS[type] || "bg-gray-500"
                  } text-white text-[10px] px-1.5 py-0.5 rounded capitalize`}
                >
                  {type}
                </span>
              ))}
            </div>
          </div>

          {/* Completeness */}
          <div className="text-right">
            <p
              className={`text-lg font-bold ${
                pct === 100
                  ? "text-green-400"
                  : pct >= 80
                    ? "text-yellow-400"
                    : "text-gray-400"
              }`}
            >
              {pct}%
            </p>
            <p className="text-xs text-gray-500">
              {match.totalOwned}/{match.totalNeeded}
            </p>
          </div>

          <span className="text-gray-500 text-sm">
            {expanded ? "^" : "v"}
          </span>
        </div>

        {/* Progress bar */}
        <div className="w-full bg-slate-700 rounded-full h-1.5 mt-3">
          <div
            className={`h-1.5 rounded-full transition-all ${
              pct === 100
                ? "bg-green-500"
                : pct >= 80
                  ? "bg-yellow-500"
                  : "bg-blue-500"
            }`}
            style={{ width: `${pct}%` }}
          />
        </div>
      </div>

      {expanded && (
        <div className="border-t border-slate-700 p-4 space-y-4">
          <p className="text-gray-400 text-sm">{match.deck.strategy}</p>

          <DeckComparison match={match} />

          {match.missingCards.length > 0 && (
            <div>
              <h4 className="text-xs text-red-400 uppercase tracking-wider mb-1">
                Missing Cards
              </h4>
              <div className="flex flex-wrap gap-1">
                {match.missingCards.map((card) => (
                  <span
                    key={card.cardName}
                    className="bg-red-900/30 text-red-400 text-xs px-2 py-1 rounded"
                  >
                    {card.cardName} x{card.count}
                  </span>
                ))}
              </div>
            </div>
          )}

          {onBuildDeck && (
            <button
              onClick={(e) => {
                e.stopPropagation();
                onBuildDeck();
              }}
              className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded text-sm font-semibold w-full"
            >
              Copy to Deck Builder
            </button>
          )}
        </div>
      )}
    </div>
  );
}
