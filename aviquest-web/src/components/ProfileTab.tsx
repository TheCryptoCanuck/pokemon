"use client";

import { xpForNextLevel, levelTitle, ACHIEVEMENTS } from "@/lib/progression";

interface ProfileTabProps {
  level: number;
  xp: number;
  streak: number;
  collectedCount: number;
  unlockedAchievements: string[];
}

export default function ProfileTab({
  level,
  xp,
  streak,
  collectedCount,
  unlockedAchievements,
}: ProfileTabProps) {
  const nextLevelXp = xpForNextLevel(level);
  const progress = Math.min(xp / nextLevelXp, 1);
  const title = levelTitle(level);

  return (
    <div className="h-full overflow-y-auto px-6 py-8">
      {/* Avatar */}
      <div className="flex justify-center mb-4 animate-scale-in">
        <div
          className="w-24 h-24 rounded-full flex items-center justify-center animate-pulse-glow"
          style={{
            background:
              "linear-gradient(135deg, var(--color-gold), var(--color-forest))",
          }}
        >
          <span className="text-5xl">🦅</span>
        </div>
      </div>

      {/* Level title */}
      <h2 className="text-2xl font-bold text-center text-gold mb-0.5 animate-fade-in stagger-1">
        {title}
      </h2>
      <p className="text-center text-white/40 mb-5 animate-fade-in stagger-1">
        Level {level}
      </p>

      {/* XP bar */}
      <div className="mb-5 animate-fade-in stagger-2">
        <div className="flex justify-between text-sm mb-1.5">
          <span className="text-white/60">XP Progress</span>
          <span className="text-gold">
            {xp} / {nextLevelXp}
          </span>
        </div>
        <div
          className="h-3 rounded-full overflow-hidden"
          style={{ backgroundColor: "var(--color-bg-card)" }}
        >
          <div
            className="h-full rounded-full transition-all duration-500 ease-out"
            style={{
              width: `${progress * 100}%`,
              backgroundColor: "var(--color-gold)",
            }}
          />
        </div>
      </div>

      {/* Stats row */}
      <div className="grid grid-cols-3 gap-3 mb-6 animate-fade-in stagger-3">
        <StatCard emoji="🔥" value={String(streak)} label="Day Streak" />
        <StatCard emoji="🐦" value={String(collectedCount)} label="Species" />
        <StatCard
          emoji="🏆"
          value={String(unlockedAchievements.length)}
          label="Badges"
        />
      </div>

      {/* Achievements */}
      <h3 className="text-lg font-bold mb-3 animate-fade-in stagger-4">
        Achievements
      </h3>
      <div className="flex flex-wrap gap-2 mb-6 animate-fade-in stagger-5">
        {ACHIEVEMENTS.map((a) => {
          const unlocked = unlockedAchievements.includes(a.id);
          return (
            <div
              key={a.id}
              className="w-14 h-14 rounded-2xl flex items-center justify-center border transition-all duration-300 relative group"
              style={{
                backgroundColor: unlocked
                  ? "rgba(245, 158, 11, 0.15)"
                  : "var(--color-bg-card)",
                borderColor: unlocked
                  ? "var(--color-gold)"
                  : "rgba(255,255,255,0.08)",
              }}
              title={unlocked ? `${a.title}: ${a.description}` : "???"}
            >
              <span
                className="text-2xl"
                style={{
                  opacity: unlocked ? 1 : 0.2,
                  filter: unlocked ? "none" : "grayscale(1)",
                }}
              >
                {unlocked ? a.emoji : "🔒"}
              </span>
              {/* Tooltip */}
              <div className="absolute bottom-full left-1/2 -translate-x-1/2 mb-2 px-2.5 py-1.5 rounded-lg bg-black/90 text-xs whitespace-nowrap opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none z-10">
                <p className="font-bold text-gold">{unlocked ? a.title : "???"}</p>
                <p className="text-white/60">
                  {unlocked ? a.description : "Keep exploring!"}
                </p>
              </div>
            </div>
          );
        })}
      </div>

      {/* Eco impact */}
      <div
        className="p-4 rounded-2xl border flex items-center gap-3 animate-fade-in stagger-6"
        style={{
          backgroundColor: "rgba(76, 175, 80, 0.1)",
          borderColor: "rgba(76, 175, 80, 0.3)",
        }}
      >
        <span className="text-3xl">🌍</span>
        <div>
          <p className="font-bold text-forest text-sm">Eco Impact</p>
          <p className="text-white/40 text-xs">
            Your sightings help scientists track bird populations worldwide.
          </p>
        </div>
      </div>
    </div>
  );
}

function StatCard({
  emoji,
  value,
  label,
}: {
  emoji: string;
  value: string;
  label: string;
}) {
  return (
    <div
      className="py-4 rounded-2xl flex flex-col items-center"
      style={{ backgroundColor: "var(--color-bg-card)" }}
    >
      <span className="text-2xl mb-1">{emoji}</span>
      <span className="text-xl font-bold text-gold">{value}</span>
      <span className="text-white/40 text-[11px]">{label}</span>
    </div>
  );
}
