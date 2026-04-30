import { Card, getCardImageUrl, RARITY_LABELS } from "../../types/card";

interface Props {
  card: Card;
  count?: number;
  onClose: () => void;
  onAdd?: () => void;
  onRemove?: () => void;
}

// TCGP energy types map to a colour for the cost pips. These match the
// ELEMENT_COLORS palette used elsewhere; lowercased keys for the
// upstream `attacks[].cost` strings (which are capitalised).
const COST_COLOR: Record<string, string> = {
  Grass: "bg-green-500",
  Fire: "bg-red-500",
  Water: "bg-blue-500",
  Lightning: "bg-yellow-400",
  Psychic: "bg-purple-500",
  Fighting: "bg-orange-700",
  Darkness: "bg-gray-800",
  Metal: "bg-gray-500",
  Dragon: "bg-amber-700",
  Colorless: "bg-gray-400",
};

function CostPips({ cost }: { cost: string[] }) {
  if (cost.length === 0) {
    return <span className="text-gray-500 text-xs italic">free</span>;
  }
  return (
    <span className="flex gap-0.5">
      {cost.map((c, i) => (
        <span
          key={i}
          title={c}
          className={`${COST_COLOR[c] ?? "bg-gray-400"} w-3 h-3 rounded-full ring-1 ring-slate-900`}
        />
      ))}
    </span>
  );
}

export default function CardModal({
  card,
  count,
  onClose,
  onAdd,
  onRemove,
}: Props) {
  return (
    <div
      className="fixed inset-0 bg-black/80 backdrop-blur-sm flex items-center justify-center z-50 p-4 animate-slide-up-fade"
      onClick={onClose}
    >
      <div
        className="bg-slate-800 rounded-xl max-w-lg w-full max-h-[90vh] overflow-y-auto p-6 relative"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          aria-label="Close card details"
          className="absolute top-2 right-2 text-gray-400 hover:text-white hover:bg-slate-700 text-xl w-8 h-8 rounded flex items-center justify-center focus-visible:outline-2 focus-visible:outline-blue-400"
        >
          ×
        </button>

        <div className="flex flex-col sm:flex-row gap-4">
          <img
            src={getCardImageUrl(card)}
            alt={card.name}
            className="w-40 rounded-lg shrink-0 self-center sm:self-start"
          />

          <div className="flex-1 text-left min-w-0">
            <h3 className="text-xl font-bold text-white">{card.name}</h3>
            <p className="text-gray-400 text-sm mt-1">
              {card.set} #{card.number}
            </p>

            <div className="mt-3 grid grid-cols-2 gap-x-4 gap-y-1 text-sm">
              {card.element && (
                <p>
                  <span className="text-gray-400">Type:</span>{" "}
                  <span className="text-white capitalize">{card.element}</span>
                </p>
              )}
              {card.type && (
                <p>
                  <span className="text-gray-400">Category:</span>{" "}
                  <span className="text-white capitalize">{card.type}</span>
                </p>
              )}
              {card.health && (
                <p>
                  <span className="text-gray-400">HP:</span>{" "}
                  <span className="text-white">{card.health}</span>
                </p>
              )}
              {card.stage !== undefined && (
                <p>
                  <span className="text-gray-400">Stage:</span>{" "}
                  <span className="text-white capitalize">
                    {card.stage === "basic" ? "Basic" : `Stage ${card.stage}`}
                  </span>
                </p>
              )}
              {card.weakness && (
                <p>
                  <span className="text-gray-400">Weakness:</span>{" "}
                  <span className="text-white">{card.weakness}</span>
                </p>
              )}
              {card.retreatCost !== undefined && (
                <p>
                  <span className="text-gray-400">Retreat:</span>{" "}
                  <span className="text-white">{card.retreatCost}</span>
                </p>
              )}
              <p>
                <span className="text-gray-400">Rarity:</span>{" "}
                <span className="text-white">
                  {RARITY_LABELS[card.rarity] || card.rarity}
                </span>
              </p>
              {card.evolvesFrom && (
                <p className="col-span-2">
                  <span className="text-gray-400">Evolves from:</span>{" "}
                  <span className="text-white">{card.evolvesFrom}</span>
                </p>
              )}
            </div>

            {count !== undefined && count > 0 && (
              <p className="mt-3 text-blue-400 font-semibold">
                Owned: {count}
              </p>
            )}

            {(onAdd || onRemove) && (
              <div className="flex gap-2 mt-3">
                {onRemove && (
                  <button
                    onClick={onRemove}
                    className="bg-red-600 hover:bg-red-700 text-white px-4 py-1.5 rounded text-sm active:scale-95 transition-transform"
                  >
                    Remove
                  </button>
                )}
                {onAdd && (
                  <button
                    onClick={onAdd}
                    className="bg-green-600 hover:bg-green-700 text-white px-4 py-1.5 rounded text-sm active:scale-95 transition-transform"
                  >
                    Add
                  </button>
                )}
              </div>
            )}
          </div>
        </div>

        {/* Abilities (rare — Pokémon-only). Rich data from hugoburguete. */}
        {card.abilities && card.abilities.length > 0 && (
          <div className="mt-5 pt-4 border-t border-slate-700 space-y-3">
            {card.abilities.map((a, i) => (
              <div key={i}>
                <div className="flex items-center gap-2">
                  <span className="text-xs font-bold text-purple-300 bg-purple-900/40 px-2 py-0.5 rounded">
                    Ability
                  </span>
                  <h4 className="text-white font-semibold">{a.name}</h4>
                </div>
                <p className="text-sm text-gray-300 mt-1 leading-snug">
                  {a.effect}
                </p>
              </div>
            ))}
          </div>
        )}

        {/* Attacks (Pokémon-only). Each row: cost pips + name + damage,
            plus effect text underneath when present. */}
        {card.attacks && card.attacks.length > 0 && (
          <div className="mt-5 pt-4 border-t border-slate-700 space-y-3">
            {card.attacks.map((atk, i) => (
              <div key={i}>
                <div className="flex items-center gap-3">
                  <CostPips cost={atk.cost} />
                  <h4 className="text-white font-semibold flex-1 truncate">
                    {atk.name}
                  </h4>
                  {atk.damage && (
                    <span className="text-amber-300 font-bold text-base tabular-nums">
                      {atk.damage}
                    </span>
                  )}
                </div>
                {atk.effect && (
                  <p className="text-sm text-gray-300 mt-1 leading-snug">
                    {atk.effect}
                  </p>
                )}
              </div>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
