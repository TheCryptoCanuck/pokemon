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
  const [frames, setFrames] = useState<ExtractedFrame[]>([]);
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
      const recognized = await recognizeCards(
        extracted,
        apiKey.trim(),
        allCards,
        (current, total) => setProgress(Math.round((current / total) * 100))
      );

      setResults(recognized);
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
          <div className="w-full bg-slate-700 rounded-full h-3">
            <div
              className="bg-blue-600 h-3 rounded-full transition-all"
              style={{ width: `${progress}%` }}
            />
          </div>
          <p className="text-gray-400 text-sm">{progress}%</p>
          {stage === "extracting" && (
            <p className="text-gray-500 text-xs">
              Extracted {frames.length} unique frames so far...
            </p>
          )}
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
          <div className="bg-green-900/30 border border-green-700 rounded-lg p-4 mb-4">
            <p className="text-green-400 font-semibold">
              Found {results.length} unique cards!
            </p>
            <p className="text-green-300 text-sm mt-1">
              Processed {frames.length} frames from your video.
            </p>
          </div>

          <div className="flex gap-3">
            <button
              onClick={handleConfirm}
              className="bg-green-600 hover:bg-green-700 text-white px-6 py-2 rounded font-semibold"
            >
              Add to Collection
            </button>
            <button
              onClick={() => {
                setStage("idle");
                setResults([]);
                setFrames([]);
              }}
              className="bg-slate-600 hover:bg-slate-500 text-white px-6 py-2 rounded"
            >
              Cancel
            </button>
          </div>
        </div>
      )}
    </div>
  );
}
