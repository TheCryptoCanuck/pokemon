import { useState, useMemo } from "react";
import { Card, Deck, getCardId } from "../../types/card";
import { validateDeck, canAddCard, getDeckStats } from "../../utils/deck-rules";
import { getElements, getSets } from "../../data/cards";
import CardDisplay from "../shared/CardDisplay";
import DeckValidation from "./DeckValidation";
import DeckAnalysis from "./DeckAnalysis";

interface Props {
  deck: Deck;
  allCards: Card[];
  collectionFilter: boolean;
  getCount: (cardId: string) => number;
  onAddCard: (cardId: string) => void;
  onRemoveCard: (cardId: string) => void;
  onRename: (name: string) => void;
}

export default function DeckEditor({
  deck,
  allCards,
  collectionFilter,
  getCount,
  onAddCard,
  onRemoveCard,
  onRename,
}: Props) {
  const [search, setSearch] = useState("");
  const [selectedType, setSelectedType] = useState("");
  const [selectedSet, setSelectedSet] = useState("");
  const [editingName, setEditingName] = useState(false);
  const [nameInput, setNameInput] = useState(deck.name);

  const errors = useMemo(
    () => validateDeck(deck.cards, allCards),
    [deck.cards, allCards]
  );

  const stats = useMemo(
    () => getDeckStats(deck.cards, allCards),
    [deck.cards, allCards]
  );

  const types = useMemo(() => getElements(allCards), [allCards]);
  const sets = useMemo(() => getSets(allCards), [allCards]);

  const availableCards = useMemo(() => {
    return allCards.filter((card) => {
      if (search && !card.name.toLowerCase().includes(search.toLowerCase()))
        return false;
      if (selectedType && card.element !== selectedType) return false;
      if (selectedSet && card.set !== selectedSet) return false;
      if (collectionFilter && getCount(getCardId(card)) === 0) return false;
      return true;
    });
  }, [allCards, search, selectedType, selectedSet, collectionFilter, getCount]);

  const deckCardDetails = useMemo(() => {
    return deck.cards
      .map((dc) => ({
        ...dc,
        card: allCards.find((c) => getCardId(c) === dc.cardId),
      }))
      .filter((dc) => dc.card);
  }, [deck.cards, allCards]);

  const selectClass =
    "bg-slate-700 text-white border border-slate-600 rounded px-2 py-1.5 text-sm focus:outline-none focus:border-blue-500";

  return (
    <div className="grid grid-cols-1 lg:grid-cols-3 gap-6">
      {/* Left: Card browser */}
      <div className="lg:col-span-2 space-y-4">
        <div className="flex flex-wrap gap-2">
          <input
            type="text"
            placeholder="Search cards..."
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            className="bg-slate-700 text-white border border-slate-600 rounded px-3 py-1.5 text-sm focus:outline-none focus:border-blue-500 w-40"
          />
          <select
            value={selectedType}
            onChange={(e) => setSelectedType(e.target.value)}
            className={selectClass}
          >
            <option value="">All Types</option>
            {types.map((t) => (
              <option key={t} value={t}>
                {t.charAt(0).toUpperCase() + t.slice(1)}
              </option>
            ))}
          </select>
          <select
            value={selectedSet}
            onChange={(e) => setSelectedSet(e.target.value)}
            className={selectClass}
          >
            <option value="">All Sets</option>
            {sets.map((s) => (
              <option key={s} value={s}>
                {s}
              </option>
            ))}
          </select>
        </div>

        <p className="text-gray-400 text-xs">{availableCards.length} cards</p>

        <div className="flex flex-wrap gap-2 max-h-[600px] overflow-y-auto">
          {availableCards.slice(0, 100).map((card) => {
            const id = getCardId(card);
            const addError = canAddCard(deck.cards, id, card, allCards);
            return (
              <div key={id} className={addError ? "opacity-40" : ""}>
                <CardDisplay
                  card={card}
                  compact
                  onClick={
                    !addError
                      ? () => onAddCard(id)
                      : undefined
                  }
                />
              </div>
            );
          })}
          {availableCards.length > 100 && (
            <p className="text-gray-500 text-sm w-full text-center py-2">
              Showing first 100 results. Use filters to narrow down.
            </p>
          )}
        </div>
      </div>

      {/* Right: Deck panel */}
      <div className="space-y-4">
        {/* Deck name */}
        <div>
          {editingName ? (
            <div className="flex gap-2">
              <input
                value={nameInput}
                onChange={(e) => setNameInput(e.target.value)}
                className="bg-slate-700 text-white border border-slate-600 rounded px-3 py-1.5 text-sm flex-1"
                autoFocus
                onKeyDown={(e) => {
                  if (e.key === "Enter") {
                    onRename(nameInput);
                    setEditingName(false);
                  }
                }}
              />
              <button
                onClick={() => {
                  onRename(nameInput);
                  setEditingName(false);
                }}
                className="bg-blue-600 text-white px-3 py-1.5 rounded text-sm"
              >
                Save
              </button>
            </div>
          ) : (
            <h3
              onClick={() => {
                setNameInput(deck.name);
                setEditingName(true);
              }}
              className="text-lg font-bold text-white cursor-pointer hover:text-blue-400"
            >
              {deck.name}
            </h3>
          )}
        </div>

        {/* Validation */}
        <DeckValidation errors={errors} totalCards={stats.totalCards} />

        {/* Deck cards */}
        <div className="space-y-1 max-h-[400px] overflow-y-auto">
          {deckCardDetails.length === 0 && (
            <p className="text-gray-500 text-sm text-center py-8">
              Click cards on the left to add them
            </p>
          )}
          {deckCardDetails.map(({ cardId, count, card }) => (
            <div
              key={cardId}
              className="flex items-center gap-2 bg-slate-700 rounded p-2"
            >
              <img
                src={`https://raw.githubusercontent.com/flibustier/pokemon-tcg-pocket-database/main/dist/images/${card!.image}`}
                alt={card!.name}
                className="w-8 h-11 rounded object-cover"
              />
              <div className="flex-1 min-w-0">
                <p className="text-white text-sm truncate">{card!.name}</p>
                <p className="text-gray-400 text-xs capitalize">
                  {card!.element || "colorless"} - {card!.set}
                </p>
              </div>
              <span className="text-blue-400 font-bold text-sm">x{count}</span>
              <button
                onClick={() => onRemoveCard(cardId)}
                className="text-red-400 hover:text-red-300 text-sm px-1"
              >
                -
              </button>
            </div>
          ))}
        </div>

        {/* Analysis */}
        <DeckAnalysis {...stats} />
      </div>
    </div>
  );
}
