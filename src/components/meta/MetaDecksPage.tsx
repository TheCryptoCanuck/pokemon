import { useState, useMemo } from "react";
import { Card, CollectionEntry } from "../../types/card";
import { META_DECKS } from "../../data/meta-decks";
import { rankMetaDecks } from "../../utils/collection-match";
import MetaDeckCard from "./MetaDeckCard";

interface Props {
  allCards: Card[];
  collection: CollectionEntry[];
  onBuildDeck: (name: string, cardNames: { cardName: string; count: number }[]) => void;
}

export default function MetaDecksPage({
  allCards,
  collection,
  onBuildDeck,
}: Props) {
  const [tierFilter, setTierFilter] = useState<string>("");
  const [minCompletion, setMinCompletion] = useState(0);

  const ranked = useMemo(
    () => rankMetaDecks(META_DECKS, collection, allCards),
    [collection, allCards]
  );

  const filtered = useMemo(() => {
    return ranked.filter((m) => {
      if (tierFilter && m.deck.tier !== tierFilter) return false;
      if (m.completeness * 100 < minCompletion) return false;
      return true;
    });
  }, [ranked, tierFilter, minCompletion]);

  const buildableFull = ranked.filter((m) => m.completeness === 1).length;
  const buildablePartial = ranked.filter(
    (m) => m.completeness >= 0.8 && m.completeness < 1
  ).length;

  const handleBuildDeck = (match: (typeof ranked)[0]) => {
    // Find actual card IDs for the deck recipe
    onBuildDeck(match.deck.name, match.deck.cards);
  };

  return (
    <div className="space-y-6">
      {/* Summary */}
      <div className="grid grid-cols-3 gap-4">
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-green-400">{buildableFull}</p>
          <p className="text-gray-400 text-sm">Fully Buildable</p>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-yellow-400">
            {buildablePartial}
          </p>
          <p className="text-gray-400 text-sm">Nearly Complete (80%+)</p>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-white">{META_DECKS.length}</p>
          <p className="text-gray-400 text-sm">Total Meta Decks</p>
        </div>
      </div>

      {/* Filters */}
      <div className="flex flex-wrap gap-3 items-center">
        <div className="flex rounded overflow-hidden border border-slate-600">
          {["", "S", "A", "B", "C"].map((tier) => (
            <button
              key={tier}
              onClick={() => setTierFilter(tier)}
              className={`px-3 py-1.5 text-sm ${
                tierFilter === tier
                  ? "bg-blue-600 text-white"
                  : "bg-slate-700 text-gray-300 hover:bg-slate-600"
              }`}
            >
              {tier || "All"}
            </button>
          ))}
        </div>

        <select
          value={minCompletion}
          onChange={(e) => setMinCompletion(Number(e.target.value))}
          className="bg-slate-700 text-white border border-slate-600 rounded px-3 py-1.5 text-sm"
        >
          <option value={0}>Any completion</option>
          <option value={50}>50%+ complete</option>
          <option value={80}>80%+ complete</option>
          <option value={100}>Fully buildable</option>
        </select>
      </div>

      <p className="text-gray-400 text-sm">
        {filtered.length} deck{filtered.length !== 1 ? "s" : ""} shown (sorted
        by completeness, then tier)
      </p>

      {/* Deck list */}
      <div className="space-y-3">
        {filtered.map((match) => (
          <MetaDeckCard
            key={match.deck.name}
            match={match}
            onBuildDeck={() => handleBuildDeck(match)}
          />
        ))}

        {filtered.length === 0 && (
          <div className="text-center text-gray-500 py-12">
            No decks match your filters. Try adjusting the tier or completion
            filter.
          </div>
        )}
      </div>
    </div>
  );
}
