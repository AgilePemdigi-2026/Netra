
from pathlib import Path
import torch
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent

# Dataset NETRA
DATASET = BASE_DIR / "dataset" / "sidewalk_damage" / "data.yaml"

# Model hasil training pertama (10 epoch)
MODEL_PATH = BASE_DIR / "runs" / "sidewalk_v2" / "weights" / "best.pt"

# Folder hasil eksperimen
OUTPUT_DIR = BASE_DIR / "runs"

device = 0 if torch.cuda.is_available() else "cpu"

print("================================")
print("NETRA - SIDEWALK FINE-TUNING V2")
print("================================")

print(f"Model   : {MODEL_PATH}")
print(f"Dataset : {DATASET}")
print(f"Device  : {device}")

if not MODEL_PATH.exists():
    raise FileNotFoundError(f"Model tidak ditemukan: {MODEL_PATH}")

if not DATASET.exists():
    raise FileNotFoundError(f"Dataset tidak ditemukan: {DATASET}")

# Menggunakan model hasil training sebelumnya
model = YOLO(str(MODEL_PATH))

# Fine-tuning tambahan 10 epoch
model.train(
    data=str(DATASET),
    epochs=10,
    imgsz=640,
    batch=4,
    device=device,
    workers=0,
    patience=15,
    project=str(OUTPUT_DIR),
    name="sidewalk_v3",
    exist_ok=False,
)

print("\nTRAINING SELESAI!")
print("Hasil tersimpan di ai/runs/sidewalk_v3")
