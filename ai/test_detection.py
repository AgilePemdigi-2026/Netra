
from pathlib import Path
from ultralytics import YOLO

# Lokasi folder AI
BASE_DIR = Path(__file__).resolve().parent

# Lokasi gambar pengujian
IMAGE_PATH = BASE_DIR / "images" / "jalan.jpg"

# Periksa apakah foto tersedia
if not IMAGE_PATH.exists():
    raise FileNotFoundError(
        f"Foto tidak ditemukan: {IMAGE_PATH}"
    )

# Memuat model YOLO yang sudah berhasil digunakan
model = YOLO("yolo26n.pt")

# Menjalankan deteksi
hasil = model.predict(
    source=str(IMAGE_PATH),
    conf=0.35,
    save=True,
    project=str(BASE_DIR / "results"),
    name="uji_jalan",
    exist_ok=True,
)

print("\n=== HASIL DETEKSI NETRA ===")

for result in hasil:
    if result.boxes is None:
        continue

    for box in result.boxes:
        class_id = int(box.cls[0])
        confidence = float(box.conf[0])
        nama_objek = result.names[class_id]

        koordinat = box.xyxy[0].tolist()

        print(f"Objek: {nama_objek}")
        print(f"Confidence: {confidence:.2%}")
        print(f"Bounding box: {koordinat}")
        print("----------------------------")

print("\nDeteksi selesai!")
print("Hasil tersimpan di ai/results/uji_jalan")
