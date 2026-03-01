'use client';

import { useState, useMemo } from 'react';
import { Bird, Rarity } from '../../lib/types';
import { getBirdXp, RARITY_COLORS, RARITY_TEXT } from '../../lib/game';
import { birds } from '../../data/birds';
import BirdImage from '../ui/BirdImage';
import BirdDetail from '../ui/BirdDetail';

const FILTER_OPTIONS: Array<{ id: string; label: string }> = [
  { id: 'all', label: 'All' },
  { id: 'common', label: 'Common' },
  { id: 'uncommon', label: 'Uncommon' },
  { id: 'rare', label: 'Rare' },
  { id: 'legendary', label: 'Legendary' },
];

export default function FieldGuideTab() {
  const [search, setSearch] = useState('');
  const [rarityFilter, setRarityFilter] = useState('all');
  const [selectedBird, setSelectedBird] = useState<Bird | null>(null);

  const filtered = useMemo(() => {
    return birds.filter(b => {
      const matchRarity = rarityFilter === 'all' || b.rarity === rarityFilter;
      const matchSearch =
        !search ||
        b.name.toLowerCase().includes(search.toLowerCase()) ||
        b.scientificName.toLowerCase().includes(search.toLowerCase());
      return matchRarity && matchSearch;
    });
  }, [search, rarityFilter]);

  return (
    <div className="flex flex-col h-[calc(100dvh-64px)]">
      {/* Search */}
      <div className="px-4 pt-3">
        <div className="relative">
          <svg className="absolute left-3 top-1/2 -translate-y-1/2 w-5 h-5 text-white/30" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
          </svg>
          <input
            type="text"
            placeholder="Search species..."
            value={search}
            onChange={e => setSearch(e.target.value)}
            className="w-full pl-10 pr-4 py-2.5 bg-[#1A2F1F] rounded-2xl text-white placeholder-white/30 border-none outline-none focus:ring-2 focus:ring-amber-400/50"
          />
        </div>
      </div>

      {/* Rarity filters */}
      <div className="flex gap-2 px-4 py-2 overflow-x-auto scrollbar-hide">
        {FILTER_OPTIONS.map(opt => {
          const isActive = rarityFilter === opt.id;
          const color = opt.id === 'all' ? 'rgb(180,180,180)' : RARITY_COLORS[opt.id as Rarity];
          return (
            <button
              key={opt.id}
              onClick={() => setRarityFilter(opt.id)}
              className={`shrink-0 px-4 py-1.5 rounded-full text-sm border transition-all ${
                isActive
                  ? 'font-bold'
                  : 'bg-[#1A2F1F] border-white/10 text-white/50 hover:border-white/20'
              }`}
              style={
                isActive
                  ? {
                      backgroundColor: `${color}20`,
                      borderColor: color,
                      color: color,
                    }
                  : undefined
              }
            >
              {opt.label}
            </button>
          );
        })}
      </div>

      {/* List */}
      <div className="flex-1 overflow-y-auto px-4 pb-20">
        {filtered.length === 0 ? (
          <div className="flex flex-col items-center justify-center py-20 text-white/30">
            <svg className="w-12 h-12 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
              <path strokeLinecap="round" strokeLinejoin="round" d="m21 21-5.197-5.197m0 0A7.5 7.5 0 1 0 5.196 5.196a7.5 7.5 0 0 0 10.607 10.607Z" />
            </svg>
            <p>No species found</p>
          </div>
        ) : (
          filtered.map(bird => (
            <button
              key={bird.name}
              onClick={() => setSelectedBird(bird)}
              className="w-full flex items-center gap-3 p-3 mb-2 bg-[#1A2F1F] rounded-2xl border transition-colors hover:bg-[#1A2F1F]/80 text-left"
              style={{ borderColor: `${RARITY_COLORS[bird.rarity]}40` }}
            >
              <div className="w-[60px] h-[60px] rounded-lg overflow-hidden shrink-0">
                <BirdImage src={bird.imageUrl} alt={bird.name} className="w-full h-full" />
              </div>
              <div className="flex-1 min-w-0">
                <p className="text-white font-bold text-sm truncate">{bird.name}</p>
                <p className="text-white/50 text-xs italic truncate">{bird.scientificName}</p>
                <div className="flex items-center gap-2 mt-1">
                  <span
                    className="text-[10px] px-1.5 py-0.5 rounded-full border"
                    style={{
                      color: RARITY_COLORS[bird.rarity],
                      backgroundColor: `${RARITY_COLORS[bird.rarity]}15`,
                      borderColor: `${RARITY_COLORS[bird.rarity]}50`,
                    }}
                  >
                    {bird.rarity}
                  </span>
                  <span className="text-amber-400 text-[11px]">
                    +{getBirdXp(bird)} XP
                  </span>
                </div>
              </div>
              <svg className="w-5 h-5 text-white/20 shrink-0" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="m8.25 4.5 7.5 7.5-7.5 7.5" />
              </svg>
            </button>
          ))
        )}
      </div>

      <BirdDetail bird={selectedBird} onClose={() => setSelectedBird(null)} />
    </div>
  );
}
