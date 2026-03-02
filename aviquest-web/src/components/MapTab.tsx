"use client";

export default function MapTab() {
  return (
    <div className="flex flex-col items-center justify-center h-full px-6">
      <span className="text-7xl mb-4 opacity-20 animate-scale-in">🗺️</span>
      <h2 className="text-2xl font-bold text-gold mb-2 animate-fade-in stagger-1">
        Interactive Map
      </h2>
      <p className="text-white/40 text-center mb-6 animate-fade-in stagger-2">
        Hotspot mapping & community sightings
        <br />
        coming soon!
      </p>
      <div
        className="px-5 py-3 rounded-2xl flex items-center gap-2 animate-fade-in stagger-3"
        style={{ backgroundColor: "var(--color-bg-card)" }}
      >
        <span>👥</span>
        <span className="text-white/60 text-sm">
          1,247 sightings logged today 🌍
        </span>
      </div>
    </div>
  );
}
