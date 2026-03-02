"use client";

import { useState } from "react";
import { Bird, Rarity } from "@/types";
import { birds } from "@/data/birds";
import { getRarityColor, getBirdXp } from "@/lib/progression";
import BirdDetailModal from "./BirdDetailModal";
import Image from "next/image";

const RARITY_FILTERS: { label: string; value: string }[] = [
  { label: "All", value: "all" },
  { label: "Common", value: "common" },
  { label: "Uncommon", value: "uncommon" },
  { label: "Rare", value: "rare" },
  { label: "Legendary", value: "legendary" },
];

export default function FieldGuideTab() {
  const [search, setSearch] = useState("");
  const [rarityFilter, setRarityFilter] = useState("all");
  const [selectedBird, setSelectedBird] = useState<Bird | null>(null);

  const filtered = birds.filter((b) => {
    const matchRarity =
      rarityFilter === "all" || b.rarity === rarityFilter;
    const matchSearch =
      search === "" ||
      b.name.toLowerCase().includes(search.toLowerCase()) ||
      b.scientificName.toLowerCase().includes(search.toLowerCase());
    return matchRarity && matchSearch;
  });

  return (
    <>
      <div className="flex flex-col h-full">
        {/* Search bar */}
        <div className="px-4 pt-3">
          <div
            className="flex items-center gap-2 px-4 py-2.5 rounded-2xl"
            style={{ backgroundColor: "var(--color-bg-card)" }}
          >
            <span className="text-white/30">🔍</span>
            <input
              type="text"
              placeholder="Search species..."
              value={search}
              onChange={(e) => setSearch(e.target.value)}
              className="flex-1 bg-transparent text-white placeholder:text-white/30 outline-none text-sm"
            />
            {search && (
              <button
                onClick={() => setSearch("")}
                className="text-white/30 hover:text-white/60 text-sm"
              >
                ✕
              </button>
            )}
          </div>
        </div>

        {/* Rarity filters */}
        <div className="flex gap-2 px-4 py-2 overflow-x-auto scrollbar-none">
          {RARITY_FILTERS.map((f) => {
            const isSelected = rarityFilter === f.value;
            const color =
              f.value === "all"
                ? "rgba(255,255,255,0.7)"
                : getRarityColor(f.value as Rarity);
            return (
              <button
                key={f.value}
                onClick={() => setRarityFilter(f.value)}
                className="px-4 py-1.5 rounded-full text-xs font-medium whitespace-nowrap border transition-all duration-200"
                style={{
                  color: isSelected ? color : "rgba(255,255,255,0.4)",
                  borderColor: isSelected ? color : "rgba(255,255,255,0.08)",
                  backgroundColor: isSelected ? `${color}20` : "var(--color-bg-card)",
                  fontWeight: isSelected ? 700 : 400,
                }}
              >
                {f.label}
              </button>
            );
          })}
        </div>

        {/* Bird list */}
        <div className="flex-1 overflow-y-auto px-4 pb-4">
          <div className="space-y-2">
            {filtered.map((bird, i) => {
              const rarityColor = getRarityColor(bird.rarity);
              const xp = getBirdXp(bird.baseXp, bird.rarity);
              return (
                <button
                  key={`${bird.name}-${i}`}
                  onClick={() => setSelectedBird(bird)}
                  className="w-full rounded-2xl border p-2.5 flex items-center gap-3 transition-colors hover:bg-white/[0.02] text-left animate-fade-in"
                  style={{
                    backgroundColor: "var(--color-bg-card)",
                    borderColor: `${rarityColor}40`,
                    animationDelay: `${Math.min(i * 20, 300)}ms`,
                  }}
                >
                  {/* Thumbnail */}
                  <div className="relative w-14 h-14 rounded-lg overflow-hidden shrink-0">
                    {bird.imageUrl ? (
                      <Image
                        src={bird.imageUrl}
                        alt={bird.name}
                        fill
                        className="object-cover"
                        sizes="56px"
                        unoptimized
                      />
                    ) : (
                      <div className="w-full h-full bg-white/5 flex items-center justify-center">
                        <span className="text-white/20 text-xl">?</span>
                      </div>
                    )}
                  </div>

                  {/* Info */}
                  <div className="flex-1 min-w-0">
                    <p className="font-bold text-sm truncate">{bird.name}</p>
                    <p className="text-white/40 italic text-xs truncate">
                      {bird.scientificName}
                    </p>
                    <div className="flex items-center gap-2 mt-0.5">
                      <span
                        className="text-[10px] px-1.5 py-0.5 rounded border"
                        style={{
                          color: rarityColor,
                          borderColor: `${rarityColor}50`,
                          backgroundColor: `${rarityColor}15`,
                        }}
                      >
                        {bird.rarity}
                      </span>
                      <span className="text-gold text-[11px]">+{xp} XP</span>
                    </div>
                  </div>

                  {/* Arrow */}
                  <span className="text-white/15 text-lg">›</span>
                </button>
              );
            })}
          </div>

          {filtered.length === 0 && (
            <div className="flex flex-col items-center justify-center py-16">
              <span className="text-4xl opacity-20 mb-2">🔍</span>
              <p className="text-white/40">No species found</p>
            </div>
          )}
        </div>
      </div>

      {selectedBird && (
        <BirdDetailModal
          bird={selectedBird}
          onClose={() => setSelectedBird(null)}
        />
      )}
    </>
  );
}
