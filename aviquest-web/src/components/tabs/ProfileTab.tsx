'use client';

import { useGame } from '../../context/GameContext';
import { levelTitle, xpForNextLevel, ACHIEVEMENTS } from '../../lib/game';
import XpBar from '../ui/XpBar';
import AchievementBadge from '../ui/AchievementBadge';

export default function ProfileTab() {
  const game = useGame();
  const nextLevelXp = xpForNextLevel(game.level);

  return (
    <div className="px-6 pt-6 pb-20 max-w-lg mx-auto">
      {/* Avatar */}
      <div className="flex flex-col items-center mb-5 animate-fade-in">
        <div className="w-24 h-24 rounded-full bg-gradient-to-br from-amber-400 to-green-500 flex items-center justify-center shadow-[0_0_20px_rgba(251,191,36,0.4)] mb-4">
          <span className="text-5xl">&#x1F985;</span>
        </div>
        <h2 className="text-[28px] font-bold text-amber-400">
          {levelTitle(game.level)}
        </h2>
        <p className="text-white/50">Level {game.level}</p>
      </div>

      {/* XP Bar */}
      <div className="mb-5 animate-fade-in animation-delay-100">
        <XpBar current={game.xp} max={nextLevelXp} />
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-3 mb-6 animate-fade-in animation-delay-200">
        <StatCard emoji="&#x1F525;" value={game.streak} label="Day Streak" />
        <StatCard emoji="&#x1F426;" value={game.collectedBirds.length} label="Species" />
        <StatCard emoji="&#x1F3C6;" value={game.unlockedAchievements.length} label="Badges" />
      </div>

      {/* Achievements */}
      <div className="animate-fade-in animation-delay-250">
        <h3 className="text-xl font-bold text-white mb-3">Achievements</h3>
        <div className="flex flex-wrap gap-2 mb-6">
          {ACHIEVEMENTS.map(a => (
            <AchievementBadge
              key={a.key}
              achievement={a}
              unlocked={game.unlockedAchievements.includes(a.key)}
            />
          ))}
        </div>
      </div>

      {/* Eco Impact */}
      <div className="animate-fade-in animation-delay-300 bg-green-500/10 border border-green-500/30 rounded-2xl p-4 flex items-start gap-3">
        <span className="text-3xl shrink-0">&#x1F30D;</span>
        <div>
          <p className="text-green-400 font-bold text-sm">Eco Impact</p>
          <p className="text-white/50 text-xs">
            Your sightings help scientists track bird populations worldwide.
          </p>
        </div>
      </div>
    </div>
  );
}

function StatCard({ emoji, value, label }: { emoji: string; value: number; label: string }) {
  return (
    <div className="bg-[#1A2F1F] rounded-2xl py-4 text-center">
      <span className="text-[28px]" dangerouslySetInnerHTML={{ __html: emoji }} />
      <p className="text-[22px] font-bold text-amber-400">{value}</p>
      <p className="text-white/50 text-xs">{label}</p>
    </div>
  );
}
