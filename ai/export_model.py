
from pathlib import Path
from ultralytics import YOLO

# Folder AI NETRA
BASE_DIR = Path(__file__).resolve().parent

# Folder untuk menyimpan model hasil ekspor
OUTPUT_DIR = BASE_DIR / "models"
OUTPUT_DIR.mkdir(parents=True, exist_ok=True)

# Menggunakan model yang sudah berhasil kita uji
model = YOLO("yolo26n.pt")

print("Memulai ekspor model AI NETRA...")

# Ekspor ke format ONNX
hasil = model.export(
    format="onnx",
    imgsz=640,
    device="cpu",
)

# Pindahkan hasil ekspor ke folder models
file_hasil = Path(hasil)
file_tujuan = OUTPUT_DIR / "netra_yolo.onnx"

if file_hasil.resolve() != file_tujuan.resolve():
    import shutil
    shutil.copy2(file_hasil, file_tujuan)

print("\nEKSPOR MODEL BERHASIL!")
print(f"Model tersimpan di: {file_tujuan}")
