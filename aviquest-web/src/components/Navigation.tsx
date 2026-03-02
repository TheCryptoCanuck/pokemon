"use client";

import { TabId } from "@/types";

const tabs: { id: TabId; icon: string; label: string }[] = [
  { id: "map", icon: "🗺️", label: "Map" },
  { id: "identify", icon: "📷", label: "Identify" },
  { id: "aviary", icon: "🖼️", label: "Aviary" },
  { id: "guide", icon: "📖", label: "Guide" },
  { id: "profile", icon: "👤", label: "Me" },
];

interface NavigationProps {
  activeTab: TabId;
  onTabChange: (tab: TabId) => void;
}

export default function Navigation({ activeTab, onTabChange }: NavigationProps) {
  return (
    <nav
      className="fixed bottom-0 left-0 right-0 z-40 border-t border-white/5"
      style={{ backgroundColor: "var(--color-bg-nav)" }}
    >
      <div className="max-w-lg mx-auto flex">
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id)}
              className="flex-1 flex flex-col items-center py-2 pt-2.5 transition-colors duration-200"
              style={{
                color: isActive
                  ? "var(--color-gold)"
                  : "rgba(255,255,255,0.4)",
              }}
            >
              <span className="text-xl leading-none mb-0.5">{tab.icon}</span>
              <span
                className={`text-[10px] leading-none ${isActive ? "font-bold" : "font-normal"}`}
              >
                {tab.label}
              </span>
              {isActive && (
                <div
                  className="w-1 h-1 rounded-full mt-1"
                  style={{ backgroundColor: "var(--color-gold)" }}
                />
              )}
            </button>
          );
        })}
      </div>
    </nav>
  );
}
