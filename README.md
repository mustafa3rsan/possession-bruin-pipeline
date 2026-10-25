# Possession pipeline

[More than a Hack 2027 – Phase 1: Ball Possession](https://github.com/metrica-sports/more-than-a-hack-2027) için kurduğumuz [Bruin](https://getbruin.com) pipeline'ı. Amaç maçın tactical videosundaki her frame için topun kimde olduğunu tahmin etmek: H (ev sahibi), A (deplasman), D (top ölü) ya da X (puanlanmıyor). Her denemeye bir isim veriyoruz, pipeline tahmini üretip doğru cevaplarla karşılaştırıyor, dashboard'da run'ları yan yana görüyoruz.

Maç verisi bu repoda yok. Sadece yarışmaya kayıtlı olanlara verildiği ve dağıtılamadığı için git'e girmiyor; aşağıdaki "Veri nereye" kısmına bak.

## Katmanlar

```
ham.*            CSV'lerden olduğu gibi yüklenen veri, her tabloda game kolonu var
temiz.*          maçlar (maclar), yarılar (devreler), yarıların içindeki top (top) ve oyuncular (oyuncular),
                 doğru cevaplar (dogru_cevaplar), broadcast ile tactical'ın zaman eşlemesi (yayin_senkronu)
model.*          model/predict.py bir isimle çalışıyor (son_tahminler); model.tahminler bütün run'ları saklıyor
degerlendirme.*  tahmini doğru cevapla karşılaştırıp puanlıyor; degerlendirme.skorlar her run ve maç için bir satır
```

Kodda maça özel bir şey yok. Frame sayısı, fps ve saha ölçüsü her maçın kendi tracking dosyasından, yarılar Smart Tagging ve tracking'den, broadcast kayması iki kameranın top izlerinden hesaplanıyor. Yeni maç gelince ayrıca bir şey yazmak gerekmiyor.

## Araçlar

| dosya | ne işe yarıyor |
|---|---|
| `run.sh <isim>` | Her şeyi tek komutla çalıştırıyor: gerekirse CSV'leri üretiyor, pipeline'ı o isimle çalıştırıp skor tablosunu yazdırıyor. İlk seferde tabloları kendisi oluşturuyor |
| `convert/to_csv.py` | Organizatörün veri paketini (XML, TXT) `data/csv/` altında CSV'ye çeviriyor. Maçları dosya adından buluyor |
| `convert/fetch_metrica.sh` | Metrica'nın açık iki maçını GitHub'dan `external_data/metrica`'ya indiriyor |
| `convert/metrica_to_csv.py` | Metrica maçlarını CSV'ye çeviriyor, olay verisinden H/A/D/X etiketlerini üretiyor |
| `viewer/server.py` | Tactical ve broadcast videoyu yan yana açıp üstüne topu ve oyuncuları çiziyor, yanında radar. `python3 viewer/server.py`, sonra http://localhost:8765 |
| `onboarding.sh` | Veriyi adım adım tanıtan tur, sorgularıyla birlikte |

## Veri nereye

Hiçbiri git'e girmiyor, hepsi `.gitignore`'da:

```
data/                      organizatörün paketi (data/tactical, data/broadcast) ya da MTAH_DATA_DIR ile başka yer
data/csv/                  convert/ çıktısı, seed'ler buradan okuyor
data/videos/<kaynak>/      <MAÇ>_<kaynak>.mp4, viewer için
evaluation/gt/             organizatörün reposundaki <MAÇ>_possession_gt_public.csv
external_data/metrica/     fetch_metrica.sh indiriyor
```

## Çalıştırma

En kolayı `./run.sh benim_denemem`. Elle yapmak istersen:

```bash
cat > .bruin.yml <<'YML'
default_environment: default
environments:
  default:
    connections:
      duckdb:
        - name: possession
          path: possession.duckdb
        - name: possession_read
          path: possession.duckdb
          read_only: true
YML

bruin run --workers 1 --full-refresh --var 'run_name="baseline"' possession/   # ilk sefer tabloları oluşturuyor
bruin run --workers 1 --var 'run_name="benim_denemem"' possession/             # sonrakiler üstüne ekliyor
bruin lineage possession/assets/degerlendirme/skorlar.sql
dac serve --dir possession --open
```

Seed'ler `data/csv/` altını okuyor (`possession/assets/ham` altındaki her asset'in `path`'ine bak). `--workers 1` adımları tek tek çalıştırıyor, çünkü DuckDB dosyasına aynı anda sadece bir işlem yazabiliyor.

## Teşekkür

`evaluation/possession_metrics.py` ve `model/predict.py` içindeki `smooth()` organizatörün reposundan, MIT Lisansı, (c) 2026-2027 Metrica Sports.
