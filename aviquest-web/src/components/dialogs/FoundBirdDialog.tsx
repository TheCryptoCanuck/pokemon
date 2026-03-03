'use client';

import { Bird } from '../../lib/types';
import { getBirdXp, RARITY_COLORS } from '../../lib/game';
import RarityBadge from '../ui/RarityBadge';
import BirdImage from '../ui/BirdImage';

interface FoundBirdDialogProps {
  bird: Bird | null;
  onAdd: () => void;
  onSkip: () => void;
}

export default function FoundBirdDialog({ bird, onAdd, onSkip }: FoundBirdDialogProps) {
  if (!bird) return null;

  const isUnknown = bird.rarity === 'unknown';

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" onClick={onSkip} />
      <div className="relative bg-[#1A2F1F] rounded-3xl p-5 max-w-sm w-full animate-scale-in overflow-y-auto max-h-[90dvh]">
        {/* Rarity badge */}
        <div className="flex justify-center mb-3 animate-fade-in">
          <RarityBadge rarity={bird.rarity} />
        </div>

        {/* Name */}
        <h2
          className="text-[22px] font-bold text-center mb-0.5"
          style={{ color: isUnknown ? RARITY_COLORS.unknown : RARITY_COLORS.legendary }}
        >
          {isUnknown ? `${bird.name}` : `${bird.name}`}
        </h2>
        <p className="text-white/50 text-center italic text-sm mb-3">
          {bird.scientificName}
        </p>

        {/* Image */}
        {isUnknown ? (
          <div
            className="h-[140px] rounded-2xl border flex flex-col items-center justify-center mb-3"
            style={{
              backgroundColor: `${RARITY_COLORS.unknown}08`,
              borderColor: `${RARITY_COLORS.unknown}40`,
            }}
          >
            <span className="text-[56px]">&#x2753;</span>
            <p className="text-purple-300 font-bold text-sm mt-1">
              Not in our database yet
            </p>
          </div>
        ) : (
          <div className="rounded-2xl overflow-hidden mb-3">
            <BirdImage src={bird.imageUrl} alt={bird.name} className="h-[220px]" />
          </div>
        )}

        {/* Lore */}
        <p className="text-white/70 text-center text-sm mb-2">{bird.lore}</p>

        {/* XP */}
        <div className="flex items-center justify-center gap-1 mb-4">
          <svg className="w-4 h-4 text-amber-400" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z" />
          </svg>
          <span className="text-amber-400 font-bold">+{getBirdXp(bird)} XP</span>
        </div>

        {/* Actions */}
        <div className="flex gap-3">
          <button
            onClick={onSkip}
            className="flex-1 py-3 rounded-xl border border-white/20 text-white/50 hover:text-white/70 hover:border-white/30 transition-colors"
          >
            Skip
          </button>
          <button
            onClick={onAdd}
            className="flex-1 py-3 rounded-xl bg-amber-400 text-black font-bold hover:bg-amber-300 transition-colors"
          >
            Add to Aviary
          </button>
        </div>
      </div>
    </div>
  );
}
