import { useState, useMemo } from "react";
import { Card, CollectionEntry, getCardId, RARITY_ORDER } from "../../types/card";
import { getSets, getElements } from "../../data/cards";
import CardGrid from "./CardGrid";
import CardFilters from "./CardFilters";
import VideoImport from "./VideoImport";
import CardModal from "../shared/CardModal";

interface Props {
  cards: Card[];
  collection: CollectionEntry[];
  addCard: (cardId: string) => void;
  removeCard: (cardId: string) => void;
  getCount: (cardId: string) => number;
  mergeCollection: (entries: CollectionEntry[]) => void;
}

export default function CollectionPage({
  cards,
  collection,
  addCard,
  removeCard,
  getCount,
  mergeCollection,
}: Props) {
  const [search, setSearch] = useState("");
  const [selectedType, setSelectedType] = useState("");
  const [selectedSet, setSelectedSet] = useState("");
  const [selectedRarity, setSelectedRarity] = useState("");
  const [showOwned, setShowOwned] = useState<"all" | "owned" | "missing">(
    "all"
  );
  const [showImport, setShowImport] = useState(false);
  const [selectedCard, setSelectedCard] = useState<Card | null>(null);

  const sets = useMemo(() => getSets(cards), [cards]);
  const types = useMemo(() => getElements(cards), [cards]);

  const filteredCards = useMemo(() => {
    return cards.filter((card) => {
      if (search && !card.name.toLowerCase().includes(search.toLowerCase()))
        return false;
      if (selectedType && card.element !== selectedType) return false;
      if (selectedSet && card.set !== selectedSet) return false;
      if (selectedRarity && card.rarity !== selectedRarity) return false;

      const id = getCardId(card);
      const count = getCount(id);
      if (showOwned === "owned" && count === 0) return false;
      if (showOwned === "missing" && count > 0) return false;

      return true;
    }).sort((a, b) => {
      const setCompare = a.set.localeCompare(b.set);
      if (setCompare !== 0) return setCompare;
      return a.number - b.number;
    });
  }, [cards, search, selectedType, selectedSet, selectedRarity, showOwned, getCount]);

  const totalOwned = collection.reduce((sum, e) => sum + (e.count > 0 ? 1 : 0), 0);
  const totalCards = cards.length;
  const completionPct = totalCards > 0 ? Math.round((totalOwned / totalCards) * 100) : 0;

  const rarityStats = useMemo(() => {
    const stats: Record<string, { owned: number; total: number }> = {};
    for (const card of cards) {
      if (!stats[card.rarity]) stats[card.rarity] = { owned: 0, total: 0 };
      stats[card.rarity].total++;
      if (getCount(getCardId(card)) > 0) stats[card.rarity].owned++;
    }
    return Object.entries(stats).sort(
      ([a], [b]) => (RARITY_ORDER[a] || 0) - (RARITY_ORDER[b] || 0)
    );
  }, [cards, getCount]);

  return (
    <div className="space-y-6">
      {/* Stats */}
      <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-white">{totalOwned}</p>
          <p className="text-gray-400 text-sm">Cards Owned</p>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-white">{totalCards}</p>
          <p className="text-gray-400 text-sm">Total Cards</p>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-blue-400">{completionPct}%</p>
          <p className="text-gray-400 text-sm">Complete</p>
        </div>
        <div className="bg-slate-800 rounded-lg p-4 text-center">
          <p className="text-3xl font-bold text-purple-400">{sets.length}</p>
          <p className="text-gray-400 text-sm">Sets</p>
        </div>
      </div>

      {/* Rarity breakdown */}
      <div className="bg-slate-800 rounded-lg p-4">
        <h3 className="text-sm font-semibold text-gray-400 mb-2">
          By Rarity
        </h3>
        <div className="flex flex-wrap gap-3">
          {rarityStats.map(([rarity, { owned, total }]) => (
            <div key={rarity} className="text-center">
              <span className="text-xs text-gray-400">{rarity}</span>
              <p className="text-sm font-semibold text-white">
                {owned}/{total}
              </p>
            </div>
          ))}
        </div>
      </div>

      {/* Import section */}
      <div className="flex gap-3">
        <button
          onClick={() => setShowImport(!showImport)}
          className={`px-4 py-2 rounded font-semibold text-sm ${
            showImport
              ? "bg-slate-600 text-white"
              : "bg-blue-600 hover:bg-blue-700 text-white"
          }`}
        >
          {showImport ? "Hide Video Import" : "Import from Video"}
        </button>
      </div>

      {showImport && (
        <VideoImport allCards={cards} onImport={mergeCollection} />
      )}

      {/* Filters */}
      <CardFilters
        search={search}
        onSearchChange={setSearch}
        selectedType={selectedType}
        onTypeChange={setSelectedType}
        selectedSet={selectedSet}
        onSetChange={setSelectedSet}
        selectedRarity={selectedRarity}
        onRarityChange={setSelectedRarity}
        showOwned={showOwned}
        onShowOwnedChange={setShowOwned}
        sets={sets}
        types={types}
      />

      {/* Card count */}
      <p className="text-gray-400 text-sm">
        Showing {filteredCards.length} cards
      </p>

      {/* Card grid */}
      <CardGrid
        cards={filteredCards}
        getCount={getCount}
        onAdd={addCard}
        onRemove={removeCard}
        onCardClick={setSelectedCard}
      />

      {/* Card modal */}
      {selectedCard && (
        <CardModal
          card={selectedCard}
          count={getCount(getCardId(selectedCard))}
          onClose={() => setSelectedCard(null)}
          onAdd={() => addCard(getCardId(selectedCard))}
          onRemove={
            getCount(getCardId(selectedCard)) > 0
              ? () => removeCard(getCardId(selectedCard))
              : undefined
          }
        />
      )}
    </div>
  );
}
