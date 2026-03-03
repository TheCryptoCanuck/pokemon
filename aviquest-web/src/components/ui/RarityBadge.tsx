import { Rarity } from '../../lib/types';
import { RARITY_COLORS, RARITY_BG, RARITY_TEXT } from '../../lib/game';

interface RarityBadgeProps {
  rarity: Rarity;
  size?: 'sm' | 'md';
}

export default function RarityBadge({ rarity, size = 'md' }: RarityBadgeProps) {
  const label = rarity === 'unknown' ? 'NEW DISCOVERY' : rarity.toUpperCase();

  return (
    <span
      className={`inline-block rounded-full border font-bold ${RARITY_TEXT[rarity]} ${
        size === 'sm' ? 'px-2 py-0.5 text-[10px]' : 'px-3 py-1 text-xs'
      }`}
      style={{
        backgroundColor: RARITY_BG[rarity],
        borderColor: RARITY_COLORS[rarity],
      }}
    >
      {label}
    </span>
  );
}
