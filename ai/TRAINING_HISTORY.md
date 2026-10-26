

\# NETRA — AI Training History



\## Overview



NETRA menggunakan model YOLO26n untuk mendeteksi objek melalui kamera Android.



Pengembangan model khusus dilakukan untuk mengenali kerusakan permukaan trotoar menggunakan dataset Sidewalk-Damage v2.



\*\*Kelas deteksi saat ini:\*\* `Losa-Agrietada` (pelat beton/trotoar retak).



Model khusus ini masih dalam tahap eksperimen dan belum diintegrasikan sebagai pendeteksi kerusakan pada aplikasi Android.



\## Dataset



\- Nama: Sidewalk-Damage v2

\- Sumber: https://universe.roboflow.com/daos/sidewalk-damage/dataset/2

\- Training: 375 gambar

\- Validation: 82 gambar

\- Test: 40 gambar

\- Total: 497 gambar

\- Jumlah kelas: 1



Dataset tidak disimpan di GitHub.



\## Riwayat Training



| Eksperimen | Training | Precision | Recall | mAP50 | mAP50-95 |

|---|---|---|---|---|---|

| V1 | 10 epoch dari pretrained | 32.35% | 23.55% | 20.21% | 8.49% |

| V2 | 10 epoch tambahan dari V1 | 33.7% | 33.2% | 26.6% | 11.5% |

| V3 | 8 epoch tercatat, fine-tuning dari V2 | 39.82% | 34.75% | 34.10% | 14.48% |



\*\*Catatan V3:\*\*

\- Target awal: 10 epoch.

\- `results.csv` mencatat 8 epoch.

\- Angka V3 pada tabel berasal dari epoch terakhir yang tercatat, bukan evaluasi ulang `best.pt`.

\- Checkpoint `best.pt` mencatat indeks epoch 4.

\- Penyebab training berhenti pada epoch 8 belum dipastikan.



Seluruh metrik pada tabel berasal dari data validasi.



\## Model Checkpoints



\- V1: `ai/models/sidewalk\_best.pt`

\- V2: `ai/runs/sidewalk\_v2/weights/best.pt` (lokal)

\- V3: `ai/models/sidewalk\_v3\_best.pt`



Checkpoint V3 disimpan di repository agar anggota tim dapat menggunakannya tanpa mengulang training.



\## Pekerjaan Berikutnya



\- Mengevaluasi checkpoint terbaik V3.

\- Melakukan pengujian pada gambar baru.

\- Menambahkan dataset pothole (jalan berlubang).

\- Mengembangkan model deteksi dua kelas.

\- Menguji integrasi model kerusakan dengan Flutter Android.



\## Batasan



Model saat ini hanya dilatih untuk mengenali retakan pada pelat beton/trotoar.



Model belum mampu mendeteksi semua jenis kerusakan jalan dan belum dapat diandalkan sebagai satu-satunya sistem peringatan keselamatan bagi pengguna tunanetra.



