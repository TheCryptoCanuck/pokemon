'use client';

import { useState } from 'react';
import { TabId } from '../../lib/types';
import BottomNav from './BottomNav';
import IdentifyTab from '../tabs/IdentifyTab';
import AviaryTab from '../tabs/AviaryTab';
import FieldGuideTab from '../tabs/FieldGuideTab';
import MapTab from '../tabs/MapTab';
import ProfileTab from '../tabs/ProfileTab';

export default function AppShell() {
  const [activeTab, setActiveTab] = useState<TabId>('identify');

  return (
    <div className="min-h-dvh bg-[#0A1F0F] text-white flex flex-col">
      <main className="flex-1 pb-16 overflow-y-auto">
        <div className={activeTab === 'map' ? '' : 'hidden'}>
          <MapTab />
        </div>
        <div className={activeTab === 'identify' ? '' : 'hidden'}>
          <IdentifyTab onNavigate={setActiveTab} />
        </div>
        <div className={activeTab === 'aviary' ? '' : 'hidden'}>
          <AviaryTab onNavigate={setActiveTab} />
        </div>
        <div className={activeTab === 'field-guide' ? '' : 'hidden'}>
          <FieldGuideTab />
        </div>
        <div className={activeTab === 'profile' ? '' : 'hidden'}>
          <ProfileTab />
        </div>
      </main>
      <BottomNav activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
}
