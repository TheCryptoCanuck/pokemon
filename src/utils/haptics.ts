// Tiny haptic helper for mobile feedback. Calls navigator.vibrate when
// available, no-ops otherwise. Restricted to deck mutations and
// pin/unpin (not every click) so the device doesn't buzz on filter
// taps or modal opens.

let reduceMotion: boolean | null = null;

function prefersReducedMotion(): boolean {
  if (reduceMotion !== null) return reduceMotion;
  if (typeof window === "undefined" || !window.matchMedia) return false;
  reduceMotion = window.matchMedia("(prefers-reduced-motion: reduce)").matches;
  return reduceMotion;
}

// 8ms feels like a satisfying tick on Android Chrome — not a buzz.
// Anything ≥20ms reads as alarm. Desktop browsers ignore this entirely.
export function tap(): void {
  if (prefersReducedMotion()) return;
  if (typeof navigator === "undefined" || !navigator.vibrate) return;
  navigator.vibrate(8);
}
