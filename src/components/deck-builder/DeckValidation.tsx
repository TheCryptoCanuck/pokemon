import { ValidationError } from "../../utils/deck-rules";

interface Props {
  errors: ValidationError[];
  totalCards: number;
}

export default function DeckValidation({ errors, totalCards }: Props) {
  const isValid = errors.length === 0 && totalCards === 20;

  return (
    <div
      className={`rounded-lg p-3 ${
        isValid
          ? "bg-green-900/30 border border-green-700"
          : "bg-slate-700/50 border border-slate-600"
      }`}
    >
      <div className="flex items-center gap-2 mb-1">
        <span className={isValid ? "text-green-400" : "text-yellow-400"}>
          {isValid ? "Valid Deck" : `${totalCards}/20 cards`}
        </span>
      </div>

      {errors.length > 0 && (
        <ul className="space-y-1 mt-2">
          {errors.map((err, i) => (
            <li key={i} className="text-red-400 text-xs flex items-start gap-1">
              <span className="mt-0.5">!</span>
              <span>{err.message}</span>
            </li>
          ))}
        </ul>
      )}

      {totalCards < 20 && errors.length === 0 && (
        <p className="text-gray-400 text-xs mt-1">
          Need {20 - totalCards} more card{20 - totalCards !== 1 ? "s" : ""}
        </p>
      )}
    </div>
  );
}
