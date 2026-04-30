import { useState, useRef } from "react";
import { Card, CollectionEntry } from "../../types/card";
import { extractFrames, ExtractedFrame } from "../../services/video-processor";
import {
  recognizeCards,
  getStoredApiKey,
  setStoredApiKey,
} from "../../services/card-recognizer";

interface Props {
  allCards: Card[];
  onImport: (entries: CollectionEntry[]) => void;
}

type Stage = "idle" | "extracting" | "recognizing" | "preview" | "error";

export default function VideoImport({ allCards, onImport }: Props) {
  const [stage, setStage] = useState<Stage>("idle");
  const [progress, setProgress] = useState(0);
  const [progressLabel, setProgressLabel] = useState("");
  const [apiKey, setApiKey] = useState(getStoredApiKey());
  const [error, setError] = useState("");
  const [results, setResults] = useState<CollectionEntry[]>([]);
  const [warnings, setWarnings] = useState<string[]>([]);
  const [frames, setFrames] = useState<ExtractedFrame[]>([]);
  // Diagnostic counter shown during the recognize stage so a long-running
  // import doesn't look frozen.
  const [frameProgress, setFrameProgress] = useState({ current: 0, total: 0 });
  const fileRef = useRef<HTMLInputElement>(null);

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;

    if (!apiKey.trim()) {
      setError("Please enter your Anthropic API key first");
      setStage("error");
      return;
    }

    setStoredApiKey(apiKey.trim());
    setError("");

    try {
      // Extract frames
      setStage("extracting");
      setProgressLabel("Extracting frames from video...");
      const extracted = await extractFrames(file, 2, (pct) =>
        setProgress(Math.round(pct))
      );
      setFrames(extracted);

      if (extracted.length === 0) {
        setError("No frames could be extracted from the video");
        setStage("error");
        return;
      }

      // Recognize cards
      setStage("recognizing");
      setProgressLabel("Identifying cards with Claude Vision...");
      setProgress(0);
      setFrameProgress({ current: 0, total: extracted.length });
      const recognized = await recognizeCards(
        extracted,
        apiKey.trim(),
        allCards,
        (current, total) => {
          setProgress(Math.round((current / total) * 100));
          setFrameProgress({ current, total });
        }
      );

      setResults(recognized.entries);
      setWarnings(recognized.warnings);
      setStage("preview");
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unknown error");
      setStage("error");
    }
  };

  const handleConfirm = () => {
    onImport(results);
    setStage("idle");
    setResults([]);
    setFrames([]);
    if (fileRef.current) fileRef.current.value = "";
  };

  return (
    <div className="bg-slate-800 rounded-xl p-6">
      <h3 className="text-lg font-bold text-white mb-2">
        Import from Video
      </h3>
      <p className="text-gray-400 text-sm mb-4">
        Screen record your TCGP collection on Android, then upload the video
        here. Claude Vision AI will identify your cards automatically.
      </p>

      {/* API Key */}
      <div className="mb-4">
        <label className="text-sm text-gray-400 block mb-1">
          Anthropic API Key
        </label>
        <input
          type="password"
          value={apiKey}
          onChange={(e) => setApiKey(e.target.value)}
          placeholder="sk-ant-..."
          className="w-full bg-slate-700 text-white border border-slate-600 rounded px-3 py-2 text-sm focus:outline-none focus:border-blue-500"
        />
        <p className="text-xs text-gray-500 mt-1">
          Your key is stored locally and only sent to Anthropic's API.
        </p>
      </div>

      {/* File upload */}
      {stage === "idle" && (
        <div className="border-2 border-dashed border-slate-600 rounded-lg p-8 text-center hover:border-blue-500 transition-colors">
          <input
            ref={fileRef}
            type="file"
            accept="video/*"
            onChange={handleFileSelect}
            className="hidden"
            id="video-upload"
          />
          <label htmlFor="video-upload" className="cursor-pointer">
            <div className="text-4xl mb-2">🎬</div>
            <p className="text-white font-semibold">
              Drop a video or click to upload
            </p>
            <p className="text-gray-400 text-sm mt-1">
              MP4, MOV, or WebM supported
            </p>
          </label>
        </div>
      )}

      {/* Progress */}
      {(stage === "extracting" || stage === "recognizing") && (
        <div className="space-y-3">
          <p className="text-white text-sm">{progressLabel}</p>
          <div className="w-full bg-slate-700 rounded-full h-3 overflow-hidden">
            <div
              className="h-3 rounded-full bg-gradient-to-r from-blue-700 via-blue-400 to-blue-700 bg-[length:200%_100%] animate-shimmer transition-[width] duration-300"
              style={{ width: `${progress}%` }}
            />
          </div>
          <div className="flex items-center justify-between text-xs text-gray-400 tabular-nums">
            <span>{progress}%</span>
            {stage === "extracting" && (
              <span>Extracted {frames.length} unique frames</span>
            )}
            {stage === "recognizing" && frameProgress.total > 0 && (
              <span>
                Frame {frameProgress.current} / {frameProgress.total}
              </span>
            )}
          </div>
        </div>
      )}

      {/* Error */}
      {stage === "error" && (
        <div className="bg-red-900/30 border border-red-700 rounded-lg p-4">
          <p className="text-red-400 text-sm">{error}</p>
          <button
            onClick={() => {
              setStage("idle");
              setError("");
            }}
            className="mt-2 text-sm text-red-300 hover:text-white underline"
          >
            Try again
          </button>
        </div>
      )}

      {/* Preview results */}
      {stage === "preview" && (
        <div>
          {warnings.length > 0 && (
            <div className="bg-yellow-900/30 border border-yellow-700 rounded-lg p-4 mb-4">
              {warnings.map((w, i) => (
                <p key={i} className="text-yellow-400 text-sm">{w}</p>
              ))}
            </div>
          )}

          {results.length > 0 ? (
            <div className="bg-green-900/30 border border-green-700 rounded-lg p-4 mb-4 animate-slide-up-fade">
              <p className="text-green-400 font-semibold">
                Found {results.length} unique cards!
              </p>
              <p className="text-green-300 text-sm mt-1">
                Processed {frames.length} frames from your video.
              </p>
            </div>
          ) : (
            <div className="text-center py-6 mb-4 animate-slide-up-fade">
              <div className="text-4xl mb-2" aria-hidden>🎞️</div>
              <p className="text-yellow-400 font-semibold">
                No cards recognized
              </p>
              <p className="text-yellow-300 text-sm mt-1 max-w-md mx-auto">
                Make sure the recording shows the TCGP collection screen with
                card names visible. A slower scroll usually helps.
              </p>
            </div>
          )}

          <div className="flex gap-3">
            {results.length > 0 && (
              <button
                onClick={handleConfirm}
                className="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-semibold"
              >
                Add to Collection
              </button>
            )}
            <button
              onClick={() => {
                setStage("idle");
                setResults([]);
                setWarnings([]);
                setFrames([]);
              }}
              className="bg-slate-600 hover:bg-slate-500 text-white px-6 py-2 rounded"
            >
              {results.length > 0 ? "Cancel" : "Try Again"}
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
