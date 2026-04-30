import { useEffect, useState } from "react";
import { Tab } from "../types/card";

interface Props {
  activeTab: Tab;
  onTabChange: (tab: Tab) => void;
  children: React.ReactNode;
}

const TABS: { id: Tab; label: string }[] = [
  { id: "collection", label: "Collection" },
  { id: "deck-builder", label: "Deck Builder" },
  { id: "pinned", label: "Pinned" },
  { id: "meta", label: "Meta Decks" },
];

export default function Layout({ activeTab, onTabChange, children }: Props) {
  // Drop a soft shadow on the sticky header once you've scrolled past the
  // first few pixels — gives the header a sense of depth without
  // intruding when at the top.
  const [scrolled, setScrolled] = useState(false);
  useEffect(() => {
    const onScroll = () => setScrolled(window.scrollY > 4);
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <div className="min-h-screen bg-slate-900">
      {/* Header */}
      <header
        className={`bg-slate-800 border-b border-slate-700 sticky top-0 z-40 transition-shadow duration-200 ${
          scrolled ? "shadow-lg shadow-black/40" : ""
        }`}
      >
        <div className="max-w-7xl mx-auto px-4">
          <div className="flex items-center justify-between h-14">
            <h1 className="text-xl font-bold text-white tracking-tight">
              <span className="text-blue-400">TCGP</span> Deck Builder
            </h1>

            <nav className="flex gap-1 overflow-x-auto whitespace-nowrap">
              {TABS.map((tab) => (
                <button
                  key={tab.id}
                  onClick={() => onTabChange(tab.id)}
                  aria-current={activeTab === tab.id ? "page" : undefined}
                  className={`px-3 py-2 rounded text-sm font-medium transition-colors shrink-0 focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-blue-400 ${
                    activeTab === tab.id
                      ? "bg-blue-600 text-white"
                      : "text-gray-400 hover:text-white hover:bg-slate-700"
                  }`}
                >
                  {tab.label}
                </button>
              ))}
            </nav>
          </div>
        </div>
      </header>

      {/* Content. Re-key on activeTab so each tab swap triggers
          animate-slide-up-fade — subtle 200ms cue that the page changed. */}
      <main key={activeTab} className="max-w-7xl mx-auto px-4 py-6 animate-slide-up-fade">
        {children}
      </main>
    </div>
  );
}
