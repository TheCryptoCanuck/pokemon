# ─────────────────────────────────────────────────────────────────────
# Download the AIY Vision Bird Classifier V1 TFLite model (Windows)
# Run from the aviquest/ directory:  .\scripts\download_model.ps1
#
# Model: Google AIY Vision Classifier — Birds V1
# Input: 224x224 RGB, normalized [0,1]
# Output: 964 bird species (scientific names)
# Size: ~3.4 MB
# Source: TensorFlow Hub
# ─────────────────────────────────────────────────────────────────────

$dest = "assets\bird_model.tflite"
$url = "https://tfhub.dev/google/lite-model/aiy/vision/classifier/birds_V1/3?lite-format=tflite"

if (Test-Path $dest) {
    $size = (Get-Item $dest).Length
    if ($size -gt 1000000) {
        Write-Host "Model already exists: $dest ($size bytes)"
        Write-Host "Delete it first to re-download."
        exit 0
    }
}

Write-Host "Downloading AIY Vision Bird Classifier V1..."
Write-Host "  From: $url"
Write-Host "  To:   $dest"

Invoke-WebRequest -Uri $url -OutFile $dest

$size = (Get-Item $dest).Length
$sizeMB = [math]::Round($size / 1MB, 1)
Write-Host ""
Write-Host "Downloaded: $size bytes ($sizeMB MB)"
Write-Host "Ready to build: flutter run"
