"use client";

import { useState } from "react";
import { Bird } from "@/types";
import { birds } from "@/data/birds";
import { unknownBird } from "@/data/birds";
import { getRarityColor } from "@/lib/progression";
import BirdDetailModal from "./BirdDetailModal";
import Image from "next/image";

interface AviaryTabProps {
  aviary: string[];
  onNavigateToIdentify: () => void;
}

export default function AviaryTab({
  aviary,
  onNavigateToIdentify,
}: AviaryTabProps) {
  const [selectedBird, setSelectedBird] = useState<Bird | null>(null);

  if (aviary.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center h-full animate-fade-in">
        <span className="text-6xl mb-4 opacity-20">✨</span>
        <h2 className="text-xl font-bold text-white/50 mb-2">
          Your aviary is empty!
        </h2>
        <p className="text-white/30 mb-6">
          Identify birds to add them here.
        </p>
        <button
          onClick={onNavigateToIdentify}
          className="px-6 py-3 rounded-2xl font-bold text-black transition-transform hover:scale-[1.02] active:scale-95"
          style={{ backgroundColor: "var(--color-gold)" }}
        >
          Go Identify
        </button>
      </div>
    );
  }

  const aviaryBirds = aviary.map(
    (name) => birds.find((b) => b.name === name) ?? unknownBird(name)
  );

  return (
    <>
      <div className="h-full overflow-y-auto p-4">
        <div className="grid grid-cols-2 sm:grid-cols-3 gap-3">
          {aviaryBirds.map((bird, i) => {
            const rarityColor = getRarityColor(bird.rarity);
            return (
              <button
                key={`${bird.name}-${i}`}
                onClick={() => setSelectedBird(bird)}
                className="rounded-2xl overflow-hidden relative group animate-scale-in"
                style={{
                  aspectRatio: "0.82",
                  animationDelay: `${Math.min(i * 30, 300)}ms`,
                }}
              >
                {/* Card border */}
                <div
                  className="absolute inset-0 rounded-2xl border-[1.5px] z-10 pointer-events-none"
                  style={{ borderColor: `${rarityColor}60` }}
                />

                {/* Image */}
                {bird.imageUrl ? (
                  <Image
                    src={bird.imageUrl}
                    alt={bird.name}
                    fill
                    className="object-cover transition-transform duration-300 group-hover:scale-105"
                    sizes="(max-width: 640px) 50vw, 33vw"
                    unoptimized
                  />
                ) : (
                  <div
                    className="w-full h-full flex items-center justify-center"
                    style={{ backgroundColor: "var(--color-bg-card)" }}
                  >
                    <span className="text-4xl opacity-20">?</span>
                  </div>
                )}

                {/* Gradient overlay */}
                <div className="absolute bottom-0 left-0 right-0 p-2 bg-gradient-to-t from-black/80 to-transparent">
                  <p className="text-white font-bold text-xs leading-tight truncate">
                    {bird.name}
                  </p>
                  <p className="text-[10px]" style={{ color: rarityColor }}>
                    {bird.rarity}
                  </p>
                </div>
              </button>
            );
          })}
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
