
from pathlib import Path
import torch
from ultralytics import YOLO

# Lokasi folder ai
BASE_DIR = Path(__file__).resolve().parent

# Dataset pothole
DATASET = BASE_DIR / "data.yaml"

# Folder hasil training baru
OUTPUT_DIR = BASE_DIR / "runs"

device = "cpu"

print("================================")
print("NETRA - POTHOLE DETECTION")
print("================================")
print(f"Dataset : {DATASET}")
print(f"Device  : {device}")

if not DATASET.exists():
    raise FileNotFoundError(f"Dataset tidak ditemukan: {DATASET}")

# Gunakan model YOLO26n pretrained
model = YOLO("yolo26n.pt")

model.train(
    data=str(DATASET),
    epochs=10,
    imgsz=640,
    batch=2,
    device=device,
    workers=0,
    patience=5,
    project=str(OUTPUT_DIR),
    name="pothole_v1",
    exist_ok=False,
)

print("\nTRAINING SELESAI!")
print(f"Hasil tersimpan di: {OUTPUT_DIR / 'pothole_v1' / 'weights' / 'best.pt'}")
