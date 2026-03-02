"use client";

import { ACHIEVEMENTS } from "@/lib/progression";
import { levelTitle } from "@/lib/progression";

interface NotificationProps {
  type: "levelUp" | "achievement";
  message: string;
  detail?: string;
  onDismiss: () => void;
}

export default function Notification({
  type,
  message,
  detail,
  onDismiss,
}: NotificationProps) {
  const achievement = detail
    ? ACHIEVEMENTS.find((a) => a.id === detail)
    : null;

  return (
    <div
      className="fixed top-4 left-1/2 -translate-x-1/2 z-50 animate-slide-down cursor-pointer"
      onClick={onDismiss}
    >
      <div
        className="px-5 py-3 rounded-2xl flex items-center gap-3 shadow-xl border"
        style={{
          backgroundColor:
            type === "levelUp" ? "var(--color-gold)" : "var(--color-bg-card)",
          borderColor:
            type === "levelUp"
              ? "transparent"
              : "var(--color-gold)",
        }}
      >
        {type === "levelUp" ? (
          <>
            <span className="text-lg">🎉</span>
            <div>
              <p className="font-bold text-black text-sm">LEVEL UP!</p>
              <p className="text-black/70 text-xs">{message}</p>
            </div>
          </>
        ) : (
          <>
            <span className="text-2xl">{achievement?.emoji ?? "🏆"}</span>
            <div>
              <p className="font-bold text-gold text-sm">{message}</p>
              <p className="text-white/60 text-xs">
                {achievement?.title ?? detail}
              </p>
            </div>
          </>
        )}
      </div>

      <style jsx>{`
        @keyframes slide-down {
          from {
            opacity: 0;
            transform: translate(-50%, -100%);
          }
          to {
            opacity: 1;
            transform: translate(-50%, 0);
          }
        }
        .animate-slide-down {
          animation: slide-down 0.3s ease-out forwards;
        }
      `}</style>
    </div>
  );
}
