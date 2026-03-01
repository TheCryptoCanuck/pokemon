interface XpBarProps {
  current: number;
  max: number;
}

export default function XpBar({ current, max }: XpBarProps) {
  const progress = Math.min((current / max) * 100, 100);

  return (
    <div className="w-full">
      <div className="flex justify-between mb-1.5">
        <span className="text-sm text-white/70">XP Progress</span>
        <span className="text-sm text-amber-400 font-medium">
          {current} / {max}
        </span>
      </div>
      <div className="w-full h-3 bg-[#1A2F1F] rounded-full overflow-hidden">
        <div
          className="h-full bg-amber-400 rounded-full transition-all duration-700 ease-out"
          style={{ width: `${progress}%` }}
          role="progressbar"
          aria-valuenow={current}
          aria-valuemin={0}
          aria-valuemax={max}
        />
      </div>
    </div>
  );
}
