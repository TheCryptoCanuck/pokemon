interface Props {
  totalCards: number;
  pokemonCount: number;
  trainerCount: number;
  energyTypes: string[];
  typeBreakdown: Record<string, number>;
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

export default function DeckAnalysis({
  totalCards,
  pokemonCount,
  trainerCount,
  energyTypes,
  typeBreakdown,
}: Props) {
  if (totalCards === 0) {
    return (
      <div className="text-gray-500 text-sm text-center py-4">
        Add cards to see analysis
      </div>
    );
  }

  return (
    <div className="space-y-4">
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
