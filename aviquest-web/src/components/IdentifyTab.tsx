"use client";

import { useState } from "react";
import { Bird } from "@/types";
import { getWeightedRandomBird } from "@/data/birds";
import { getRarityColor, getBirdXp } from "@/lib/progression";
import Image from "next/image";

interface IdentifyTabProps {
  onAddBird: (bird: Bird) => void;
}

type IdentifyState = "idle" | "analyzing" | "result";

export default function IdentifyTab({ onAddBird }: IdentifyTabProps) {
  const [state, setState] = useState<IdentifyState>("idle");
  const [foundBird, setFoundBird] = useState<Bird | null>(null);

  const handleIdentify = () => {
    setState("analyzing");
    // Simulate analysis delay
    setTimeout(() => {
      const bird = getWeightedRandomBird();
      setFoundBird(bird);
      setState("result");
    }, 1500 + Math.random() * 1000);
  };

  const handleAdd = () => {
    if (foundBird) {
      onAddBird(foundBird);
      setState("idle");
      setFoundBird(null);
    }
  };

  const handleSkip = () => {
    setState("idle");
    setFoundBird(null);
  };

  if (state === "analyzing") {
    return (
      <div className="flex flex-col items-center justify-center h-full animate-fade-in">
        <div className="w-16 h-16 rounded-full border-4 border-gold/30 border-t-gold animate-spin mb-6" />
        <h2 className="text-xl font-bold text-gold mb-2">Analysing...</h2>
        <p className="text-white/50">Processing photo...</p>
      </div>
    );
  }

  if (state === "result" && foundBird) {
    const rarityColor = getRarityColor(foundBird.rarity);
    const xp = getBirdXp(foundBird.baseXp, foundBird.rarity);

    return (
      <div className="flex flex-col items-center px-6 py-8 h-full overflow-y-auto animate-scale-in">
        {/* Rarity badge */}
        <span
          className="px-3 py-1 rounded-full text-xs font-bold border mb-3"
          style={{
            color: rarityColor,
            borderColor: rarityColor,
            backgroundColor: `${rarityColor}15`,
          }}
        >
          {foundBird.rarity.toUpperCase()}
        </span>

        <h2 className="text-2xl font-bold text-gold mb-1">{foundBird.name}</h2>
        <p className="text-white/50 italic text-sm mb-4">
          {foundBird.scientificName}
        </p>

        {/* Image */}
        {foundBird.imageUrl && (
          <div className="relative w-full max-w-sm h-52 rounded-2xl overflow-hidden mb-4">
            <Image
              src={foundBird.imageUrl}
              alt={foundBird.name}
              fill
              className="object-cover"
              sizes="400px"
              unoptimized
            />
          </div>
        )}

        <p className="text-white/60 text-center text-sm mb-3 max-w-sm">
          {foundBird.lore}
        </p>

        <div className="flex items-center gap-1 text-gold font-bold mb-6">
          <span>⚡</span>
          <span>+{xp} XP</span>
        </div>

        {/* Action buttons */}
        <div className="flex gap-3 w-full max-w-sm">
          <button
            onClick={handleSkip}
            className="flex-1 py-3 rounded-xl font-medium text-white/50 border border-white/10 hover:border-white/20 transition-colors"
          >
            Skip
          </button>
          <button
            onClick={handleAdd}
            className="flex-1 py-3 rounded-xl font-bold text-black transition-transform hover:scale-[1.02] active:scale-95"
            style={{ backgroundColor: "var(--color-gold)" }}
          >
            Add to Aviary
          </button>
        </div>
      </div>
    );
  }

  // Idle state
  return (
    <div className="flex flex-col items-center justify-center h-full px-6">
      <h1 className="text-3xl font-bold text-gold mb-2 animate-fade-in">
        AviQuest
      </h1>
      <p className="text-white/50 mb-8 animate-fade-in stagger-1">
        Point at a bird and identify it!
      </p>

      {/* Camera placeholder */}
      <div
        className="w-full max-w-sm h-72 rounded-3xl border border-white/10 flex flex-col items-center justify-center mb-8 animate-fade-in stagger-2"
        style={{ backgroundColor: "var(--color-bg-card)" }}
      >
        <span className="text-6xl mb-2 opacity-20">📷</span>
        <p className="text-white/30 text-sm">Camera preview</p>
        <p className="text-white/20 text-xs mt-1">
          Web version uses simulated identification
        </p>
      </div>

      {/* Action buttons */}
      <div className="flex gap-4 animate-fade-in stagger-3">
        <button
          onClick={handleIdentify}
          className="px-6 py-3 rounded-2xl font-bold text-black flex items-center gap-2 transition-transform hover:scale-[1.02] active:scale-95"
          style={{ backgroundColor: "var(--color-gold)" }}
        >
          <span>📷</span>
          Identify by Photo
        </button>
        <button
          onClick={handleIdentify}
          className="px-5 py-3 rounded-2xl font-bold border flex items-center gap-2 transition-colors hover:bg-gold/10"
          style={{
            color: "var(--color-gold)",
            borderColor: "var(--color-gold)",
          }}
        >
          <span>🎤</span>
          By Call
        </button>
      </div>
    </div>
  );
}
