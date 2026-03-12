import { Card, getCardImageUrl, RARITY_LABELS } from "../../types/card";

interface Props {
  card: Card;
  count?: number;
  onClose: () => void;
  onAdd?: () => void;
  onRemove?: () => void;
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
      className="fixed inset-0 bg-black/70 flex items-center justify-center z-50 p-4"
      onClick={onClose}
    >
      <div
        className="bg-slate-800 rounded-xl max-w-md w-full p-6 relative"
        onClick={(e) => e.stopPropagation()}
      >
        <button
          onClick={onClose}
          className="absolute top-3 right-3 text-gray-400 hover:text-white text-xl"
        >
          x
        </button>

        <div className="flex gap-4">
          <img
            src={getCardImageUrl(card)}
            alt={card.name}
            className="w-40 rounded-lg"
          />

          <div className="flex-1 text-left">
            <h3 className="text-xl font-bold text-white">{card.name}</h3>
            <p className="text-gray-400 text-sm mt-1">
              {card.set} #{card.number}
            </p>

            <div className="mt-3 space-y-1 text-sm">
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
                    {card.stage === "basic"
                      ? "Basic"
                      : `Stage ${card.stage}`}
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
                <p>
                  <span className="text-gray-400">Evolves from:</span>{" "}
                  <span className="text-white">{card.evolvesFrom}</span>
                </p>
              )}
            </div>

            {count !== undefined && (
              <p className="mt-3 text-blue-400 font-semibold">
                Owned: {count}
              </p>
            )}

            {(onAdd || onRemove) && (
              <div className="flex gap-2 mt-3">
                {onRemove && (
                  <button
                    onClick={onRemove}
                    className="bg-red-600 hover:bg-red-700 text-white px-4 py-1.5 rounded text-sm"
                  >
                    Remove
                  </button>
                )}
                {onAdd && (
                  <button
                    onClick={onAdd}
                    className="bg-green-600 hover:bg-green-700 text-white px-4 py-1.5 rounded text-sm"
                  >
                    Add
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      </div>
    </div>
  );
}
