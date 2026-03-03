'use client';

interface AnalyzingDialogProps {
  open: boolean;
}

export default function AnalyzingDialog({ open }: AnalyzingDialogProps) {
  if (!open) return null;

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center">
      <div className="absolute inset-0 bg-black/60 backdrop-blur-sm" />
      <div className="relative bg-[#1A2F1F] rounded-2xl p-6 text-center max-w-xs w-full mx-4 animate-fade-in">
        <h3 className="text-xl font-bold text-amber-400 mb-4">
          Analysing...
        </h3>
        <div className="flex justify-center mb-4">
          <div className="w-10 h-10 border-3 border-amber-400/30 border-t-amber-400 rounded-full animate-spin" />
        </div>
        <p className="text-white/70">Processing photo...</p>
      </div>
    </div>
  );
}
