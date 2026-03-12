import { useState, useEffect } from "react";
import { Card, Tab, getCardId } from "./types/card";
import { fetchCards } from "./data/cards";
import { useCollection } from "./hooks/useCollection";
import { useDecks } from "./hooks/useDecks";
import Layout from "./components/Layout";
import CollectionPage from "./components/collection/CollectionPage";
import DeckBuilderPage from "./components/deck-builder/DeckBuilderPage";
import MetaDecksPage from "./components/meta/MetaDecksPage";

export default function App() {
  const [cards, setCards] = useState<Card[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [activeTab, setActiveTab] = useState<Tab>("collection");

  const {
    collection,
    addCard,
    removeCard,
    getCount,
    mergeCollection,
  } = useCollection();

  const {
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
  } = useDecks();

  useEffect(() => {
    fetchCards()
      .then(setCards)
      .catch((err) => setError(err.message))
      .finally(() => setLoading(false));
  }, []);

  const handleBuildMetaDeck = (
    name: string,
    cardNames: { cardName: string; count: number }[]
  ) => {
    const deckId = createDeck(name);
    for (const { cardName, count } of cardNames) {
      const card = cards.find(
        (c) => c.name.toLowerCase() === cardName.toLowerCase()
      );
      if (card) {
        const id = getCardId(card);
        for (let i = 0; i < count; i++) {
          addCardToDeck(deckId, id);
        }
      }
    }
    setActiveDeckId(deckId);
    setActiveTab("deck-builder");
  };

  if (loading) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center">
        <div className="text-center">
          <div className="animate-spin w-12 h-12 border-4 border-blue-500 border-t-transparent rounded-full mx-auto mb-4" />
          <p className="text-gray-400">Loading card database...</p>
        </div>
      </div>
    );
  }

  if (error) {
    return (
      <div className="min-h-screen bg-slate-900 flex items-center justify-center">
        <div className="text-center">
          <p className="text-red-400 text-lg">Failed to load cards</p>
          <p className="text-gray-500 text-sm mt-1">{error}</p>
          <button
            onClick={() => window.location.reload()}
            className="mt-4 bg-blue-600 text-white px-6 py-2 rounded"
          >
            Retry
          </button>
        </div>
      </div>
    );
  }

  return (
    <Layout activeTab={activeTab} onTabChange={setActiveTab}>
      {activeTab === "collection" && (
        <CollectionPage
          cards={cards}
          collection={collection}
          addCard={addCard}
          removeCard={removeCard}
          getCount={getCount}
          mergeCollection={mergeCollection}
        />
      )}

      {activeTab === "deck-builder" && (
        <DeckBuilderPage
          allCards={cards}
          getCount={getCount}
          decks={decks}
          activeDeck={activeDeck}
          activeDeckId={activeDeckId}
          setActiveDeckId={setActiveDeckId}
          createDeck={createDeck}
          deleteDeck={deleteDeck}
          renameDeck={renameDeck}
          duplicateDeck={duplicateDeck}
          addCardToDeck={addCardToDeck}
          removeCardFromDeck={removeCardFromDeck}
        />
      )}

      {activeTab === "meta" && (
        <MetaDecksPage
          allCards={cards}
          collection={collection}
          onBuildDeck={handleBuildMetaDeck}
        />
      )}
    </Layout>
  );
}
