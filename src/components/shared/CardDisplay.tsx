import { Card, getCardImageUrl, RARITY_LABELS } from "../../types/card";

interface Props {
  card: Card;
  count?: number;
  owned?: boolean;
  onClick?: () => void;
  onAdd?: () => void;
  onRemove?: () => void;
  compact?: boolean;
}

const ELEMENT_COLORS: Record<string, string> = {
  grass: "bg-green-600",
  fire: "bg-red-600",
  water: "bg-blue-600",
  lightning: "bg-yellow-500",
  psychic: "bg-purple-600",
  fighting: "bg-orange-700",
  darkness: "bg-gray-800",
  metal: "bg-gray-500",
  colorless: "bg-gray-400",
};

export default function CardDisplay({
  card,
  count,
  owned,
  onClick,
  onAdd,
  onRemove,
  compact,
}: Props) {
  const imgUrl = getCardImageUrl(card);
  const elColor = ELEMENT_COLORS[card.element || "colorless"] || "bg-gray-400";

  return (
    <div
      className={`relative group rounded-lg overflow-hidden transition-all ${
        owned === false ? "opacity-40 grayscale" : ""
      } ${onClick ? "cursor-pointer hover:scale-105 hover:shadow-lg hover:shadow-blue-500/20" : ""} ${
        compact ? "w-28" : "w-36"
      }`}
      onClick={onClick}
    >
      <img
        src={imgUrl}
        alt={card.name}
        className="w-full rounded-lg"
        loading="lazy"
        onError={(e) => {
          (e.target as HTMLImageElement).src =
            "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='280' fill='%231e293b'%3E%3Crect width='200' height='280' rx='8'/%3E%3Ctext x='100' y='140' text-anchor='middle' fill='%2394a3b8' font-size='14'%3ENo Image%3C/text%3E%3C/svg%3E";
        }}
      />

      {count !== undefined && count > 0 && (
        <span className="absolute top-1 right-1 bg-blue-600 text-white text-xs font-bold rounded-full w-6 h-6 flex items-center justify-center shadow">
          {count}
        </span>
      )}

      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-black/90 via-black/60 to-transparent p-2 pt-6 opacity-0 group-hover:opacity-100 transition-opacity">
        <p className="text-white text-xs font-semibold truncate">{card.name}</p>
        <div className="flex items-center gap-1 mt-0.5">
          <span
            className={`${elColor} text-white text-[10px] px-1.5 py-0.5 rounded`}
          >
            {card.element || "colorless"}
          </span>
          <span className="text-gray-300 text-[10px]">
            {RARITY_LABELS[card.rarity] || card.rarity}
          </span>
        </div>

        {(onAdd || onRemove) && (
          <div className="flex gap-1 mt-1">
            {onRemove && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onRemove();
                }}
                className="bg-red-600 hover:bg-red-700 text-white text-xs px-2 py-0.5 rounded"
              >
                -
              </button>
            )}
            {onAdd && (
              <button
                onClick={(e) => {
                  e.stopPropagation();
                  onAdd();
                }}
                className="bg-green-600 hover:bg-green-700 text-white text-xs px-2 py-0.5 rounded"
              >
                +
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
