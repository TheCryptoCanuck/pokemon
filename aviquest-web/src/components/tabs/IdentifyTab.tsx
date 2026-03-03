'use client';

import { useState, useCallback, useRef, useEffect } from 'react';
import { Bird, TabId } from '../../lib/types';
import { weightedRandomBird, ACHIEVEMENTS } from '../../lib/game';
import { birds } from '../../data/birds';
import { useGame } from '../../context/GameContext';
import AnalyzingDialog from '../dialogs/AnalyzingDialog';
import FoundBirdDialog from '../dialogs/FoundBirdDialog';

interface IdentifyTabProps {
  onNavigate: (tab: TabId) => void;
}

export default function IdentifyTab({ onNavigate }: IdentifyTabProps) {
  const game = useGame();
  const [analyzing, setAnalyzing] = useState(false);
  const [foundBird, setFoundBird] = useState<Bird | null>(null);
  const [toast, setToast] = useState<string | null>(null);
  const videoRef = useRef<HTMLVideoElement>(null);
  const streamRef = useRef<MediaStream | null>(null);
  const [cameraReady, setCameraReady] = useState(false);
  const [cameraError, setCameraError] = useState(false);

  const startCamera = useCallback(async () => {
    try {
      const stream = await navigator.mediaDevices.getUserMedia({
        video: { facingMode: 'environment' },
      });
      streamRef.current = stream;
      if (videoRef.current) {
        videoRef.current.srcObject = stream;
        setCameraReady(true);
      }
    } catch {
      setCameraError(true);
    }
  }, []);

  useEffect(() => {
    startCamera();
    return () => {
      if (streamRef.current) {
        streamRef.current.getTracks().forEach(t => t.stop());
      }
    };
  }, [startCamera]);

  const showToast = (msg: string) => {
    setToast(msg);
    setTimeout(() => setToast(null), 4000);
  };

  const handleIdentify = useCallback(async () => {
    setAnalyzing(true);
    await new Promise(r => setTimeout(r, 1800));
    setAnalyzing(false);
    const bird = weightedRandomBird(birds);
    setFoundBird(bird);
  }, []);

  const handleAdd = useCallback(() => {
    if (!foundBird) return;
    const { newAchievements, leveledUp } = game.addBird(foundBird);

    if (leveledUp) {
      showToast(`LEVEL UP! You are now a Level ${game.level + 1} birder!`);
    }

    if (newAchievements.length > 0) {
      const achievement = ACHIEVEMENTS.find(a => a.key === newAchievements[0]);
      if (achievement) {
        setTimeout(() => {
          showToast(`Achievement Unlocked! ${achievement.emoji} ${achievement.title}`);
        }, leveledUp ? 1500 : 0);
      }
    }

    setFoundBird(null);
  }, [foundBird, game]);

  return (
    <div className="flex flex-col items-center justify-center min-h-[calc(100dvh-64px)] px-6 py-8">
      {/* Title */}
      <h1 className="text-3xl font-bold text-amber-400 mb-1 animate-fade-in">
        AviQuest
      </h1>
      <p className="text-white/50 mb-6 animate-fade-in animation-delay-100">
        Point at a bird and identify it!
      </p>

      {/* Camera viewfinder */}
      <div className="relative w-full max-w-sm aspect-[3/4] rounded-3xl overflow-hidden border-2 border-amber-400/50 mb-8 animate-fade-in animation-delay-200">
        {cameraReady && !cameraError ? (
          <video
            ref={videoRef}
            autoPlay
            playsInline
            muted
            className="w-full h-full object-cover"
          />
        ) : (
          <div className="w-full h-full bg-[#1A2F1F] flex flex-col items-center justify-center">
            <svg className="w-16 h-16 text-white/15 mb-2" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1}>
              <path strokeLinecap="round" strokeLinejoin="round" d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z" />
              <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0Z" />
            </svg>
            <p className="text-white/30 text-sm">
              {cameraError ? 'Camera unavailable' : 'Starting camera...'}
            </p>
            {!cameraError && (
              <video ref={videoRef} autoPlay playsInline muted className="hidden" />
            )}
          </div>
        )}
        {/* Crosshair overlay */}
        <div className="absolute inset-0 pointer-events-none">
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-16 h-16 border-2 border-amber-400/40 rounded-full" />
          <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-[0.5px] w-6 h-[1px] bg-amber-400/40" />
          <div className="absolute top-1/2 left-1/2 -translate-x-[0.5px] -translate-y-1/2 w-[1px] h-6 bg-amber-400/40" />
        </div>
      </div>

      {/* Action buttons */}
      <div className="flex gap-4 animate-fade-in animation-delay-300">
        <button
          onClick={handleIdentify}
          disabled={analyzing}
          className="flex items-center gap-2 bg-amber-400 text-black font-bold px-6 py-3.5 rounded-2xl hover:bg-amber-300 transition-colors disabled:opacity-50"
        >
          <svg className="w-7 h-7" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M6.827 6.175A2.31 2.31 0 0 1 5.186 7.23c-.38.054-.757.112-1.134.175C2.999 7.58 2.25 8.507 2.25 9.574V18a2.25 2.25 0 0 0 2.25 2.25h15A2.25 2.25 0 0 0 21.75 18V9.574c0-1.067-.75-1.994-1.802-2.169a47.865 47.865 0 0 0-1.134-.175 2.31 2.31 0 0 1-1.64-1.055l-.822-1.316a2.192 2.192 0 0 0-1.736-1.039 48.774 48.774 0 0 0-5.232 0 2.192 2.192 0 0 0-1.736 1.039l-.821 1.316Z" />
            <path strokeLinecap="round" strokeLinejoin="round" d="M16.5 12.75a4.5 4.5 0 1 1-9 0 4.5 4.5 0 0 1 9 0Z" />
          </svg>
          Identify by Photo
        </button>
        <button
          onClick={handleIdentify}
          disabled={analyzing}
          className="flex items-center gap-2 border border-amber-400 text-amber-400 font-bold px-5 py-3.5 rounded-2xl hover:bg-amber-400/10 transition-colors disabled:opacity-50"
        >
          <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M12 18.75a6 6 0 0 0 6-6v-1.5m-6 7.5a6 6 0 0 1-6-6v-1.5m6 7.5v3.75m-3.75 0h7.5M12 15.75a3 3 0 0 1-3-3V4.5a3 3 0 1 1 6 0v8.25a3 3 0 0 1-3 3Z" />
          </svg>
          By Call
        </button>
      </div>

      {/* Dialogs */}
      <AnalyzingDialog open={analyzing} />
      <FoundBirdDialog
        bird={foundBird}
        onAdd={handleAdd}
        onSkip={() => setFoundBird(null)}
      />

      {/* Toast */}
      {toast && (
        <div className="fixed top-4 left-1/2 -translate-x-1/2 z-[60] bg-amber-400 text-black font-bold px-6 py-3 rounded-xl shadow-lg animate-fade-in max-w-sm text-center">
          {toast}
        </div>
      )}
    </div>
  );
}
