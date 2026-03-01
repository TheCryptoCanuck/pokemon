'use client';

import { useRef, useEffect } from 'react';
import { Bird } from '../../lib/types';
import { getBirdXp, RARITY_COLORS } from '../../lib/game';
import RarityBadge from './RarityBadge';
import BirdImage from './BirdImage';

interface BirdDetailProps {
  bird: Bird | null;
  onClose: () => void;
}

interface DetailRowProps {
  icon: React.ReactNode;
  label: string;
  value: string;
}

function DetailRow({ icon, label, value }: DetailRowProps) {
  return (
    <div className="flex gap-2.5 py-1.5">
      <span className="text-amber-400 mt-0.5 shrink-0">{icon}</span>
      <div>
        <p className="text-white/50 text-xs">{label}</p>
        <p className="text-white text-[15px]">{value}</p>
      </div>
    </div>
  );
}

export default function BirdDetail({ bird, onClose }: BirdDetailProps) {
  const overlayRef = useRef<HTMLDivElement>(null);
  const audioRef = useRef<HTMLAudioElement | null>(null);

  useEffect(() => {
    if (bird) {
      document.body.style.overflow = 'hidden';
    }
    return () => {
      document.body.style.overflow = '';
      if (audioRef.current) {
        audioRef.current.pause();
        audioRef.current = null;
      }
    };
  }, [bird]);

  useEffect(() => {
    const handleEsc = (e: KeyboardEvent) => {
      if (e.key === 'Escape') onClose();
    };
    window.addEventListener('keydown', handleEsc);
    return () => window.removeEventListener('keydown', handleEsc);
  }, [onClose]);

  if (!bird) return null;

  const handlePlayCall = () => {
    if (audioRef.current) {
      audioRef.current.pause();
    }
    audioRef.current = new Audio(bird.audioUrl);
    audioRef.current.play().catch(() => {});
  };

  return (
    <div
      ref={overlayRef}
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center"
      onClick={(e) => {
        if (e.target === overlayRef.current) onClose();
      }}
    >
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
      <div className="relative w-full max-w-lg max-h-[95dvh] bg-[#1A2F1F] rounded-t-3xl sm:rounded-3xl overflow-y-auto animate-slide-up">
        <div className="p-5">
          {/* Drag handle */}
          <div className="flex justify-center mb-4">
            <div className="w-10 h-1 rounded-full bg-white/20" />
          </div>

          {/* Rarity badge */}
          <div className="flex justify-center mb-2">
            <RarityBadge rarity={bird.rarity} />
          </div>

          {/* Name */}
          <h2 className="text-2xl font-bold text-amber-400 text-center mb-0.5">
            {bird.name}
          </h2>
          <p className="text-white/50 text-center italic text-sm mb-4">
            {bird.scientificName}
          </p>

          {/* Image */}
          {bird.rarity === 'unknown' ? (
            <div
              className="h-40 rounded-2xl border flex flex-col items-center justify-center mb-4"
              style={{
                backgroundColor: `${RARITY_COLORS.unknown}08`,
                borderColor: `${RARITY_COLORS.unknown}40`,
              }}
            >
              <span className="text-6xl">&#x2753;</span>
              <p className="text-purple-300 text-sm mt-1.5">Photo not yet in database</p>
            </div>
          ) : (
            <div className="rounded-2xl overflow-hidden mb-4">
              <BirdImage src={bird.imageUrl} alt={bird.name} className="h-60" />
            </div>
          )}

          {/* Details */}
          <DetailRow
            icon={
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 6.042A8.967 8.967 0 0 0 6 3.75c-1.052 0-2.062.18-3 .512v14.25A8.987 8.987 0 0 1 6 18c2.305 0 4.408.867 6 2.292m0-14.25a8.966 8.966 0 0 1 6-2.292c1.052 0 2.062.18 3 .512v14.25A8.987 8.987 0 0 0 18 18a8.967 8.967 0 0 0-6 2.292m0-14.25v14.25" />
              </svg>
            }
            label="Lore"
            value={bird.lore}
          />
          <DetailRow
            icon={
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M2.25 15.75l5.159-5.159a2.25 2.25 0 013.182 0l5.159 5.159m-1.5-1.5l1.409-1.409a2.25 2.25 0 013.182 0l2.909 2.909M3.75 21h16.5a2.25 2.25 0 002.25-2.25V5.25a2.25 2.25 0 00-2.25-2.25H3.75a2.25 2.25 0 00-2.25 2.25v13.5A2.25 2.25 0 003.75 21z" />
              </svg>
            }
            label="Habitat"
            value={bird.habitat}
          />
          <DetailRow
            icon={
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M12 21a9.004 9.004 0 0 0 8.716-6.747M12 21a9.004 9.004 0 0 1-8.716-6.747M12 21c2.485 0 4.5-4.03 4.5-9S14.485 3 12 3m0 18c-2.485 0-4.5-4.03-4.5-9S9.515 3 12 3m0 0a8.997 8.997 0 0 1 7.843 4.582M12 3a8.997 8.997 0 0 0-7.843 4.582m15.686 0A11.953 11.953 0 0 1 12 10.5c-2.998 0-5.74-1.1-7.843-2.918m15.686 0A8.959 8.959 0 0 1 21 12c0 .778-.099 1.533-.284 2.253m0 0A17.919 17.919 0 0 1 12 16.5a17.92 17.92 0 0 1-8.716-2.247m0 0A9.015 9.015 0 0 1 3 12c0-1.605.42-3.113 1.157-4.418" />
              </svg>
            }
            label="Conservation"
            value={bird.conservationStatus}
          />
          <DetailRow
            icon={
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={1.5}>
                <path strokeLinecap="round" strokeLinejoin="round" d="m3.75 13.5 10.5-11.25L12 10.5h8.25L9.75 21.75 12 13.5H3.75Z" />
              </svg>
            }
            label="XP Value"
            value={`+${getBirdXp(bird)} XP`}
          />

          {/* Audio button */}
          {bird.audioUrl && (
            <button
              onClick={handlePlayCall}
              className="mt-4 w-full flex items-center justify-center gap-2 bg-amber-400 text-black font-bold py-3 rounded-xl hover:bg-amber-300 transition-colors"
            >
              <svg className="w-5 h-5" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                <path strokeLinecap="round" strokeLinejoin="round" d="M19.114 5.636a9 9 0 0 1 0 12.728M16.463 8.288a5.25 5.25 0 0 1 0 7.424M6.75 8.25l4.72-4.72a.75.75 0 0 1 1.28.53v15.88a.75.75 0 0 1-1.28.53l-4.72-4.72H4.51c-.88 0-1.704-.507-1.938-1.354A9.009 9.009 0 0 1 2.25 12c0-.83.112-1.633.322-2.396C2.806 8.756 3.63 8.25 4.51 8.25H6.75Z" />
              </svg>
              Play Bird Call
            </button>
          )}

          {/* Close */}
          <button
            onClick={onClose}
            className="mt-3 w-full py-3 rounded-xl border border-white/20 text-white/50 hover:text-white/70 hover:border-white/30 transition-colors"
          >
            Close
          </button>

          <div className="h-8" />
        </div>
      </div>
    </div>
  );
}
