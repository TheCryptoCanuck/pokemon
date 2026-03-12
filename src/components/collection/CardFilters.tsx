interface Props {
  search: string;
  onSearchChange: (v: string) => void;
  selectedType: string;
  onTypeChange: (v: string) => void;
  selectedSet: string;
  onSetChange: (v: string) => void;
  selectedRarity: string;
  onRarityChange: (v: string) => void;
  showOwned: "all" | "owned" | "missing";
  onShowOwnedChange: (v: "all" | "owned" | "missing") => void;
  sets: string[];
  types: string[];
}

export default function CardFilters({
  search,
  onSearchChange,
  selectedType,
  onTypeChange,
  selectedSet,
  onSetChange,
  selectedRarity,
  onRarityChange,
  showOwned,
  onShowOwnedChange,
  sets,
  types,
}: Props) {
  const selectClass =
    "bg-slate-700 text-white border border-slate-600 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500";

  return (
    <div className="flex flex-wrap gap-3 items-center">
      <input
        type="text"
        placeholder="Search cards..."
        value={search}
        onChange={(e) => onSearchChange(e.target.value)}
        className="bg-slate-700 text-white border border-slate-600 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500 w-48"
      />

      <select
        value={selectedType}
        onChange={(e) => onTypeChange(e.target.value)}
        className={selectClass}
      >
        <option value="">All Types</option>
        {types.map((t) => (
          <option key={t} value={t}>
            {t.charAt(0).toUpperCase() + t.slice(1)}
          </option>
        ))}
      </select>

      <select
        value={selectedSet}
        onChange={(e) => onSetChange(e.target.value)}
        className={selectClass}
      >
        <option value="">All Sets</option>
        {sets.map((s) => (
          <option key={s} value={s}>
            {s}
          </option>
        ))}
      </select>

      <select
        value={selectedRarity}
        onChange={(e) => onRarityChange(e.target.value)}
        className={selectClass}
      >
        <option value="">All Rarities</option>
        <option value="C">Common</option>
        <option value="U">Uncommon</option>
        <option value="R">Rare</option>
        <option value="RR">Double Rare</option>
        <option value="AR">Art Rare</option>
        <option value="SR">Super Rare</option>
        <option value="SAR">Special Art Rare</option>
        <option value="IM">Immersive</option>
        <option value="UR">Crown Rare</option>
      </select>

      <div className="flex rounded overflow-hidden border border-slate-600">
        {(["all", "owned", "missing"] as const).map((opt) => (
          <button
            key={opt}
            onClick={() => onShowOwnedChange(opt)}
            className={`px-3 py-2 text-sm capitalize ${
              showOwned === opt
                ? "bg-blue-600 text-white"
                : "bg-slate-700 text-gray-300 hover:bg-slate-600"
            }`}
          >
            {opt}
          </button>
        ))}
      </div>
    </div>
  );
}
