'use client';

import { useState, useMemo } from 'react';
import { Bird, TabId } from '../../lib/types';
import { unknownBird } from '../../lib/game';
import { birds } from '../../data/birds';
import { useGame } from '../../context/GameContext';
import BirdCard from '../ui/BirdCard';
import BirdDetail from '../ui/BirdDetail';

interface AviaryTabProps {
  onNavigate: (tab: TabId) => void;
}

export default function AviaryTab({ onNavigate }: AviaryTabProps) {
  const game = useGame();
  const [selectedBird, setSelectedBird] = useState<Bird | null>(null);

  const collectedBirds = useMemo(() => {
    return game.collectedBirds.map(name => {
      return birds.find(b => b.name === name) ?? unknownBird(name);
    });
  }, [game.collectedBirds]);

  if (collectedBirds.length === 0) {
    return (
      <div className="flex flex-col items-center justify-center min-h-[calc(100dvh-64px)] px-6">
        <svg className="w-16 h-16 text-white/15 mb-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
          <path strokeLinecap="round" strokeLinejoin="round" d="M9.813 15.904 9 18.75l-.813-2.846a4.5 4.5 0 0 0-3.09-3.09L2.25 12l2.846-.813a4.5 4.5 0 0 0 3.09-3.09L9 5.25l.813 2.846a4.5 4.5 0 0 0 3.09 3.09L15.75 12l-2.846.813a4.5 4.5 0 0 0-3.09 3.09ZM18.259 8.715 18 9.75l-.259-1.035a3.375 3.375 0 0 0-2.455-2.456L14.25 6l1.036-.259a3.375 3.375 0 0 0 2.455-2.456L18 2.25l.259 1.035a3.375 3.375 0 0 0 2.455 2.456L21.75 6l-1.036.259a3.375 3.375 0 0 0-2.455 2.456ZM16.894 20.567 16.5 21.75l-.394-1.183a2.25 2.25 0 0 0-1.423-1.423L13.5 18.75l1.183-.394a2.25 2.25 0 0 0 1.423-1.423l.394-1.183.394 1.183a2.25 2.25 0 0 0 1.423 1.423l1.183.394-1.183.394a2.25 2.25 0 0 0-1.423 1.423Z" />
        </svg>
        <h2 className="text-xl text-white/50 font-semibold mb-2">Your aviary is empty!</h2>
        <p className="text-white/30 mb-6">Identify birds to add them here.</p>
        <button
          onClick={() => onNavigate('identify')}
          className="bg-amber-400 text-black font-bold px-6 py-3 rounded-xl hover:bg-amber-300 transition-colors"
        >
          Go Identify
        </button>
      </div>
    );
  }

  return (
    <div className="px-4 pt-4 pb-20">
      <div className="flex items-center justify-between mb-4">
        <h2 className="text-xl font-bold text-amber-400">My Aviary</h2>
        <span className="text-white/50 text-sm">{collectedBirds.length} species</span>
      </div>
      <div className="grid grid-cols-2 sm:grid-cols-3 md:grid-cols-4 gap-3">
        {collectedBirds.map((bird, i) => (
          <BirdCard key={`${bird.name}-${i}`} bird={bird} onClick={setSelectedBird} />
        ))}
      </div>
      <BirdDetail bird={selectedBird} onClose={() => setSelectedBird(null)} />
    </div>
  );
}
