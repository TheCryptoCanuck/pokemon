"use client";

import { Bird } from "@/types";
import { getRarityColor, getBirdXp } from "@/lib/progression";
import Image from "next/image";

interface BirdDetailModalProps {
  bird: Bird;
  onClose: () => void;
}

export default function BirdDetailModal({
  bird,
  onClose,
}: BirdDetailModalProps) {
  const rarityColor = getRarityColor(bird.rarity);
  const xp = getBirdXp(bird.baseXp, bird.rarity);

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      onClick={onClose}
    >
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
      <div
        className="relative w-full max-w-lg max-h-[90vh] overflow-y-auto rounded-t-3xl sm:rounded-3xl animate-slide-up"
        style={{ backgroundColor: "var(--color-bg-card)" }}
        onClick={(e) => e.stopPropagation()}
      >
        {/* Drag handle */}
        <div className="flex justify-center pt-3 pb-1">
          <div className="w-10 h-1 rounded-full bg-white/20" />
        </div>

        <div className="p-5 pb-8">
          {/* Rarity badge */}
          <div className="flex justify-center mb-2">
            <span
              className="px-3 py-1 rounded-full text-xs font-bold border"
              style={{
                color: rarityColor,
                borderColor: rarityColor,
                backgroundColor: `${rarityColor}15`,
              }}
            >
              {bird.rarity === "unknown"
                ? "NEW DISCOVERY"
                : bird.rarity.toUpperCase()}
            </span>
          </div>

          {/* Name */}
          <h2 className="text-2xl font-bold text-center text-gold mb-0.5">
            {bird.name}
          </h2>
          <p className="text-center text-white/50 italic text-sm mb-4">
            {bird.scientificName}
          </p>

          {/* Image */}
          {bird.imageUrl ? (
            <div className="relative w-full h-56 rounded-2xl overflow-hidden mb-4">
              <Image
                src={bird.imageUrl}
                alt={bird.name}
                fill
                className="object-cover"
                sizes="(max-width: 640px) 100vw, 512px"
                unoptimized
              />
            </div>
          ) : (
            <div
              className="w-full h-40 rounded-2xl flex flex-col items-center justify-center mb-4 border"
              style={{
                backgroundColor: `${rarityColor}10`,
                borderColor: `${rarityColor}40`,
              }}
            >
              <span className="text-6xl mb-1">?</span>
              <span style={{ color: rarityColor }} className="text-sm">
                Photo not yet in database
              </span>
            </div>
          )}

          {/* Details */}
          <div className="space-y-3">
            <DetailRow icon="📖" label="Lore" value={bird.lore} />
            <DetailRow icon="🌍" label="Habitat" value={bird.habitat} />
            <DetailRow
              icon="🌿"
              label="Conservation"
              value={bird.conservationStatus}
            />
            <DetailRow icon="⚡" label="XP Value" value={`+${xp} XP`} />
          </div>

          {/* Audio button */}
          {bird.audioUrl && (
            <button
              className="mt-4 w-full py-3 rounded-xl font-bold text-black flex items-center justify-center gap-2"
              style={{ backgroundColor: "var(--color-gold)" }}
              onClick={() => {
                const audio = new Audio(bird.audioUrl);
                audio.play().catch(() => {});
              }}
            >
              <span>🔊</span>
              Play Bird Call
            </button>
          )}

          {/* Close button */}
          <button
            className="mt-3 w-full py-3 rounded-xl font-medium text-white/60 border border-white/10 hover:border-white/20 transition-colors"
            onClick={onClose}
          >
            Close
          </button>
        </div>
      </div>
    </div>
  );
}

function DetailRow({
  icon,
  label,
  value,
}: {
  icon: string;
  label: string;
  value: string;
}) {
  return (
    <div className="flex gap-2.5">
      <span className="text-base mt-0.5">{icon}</span>
      <div className="flex-1">
        <p className="text-white/50 text-xs">{label}</p>
        <p className="text-white text-sm leading-relaxed">{value}</p>
      </div>
    </div>
  );
}
