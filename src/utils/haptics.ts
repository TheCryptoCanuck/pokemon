// Tiny haptic helper for mobile feedback. On native Android uses
// Capacitor Haptics; on web falls back to navigator.vibrate(8).
// Restricted to deck mutations and pin/unpin — not filter taps or
// modal opens.

import { Capacitor } from "@capacitor/core";
import { Haptics, ImpactStyle } from "@capacitor/haptics";

let reduceMotion: boolean | null = null;

function prefersReducedMotion(): boolean {
  if (reduceMotion !== null) return reduceMotion;
  if (typeof window === "undefined" || !window.matchMedia) return false;
  reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  return reduceMotion;
}

export function tap(): void {
  if (prefersReducedMotion()) return;
  if (Capacitor.isNativePlatform()) {
    Haptics.impact({ style: ImpactStyle.Light });
    return;
  }
  if (typeof navigator === "undefined" || !navigator.vibrate) return;
  navigator.vibrate(8);
}
