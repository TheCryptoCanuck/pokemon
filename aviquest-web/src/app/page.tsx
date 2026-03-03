"use client";

import { useState } from "react";
import { TabId } from "@/types";
import { useGameState } from "@/hooks/useGameState";
import Navigation from "@/components/Navigation";
import MapTab from "@/components/MapTab";
import IdentifyTab from "@/components/IdentifyTab";
import AviaryTab from "@/components/AviaryTab";
import FieldGuideTab from "@/components/FieldGuideTab";
import ProfileTab from "@/components/ProfileTab";
import Notification from "@/components/Notification";

export default function Home() {
  const [activeTab, setActiveTab] = useState<TabId>("identify");
  const game = useGameState();

  if (!game.mounted) {
    return (
      <div className="h-dvh flex items-center justify-center">
        <div className="w-12 h-12 rounded-full border-4 border-gold/30 border-t-gold animate-spin" />
      </div>
    );
  }

  return (
    <div className="h-dvh flex flex-col max-w-lg mx-auto relative">
      {/* Notification */}
      {game.notification && (
        <Notification
          type={game.notification.type}
          message={game.notification.message}
          detail={game.notification.detail}
          onDismiss={game.dismissNotification}
        />
      )}

      {/* Tab content */}
      <main className="flex-1 overflow-hidden pb-14">
        {activeTab === "map" && <MapTab />}
        {activeTab === "identify" && (
          <IdentifyTab onAddBird={game.addBird} />
        )}
        {activeTab === "aviary" && (
          <AviaryTab
            aviary={game.aviary}
            onNavigateToIdentify={() => setActiveTab("identify")}
          />
        )}
        {activeTab === "guide" && <FieldGuideTab />}
        {activeTab === "profile" && (
          <ProfileTab
            level={game.level}
            xp={game.xp}
            streak={game.streak}
            collectedCount={game.aviary.length}
            unlockedAchievements={game.unlockedAchievements}
          />
        )}
      </main>

      {/* Bottom navigation */}
      <Navigation activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}
