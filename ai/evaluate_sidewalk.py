
from pathlib import Path
from ultralytics import YOLO

BASE_DIR = Path(__file__).resolve().parent

MODEL_PATH = (
    BASE_DIR
    / "runs"
    / "sidewalk_v1"
    / "weights"
    / "best.pt"
)

DATASET_PATH = (
    BASE_DIR
    / "dataset"
    / "sidewalk_damage"
    / "data.yaml"
)

print("================================")
print("EVALUASI AI NETRA - SIDEWALK")
print("================================")

model = YOLO(str(MODEL_PATH))

metrics = model.val(
    data=str(DATASET_PATH),
    split="val",
    imgsz=640,
    batch=4,
    device="cpu",
    workers=0,
    plots=True,
    project=str(BASE_DIR / "evaluations"),
    name="sidewalk_10epoch",
)

print("\n=== HASIL EVALUASI NETRA ===")
print(f"Precision : {metrics.box.mp:.4f}")
print(f"Recall    : {metrics.box.mr:.4f}")
print(f"mAP50     : {metrics.box.map50:.4f}")
print(f"mAP50-95  : {metrics.box.map:.4f}")

print("\nEVALUASI SELESAI!")
