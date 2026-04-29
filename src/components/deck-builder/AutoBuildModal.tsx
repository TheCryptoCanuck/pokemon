import { useState } from "react";
import { Card, CollectionEntry, ENERGY_TYPES } from "../../types/card";
import { autoBuild } from "../../utils/auto-build";

interface Props {
  allCards: Card[];
  collection: CollectionEntry[];
  onClose: () => void;
  onBuild: (name: string, energyTypes: string[], pool: "all" | "owned") => void;
}

const SELECTABLE_TYPES = ENERGY_TYPES.filter((t) => t !== "colorless");

const TYPE_COLORS: Record<string, string> = {
  grass: "bg-green-600 hover:bg-green-700",
  fire: "bg-red-600 hover:bg-red-700",
  water: "bg-blue-600 hover:bg-blue-700",
  lightning: "bg-yellow-500 hover:bg-yellow-600",
  psychic: "bg-purple-600 hover:bg-purple-700",
  fighting: "bg-orange-700 hover:bg-orange-800",
  darkness: "bg-gray-800 hover:bg-gray-900",
  metal: "bg-gray-500 hover:bg-gray-600",
};

export default function AutoBuildModal({
  allCards,
  collection,
  onClose,
  onBuild,
}: Props) {
  const [selected, setSelected] = useState<string[]>([]);
  const [useOwnedOnly, setUseOwnedOnly] = useState(collection.length > 0);
  const [previewWarnings, setPreviewWarnings] = useState<string[] | null>(null);

  const toggleType = (type: string) => {
    setPreviewWarnings(null);
    setSelected((prev) => {
      if (prev.includes(type)) return prev.filter((t) => t !== type);
      // Cap at 3; if at cap, drop the oldest.
      const next = [...prev, type];
      return next.length > 3 ? next.slice(1) : next;
    });
  };

  const handleBuild = () => {
    if (selected.length === 0) return;
    // Run a dry build to surface warnings before we create a deck.
    const result = autoBuild(allCards, {
      energyTypes: selected,
      pool: useOwnedOnly ? "owned" : "all",
      collection,
    });
    if (result.cards.length === 0) {
      setPreviewWarnings(
        result.warnings.length > 0
          ? result.warnings
          : ["Could not build a deck for those settings."]
      );
      return;
    }
    const name =
      selected.length === 1
        ? `Auto: ${selected[0]}`
        : `Auto: ${selected.join("/")}`;
    onBuild(name, selected, useOwnedOnly ? "owned" : "all");
  };

  return (
    <div
      className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      onClick={onClose}
    >
      <div
        className="bg-slate-800 border border-slate-700 rounded-lg p-5 max-w-md w-full"
        onClick={(e) => e.stopPropagation()}
      >
        <h3 className="text-lg font-bold text-white mb-1">Auto-Build Deck</h3>
        <p className="text-sm text-gray-400 mb-4">
          Pick 1–3 energy types. We'll assemble the highest-scoring legal
          20-card deck for you.
        </p>

        <div className="mb-4">
          <h4 className="text-xs text-gray-400 uppercase tracking-wider mb-2">
            Energy Types ({selected.length}/3)
          </h4>
          <div className="grid grid-cols-4 gap-2">
            {SELECTABLE_TYPES.map((type) => {
              const isSelected = selected.includes(type);
              return (
                <button
                  key={type}
                  onClick={() => toggleType(type)}
                  className={`px-2 py-2 rounded text-xs font-semibold capitalize transition ${
                    isSelected
                      ? `${TYPE_COLORS[type] || "bg-slate-600"} text-white ring-2 ring-white`
                      : "bg-slate-700 text-gray-400 hover:bg-slate-600"
                  }`}
                >
                  {type}
                </button>
              );
            })}
          </div>
        </div>

        <label className="flex items-center gap-2 text-sm text-gray-300 mb-4">
          <input
            type="checkbox"
            checked={useOwnedOnly}
            onChange={(e) => {
              setPreviewWarnings(null);
              setUseOwnedOnly(e.target.checked);
            }}
            disabled={collection.length === 0}
            className="rounded"
          />
          <span>
            Use only cards I own
            {collection.length === 0 && (
              <span className="text-gray-500 italic ml-1">
                (collection empty)
              </span>
            )}
          </span>
        </label>

        {previewWarnings && (
          <div className="bg-rose-900/30 border border-rose-700 rounded p-2 mb-4">
            {previewWarnings.map((w, i) => (
              <p key={i} className="text-rose-300 text-xs">
                {w}
              </p>
            ))}
          </div>
        )}

        <div className="flex gap-2 justify-end">
          <button
            onClick={onClose}
            className="bg-slate-700 hover:bg-slate-600 text-white px-4 py-2 rounded text-sm"
          >
            Cancel
          </button>
          <button
            onClick={handleBuild}
            disabled={selected.length === 0}
            className="bg-purple-600 hover:bg-purple-700 disabled:bg-slate-700 disabled:text-gray-500 text-white px-4 py-2 rounded text-sm font-semibold"
          >
            ⚡ Auto-Build
          </button>
        </div>
      </div>
    </div>
  );
}
