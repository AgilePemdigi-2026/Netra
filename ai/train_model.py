
from pathlib import Path
import torch
from ultralytics import YOLO

# Lokasi folder AI NETRA
BASE_DIR = Path(__file__).resolve().parent

# Lokasi dataset
DATASET = (
    BASE_DIR
    / "dataset"
    / "sidewalk_damage"
    / "data.yaml"
)

# Folder hasil training
OUTPUT_DIR = BASE_DIR / "runs"

# Periksa GPU
if torch.cuda.is_available():
    device = 0
    print("GPU NVIDIA CUDA terdeteksi.")
else:
    device = "cpu"
    print("GPU CUDA tidak tersedia. Menggunakan CPU.")

print("\n================================")
print("TRAINING YOLO NETRA")
print("KELAS: LOSA-AGRIETADA")
print("================================")

print(f"Dataset: {DATASET}")
print(f"Device : {device}")

# Model YOLO pretrained
model = YOLO("yolo26n.pt")

# Percobaan training pertama
model.train(
    data=str(DATASET),
    epochs=10,
    imgsz=640,
    batch=4,
    device=device,
    workers=0,
    project=str(OUTPUT_DIR),
    name="sidewalk_v1",
    exist_ok=False,
)

print("\nTRAINING SELESAI!")
print("Hasil tersimpan di folder ai/runs.")
