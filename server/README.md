# AviQuest Bird Inference API

FastAPI server that accepts bird images or audio recordings and returns top-3 species predictions.

## Endpoints

| Method | Path           | Description                        |
|--------|----------------|------------------------------------|
| GET    | `/health`      | Liveness check                     |
| POST   | `/infer/image` | Identify bird from image (multipart) |
| POST   | `/infer/audio` | Identify bird from audio (multipart) |

### Success response (200)

```json
{
  "requestId": "d4f7e2a1-...",
  "modelVersion": "aviquest-v1.0.0-stub",
  "latencyMs": 1.23,
  "predictions": [
    {"label": "Black-capped Chickadee", "confidence": 0.91},
    {"label": "Carolina Chickadee",     "confidence": 0.06},
    {"label": "Mountain Chickadee",     "confidence": 0.02}
  ]
}
```

### Error response (400 / 401 / 413 / 500)

```json
{
  "error": {"code": 400, "type": "INVALID_REQUEST", "message": "..."},
  "requestId": "d4f7e2a1-..."
}
```

## Local development

```bash
cd server

# Create virtualenv and install deps
python -m venv .venv
source .venv/bin/activate
pip install -r requirements.txt

# Run in stub mode (fake deterministic predictions)
MODEL_MODE=stub uvicorn app.main:app --reload

# Interactive docs
open http://localhost:8000/docs
```

### Quick smoke test with curl

```bash
# Image inference
curl -X POST http://localhost:8000/infer/image \
  -F "file=@path/to/bird.jpg;type=image/jpeg"

# Audio inference
curl -X POST http://localhost:8000/infer/audio \
  -F "file=@path/to/bird.wav;type=audio/wav"
```

## Running tests

```bash
cd server
pip install pytest-asyncio
python -m pytest tests/ -v
```

## Docker

```bash
cd server
docker build -t aviquest-api .
docker run -p 8000:8000 -e MODEL_MODE=stub aviquest-api
```

## Configuration

All settings are read from environment variables. See `.env.example` for the full list.

| Variable           | Default                     | Description                          |
|--------------------|-----------------------------|--------------------------------------|
| `MODEL_MODE`       | `stub`                      | `stub` for fake predictions, `real` for ML model |
| `API_KEY`          | *(empty — auth disabled)*   | Set to require `X-API-Key` header    |
| `MAX_IMAGE_BYTES`  | `10485760` (10 MB)          | Max upload size for images           |
| `MAX_AUDIO_BYTES`  | `26214400` (25 MB)          | Max upload size for audio            |
| `MODEL_VERSION`    | `aviquest-v1.0.0-stub`      | Version string returned in responses |
| `HOST`             | `0.0.0.0`                   | Bind address                         |
| `PORT`             | `8000`                      | Bind port                            |

## Deploying

### Fly.io (quick)

```bash
cd server
fly launch --name aviquest-api
fly secrets set MODEL_MODE=stub
fly deploy
```

### Any Docker host

```bash
docker build -t aviquest-api .
docker run -d -p 8000:8000 \
  -e MODEL_MODE=stub \
  -e API_KEY=your-secret-key \
  aviquest-api
```

## Swapping in a real model

Replace the `predict_image_real` / `predict_audio_real` functions in `app/models.py` with your actual ML inference code. Set `MODEL_MODE=real` to activate.
