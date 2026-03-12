export interface ExtractedFrame {
  dataUrl: string;
  timestamp: number;
}

export async function extractFrames(
  file: File,
  intervalSeconds: number = 2,
  onProgress?: (pct: number) => void
): Promise<ExtractedFrame[]> {
  return new Promise((resolve, reject) => {
    const video = document.createElement("video");
    const canvas = document.createElement("canvas");
    const ctx = canvas.getContext("2d");

    if (!ctx) {
      reject(new Error("Canvas context not available"));
      return;
    }

    video.preload = "auto";
    video.muted = true;

    const url = URL.createObjectURL(file);
    video.src = url;
    video.load();

    video.onloadedmetadata = async () => {
      const duration = video.duration;
      canvas.width = video.videoWidth;
      canvas.height = video.videoHeight;

      const frames: ExtractedFrame[] = [];
      const timestamps: number[] = [];

      for (let t = 0; t < duration; t += intervalSeconds) {
        timestamps.push(t);
      }

      for (let i = 0; i < timestamps.length; i++) {
        const t = timestamps[i];
        try {
          const frame = await seekAndCapture(video, canvas, ctx, t);
          if (frame && !isDuplicateFrame(frames, frame)) {
            frames.push(frame);
          }
        } catch {
          // Skip frames that fail to capture
        }
        onProgress?.(((i + 1) / timestamps.length) * 100);
      }

      URL.revokeObjectURL(url);
      resolve(frames);
    };

    video.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Failed to load video"));
    };
  });
}

function seekAndCapture(
  video: HTMLVideoElement,
  canvas: HTMLCanvasElement,
  ctx: CanvasRenderingContext2D,
  time: number
): Promise<ExtractedFrame> {
  return new Promise((resolve, reject) => {
    video.currentTime = time;
    const timeout = setTimeout(() => reject(new Error("Seek timeout")), 5000);

    video.onseeked = () => {
      clearTimeout(timeout);
      ctx.drawImage(video, 0, 0, canvas.width, canvas.height);
      const dataUrl = canvas.toDataURL("image/jpeg", 0.8);
      resolve({ dataUrl, timestamp: time });
    };
  });
}

function isDuplicateFrame(
  existing: ExtractedFrame[],
  newFrame: ExtractedFrame
): boolean {
  if (existing.length === 0) return false;
  // Simple length comparison - drastically different data URLs likely mean different frames
  const last = existing[existing.length - 1];
  const lenDiff = Math.abs(last.dataUrl.length - newFrame.dataUrl.length);
  const avgLen = (last.dataUrl.length + newFrame.dataUrl.length) / 2;
  return lenDiff / avgLen < 0.005; // Less than 0.5% size difference means near-identical frame
}

export function frameToBase64(frame: ExtractedFrame): string {
  return frame.dataUrl.replace(/^data:image\/\w+;base64,/, "");
}
