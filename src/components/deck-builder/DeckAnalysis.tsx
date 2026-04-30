import { useEffect, useRef, useState } from "react";
import type { DeckScore, ScoreStatus } from "../../utils/deck-scoring";

interface Props {
  totalCards: number;
  pokemonCount: number;
  trainerCount: number;
  energyTypes: string[];
  typeBreakdown: Record<string, number>;
  score?: DeckScore;
}

// Smoothly tween from the previous score to the new target over ~600ms.
// Single in-flight RAF; cancel on each new target so the latest value
// always wins (handles rapid +/- spam without runaway animations).
function useDeckScoreTween(target: number): number {
  const [display, setDisplay] = useState(target);
  const rafRef = useRef<number | null>(null);
  const fromRef = useRef(target);

  useEffect(() => {
    // setState-in-effect is intentional here: we're driving an
    // animation off requestAnimationFrame, which is exactly the
    // "synchronizing state with an external system" use case the
    // React docs carve out.
    /* eslint-disable react-hooks/set-state-in-effect */
    if (Math.abs(target - fromRef.current) < 1) {
      setDisplay(target);
      fromRef.current = target;
      return;
    }
    const start = performance.now();
    const from = fromRef.current;
    const duration = 600;
    const ease = (t: number) => 1 - Math.pow(1 - t, 3); // easeOutCubic
    const step = (now: number) => {
      const t = Math.min(1, (now - start) / duration);
      const v = from + (target - from) * ease(t);
      setDisplay(Math.round(v));
      if (t < 1) {
        rafRef.current = requestAnimationFrame(step);
      } else {
        fromRef.current = target;
        rafRef.current = null;
      }
    };
    if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    rafRef.current = requestAnimationFrame(step);
    return () => {
      if (rafRef.current !== null) cancelAnimationFrame(rafRef.current);
    };
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [target]);

  return display;
}

const TYPE_COLORS: Record<string, string> = {
  grass: "#22c55e",
  fire: "#ef4444",
  water: "#3b82f6",
  lightning: "#eab308",
  psychic: "#a855f7",
  fighting: "#c2410c",
  darkness: "#374151",
  metal: "#6b7280",
  colorless: "#9ca3af",
};

const STATUS_COLOR: Record<ScoreStatus, string> = {
  good: "#10b981", // emerald-500
  warn: "#f59e0b", // amber-500
  bad: "#f43f5e", // rose-500
};

const GRADE_PILL: Record<DeckScore["grade"], string> = {
  S: "bg-emerald-500 text-white",
  A: "bg-emerald-600 text-white",
  B: "bg-amber-500 text-white",
  C: "bg-amber-600 text-white",
  D: "bg-rose-600 text-white",
};

function ringColor(total: number): string {
  if (total >= 75) return STATUS_COLOR.good;
  if (total >= 45) return STATUS_COLOR.warn;
  return STATUS_COLOR.bad;
}

export default function DeckAnalysis({
  totalCards,
  pokemonCount,
  trainerCount,
  energyTypes,
  typeBreakdown,
  score,
}: Props) {
  // Always call hooks at top level — early return below.
  const displayedTotal = useDeckScoreTween(score?.total ?? 0);
  // Re-key the grade pill when the grade letter changes so the
  // animate-pop animation re-runs. setState-in-effect here is the
  // canonical "remount-on-change" pattern.
  const prevGradeRef = useRef<string | undefined>(score?.grade);
  const [popKey, setPopKey] = useState(0);
  useEffect(() => {
    /* eslint-disable react-hooks/set-state-in-effect */
    if (score && prevGradeRef.current && prevGradeRef.current !== score.grade) {
      setPopKey((k) => k + 1);
    }
    prevGradeRef.current = score?.grade;
    /* eslint-enable react-hooks/set-state-in-effect */
  }, [score?.grade, score]);

  if (totalCards === 0) {
    return (
      <div className="text-center py-6 animate-slide-up-fade">
        <div className="text-4xl mb-2" aria-hidden>🃏</div>
        <p className="text-sm text-gray-300">Empty deck</p>
        <p className="text-xs text-gray-500 mt-1">
          Pick cards from the browser to see your score and breakdown.
        </p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      {/* Deck score */}
      {score && score.breakdown.length > 0 && (
        <div className="bg-slate-800 border border-slate-700 rounded p-3">
          <div className="flex items-center gap-3">
            <div
              className="relative w-16 h-16 rounded-full flex items-center justify-center"
              style={{
                background: `conic-gradient(${ringColor(displayedTotal)} ${displayedTotal * 3.6}deg, #334155 0)`,
              }}
              role="img"
              aria-label={`Deck score ${score.total} out of 100, grade ${score.grade}`}
            >
              <div className="absolute inset-1 rounded-full bg-slate-800 flex items-center justify-center">
                <span className="text-xl font-bold text-white tabular-nums">
                  {displayedTotal}
                </span>
              </div>
            </div>
            <div className="flex-1">
              <div className="flex items-center gap-2">
                <h4 className="text-sm font-semibold text-white">Deck Score</h4>
                <span
                  key={popKey}
                  className={`text-xs font-bold px-2 py-0.5 rounded animate-pop ${GRADE_PILL[score.grade]} ${
                    score.grade === "S"
                      ? "shadow-lg shadow-emerald-500/40"
                      : ""
                  }`}
                >
                  {score.grade}
                </span>
              </div>
              <p className="text-xs text-gray-400 mt-0.5">
                Tap to expand the breakdown
              </p>
            </div>
          </div>

          <details className="mt-3 group">
            <summary className="cursor-pointer text-xs text-blue-400 hover:text-blue-300 select-none list-none">
              <span className="group-open:hidden">▸ Show breakdown</span>
              <span className="hidden group-open:inline">▾ Hide breakdown</span>
            </summary>
            <ul className="mt-2 space-y-2">
              {score.breakdown.map((h) => (
                <li key={h.id} className="text-xs">
                  <div className="flex items-center gap-2">
                    <span
                      className="inline-block w-2 h-2 rounded-full shrink-0"
                      style={{ backgroundColor: STATUS_COLOR[h.status] }}
                    />
                    <span className="text-gray-200 font-medium flex-1 truncate">
                      {h.label}
                    </span>
                    <span className="text-gray-400 tabular-nums">
                      {h.score}/100
                    </span>
                  </div>
                  <p className="text-gray-400 ml-4 mt-0.5">{h.message}</p>
                  {h.suggestion && (
                    <p className="text-amber-300 ml-4 mt-0.5 italic">
                      {h.suggestion}
                    </p>
                  )}
                </li>
              ))}
            </ul>
            <p className="text-[10px] text-gray-500 mt-3">
              Synergy data reviewed {score.lastReviewed}
            </p>
          </details>
        </div>
      )}

      {/* Card type split */}
      <div>
        <h4 className="text-xs text-gray-400 mb-2 uppercase tracking-wider">
          Composition
        </h4>
        <div className="flex gap-3">
          <div className="flex-1 bg-slate-700 rounded p-2 text-center">
            <p className="text-lg font-bold text-blue-400">{pokemonCount}</p>
            <p className="text-xs text-gray-400">Pokemon</p>
          </div>
          <div className="flex-1 bg-slate-700 rounded p-2 text-center">
            <p className="text-lg font-bold text-purple-400">{trainerCount}</p>
            <p className="text-xs text-gray-400">Trainers</p>
          </div>
        </div>
      </div>

      {/* Energy types */}
      <div>
        <h4 className="text-xs text-gray-400 mb-2 uppercase tracking-wider">
          Energy Types ({energyTypes.length}/3)
        </h4>
        <div className="flex flex-wrap gap-2">
          {energyTypes.map((type) => (
            <span
              key={type}
              className="px-2 py-1 rounded text-xs text-white font-semibold capitalize"
              style={{ backgroundColor: TYPE_COLORS[type] || "#6b7280" }}
            >
              {type}
            </span>
          ))}
          {energyTypes.length === 0 && (
            <span className="text-gray-500 text-xs">None yet</span>
          )}
        </div>
      </div>

      {/* Type distribution bar */}
      <div>
        <h4 className="text-xs text-gray-400 mb-2 uppercase tracking-wider">
          Type Distribution
        </h4>
        <div className="space-y-1">
          {Object.entries(typeBreakdown)
            .sort(([, a], [, b]) => b - a)
            .map(([type, count]) => (
              <div key={type} className="flex items-center gap-2">
                <span className="text-xs text-gray-300 capitalize w-16 text-right">
                  {type}
                </span>
                <div className="flex-1 bg-slate-700 rounded-full h-2">
                  <div
                    className="h-2 rounded-full transition-all"
                    style={{
                      width: `${(count / totalCards) * 100}%`,
                      backgroundColor: TYPE_COLORS[type] || "#6b7280",
                    }}
                  />
                </div>
                <span className="text-xs text-gray-400 w-6">{count}</span>
              </div>
            ))}
        </div>
      </div>
    </div>
  );
}
