import { useState } from "react";
import { Card, Deck } from "../../types/card";
import DeckEditor from "./DeckEditor";

interface Props {
  allCards: Card[];
  getCount: (cardId: string) => number;
  decks: Deck[];
  activeDeck: Deck | null;
  activeDeckId: string | null;
  setActiveDeckId: (id: string | null) => void;
  createDeck: (name: string) => string;
  deleteDeck: (id: string) => void;
  renameDeck: (id: string, name: string) => void;
  duplicateDeck: (id: string) => string | null;
  addCardToDeck: (deckId: string, cardId: string) => void;
  removeCardFromDeck: (deckId: string, cardId: string) => void;
}

export default function DeckBuilderPage({
  allCards,
  getCount,
  decks,
  activeDeck,
  activeDeckId,
  setActiveDeckId,
  createDeck,
  deleteDeck,
  renameDeck,
  duplicateDeck,
  addCardToDeck,
  removeCardFromDeck,
}: Props) {
  const [collectionOnly, setCollectionOnly] = useState(true);

  return (
    <div className="space-y-6">
      {/* Deck list header */}
      <div className="flex flex-wrap items-center gap-3">
        <button
          onClick={() => createDeck("New Deck")}
          className="bg-blue-600 hover:bg-blue-700 text-white px-4 py-2 rounded font-semibold text-sm"
        >
          + New Deck
        </button>

        <label className="flex items-center gap-2 text-sm text-gray-300">
          <input
            type="checkbox"
            checked={collectionOnly}
            onChange={(e) => setCollectionOnly(e.target.checked)}
            className="rounded"
          />
          Show only owned cards
        </label>
      </div>

      {/* Deck tabs */}
      {decks.length > 0 && (
        <div className="flex flex-wrap gap-2">
          {decks.map((deck) => (
            <div key={deck.id} className="flex items-center">
              <button
                onClick={() => setActiveDeckId(deck.id)}
                className={`px-3 py-1.5 rounded-l text-sm ${
                  activeDeckId === deck.id
                    ? "bg-blue-600 text-white"
                    : "bg-slate-700 text-gray-300 hover:bg-slate-600"
                }`}
              >
                {deck.name}
                <span className="ml-1 text-xs opacity-70">
                  ({deck.cards.reduce((s, c) => s + c.count, 0)}/20)
                </span>
              </button>
              <div className="flex">
                <button
                  onClick={() => duplicateDeck(deck.id)}
                  className="bg-slate-600 hover:bg-slate-500 text-gray-300 px-1.5 py-1.5 text-xs border-l border-slate-500"
                  title="Duplicate"
                >
                  cp
                </button>
                <button
                  onClick={() => {
                    if (confirm(`Delete "${deck.name}"?`))
                      deleteDeck(deck.id);
                  }}
                  className="bg-slate-600 hover:bg-red-600 text-gray-300 px-1.5 py-1.5 rounded-r text-xs border-l border-slate-500"
                  title="Delete"
                >
                  x
                </button>
              </div>
            </div>
          ))}
        </div>
      )}

      {/* Active deck editor */}
      {activeDeck ? (
        <DeckEditor
          deck={activeDeck}
          allCards={allCards}
          collectionFilter={collectionOnly}
          getCount={getCount}
          onAddCard={(cardId) => addCardToDeck(activeDeck.id, cardId)}
          onRemoveCard={(cardId) =>
            removeCardFromDeck(activeDeck.id, cardId)
          }
          onRename={(name) => renameDeck(activeDeck.id, name)}
        />
      ) : (
        <div className="text-center text-gray-500 py-16">
          <p className="text-lg">No deck selected</p>
          <p className="text-sm mt-1">
            Create a new deck or select an existing one
          </p>
        </div>
      )}
    </div>
  );
}
