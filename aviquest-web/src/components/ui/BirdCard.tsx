'use client';

import { Bird } from '../../lib/types';
import { RARITY_COLORS } from '../../lib/game';
import BirdImage from './BirdImage';

interface BirdCardProps {
  bird: Bird;
  onClick: (bird: Bird) => void;
}

export default function BirdCard({ bird, onClick }: BirdCardProps) {
  return (
    <button
      onClick={() => onClick(bird)}
      className="group relative overflow-hidden rounded-2xl border bg-[#1A2F1F] transition-transform hover:scale-[1.02] active:scale-[0.98] focus:outline-none focus-visible:ring-2 focus-visible:ring-amber-400 w-full aspect-[0.82]"
      style={{ borderColor: `${RARITY_COLORS[bird.rarity]}60` }}
    >
      <BirdImage
        src={bird.imageUrl}
        alt={bird.name}
        className="absolute inset-0"
      />
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/80 to-transparent p-2">
        <p className="text-white font-bold text-[13px] text-left truncate">{bird.name}</p>
        <p
          className="text-[11px] text-left"
          style={{ color: RARITY_COLORS[bird.rarity] }}
        >
          {bird.rarity}
        </p>
      </div>
    </button>
  );
}
