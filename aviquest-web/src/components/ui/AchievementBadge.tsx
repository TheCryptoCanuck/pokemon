import { Achievement } from '../../lib/types';

interface AchievementBadgeProps {
  achievement: Achievement;
  unlocked: boolean;
}

export default function AchievementBadge({ achievement, unlocked }: AchievementBadgeProps) {
  return (
    <div
      className={`w-[60px] h-[60px] rounded-2xl border flex items-center justify-center transition-all ${
        unlocked
          ? 'bg-amber-400/15 border-amber-400'
          : 'bg-[#1A2F1F] border-white/10'
      }`}
      title={unlocked ? `${achievement.title}: ${achievement.description}` : '???'}
    >
      <span className={`text-[28px] ${unlocked ? '' : 'opacity-25 grayscale'}`}>
        {unlocked ? achievement.emoji : '🔒'}
      </span>
    </div>
  );
}
