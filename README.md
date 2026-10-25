# Possession pipeline

[More than a Hack 2027 – Phase 1: Ball Possession](https://github.com/metrica-sports/more-than-a-hack-2027) için kurduğumuz [Bruin](https://getbruin.com) pipeline'ı. Amaç maçın tactical videosundaki her frame için topun kimde olduğunu tahmin etmek: H (ev sahibi), A (deplasman), D (top ölü) ya da X (puanlanmıyor). Her denemeye bir isim veriyoruz, pipeline tahmini üretip doğru cevaplarla karşılaştırıyor, dashboard'da run'ları yan yana görüyoruz.

Maç verisi bu repoda yok. Sadece yarışmaya kayıtlı olanlara verildiği için `data/` git'e girmiyor; pipeline kendi veri paketinden ürettiğin CSV'leri okuyor.

## Katmanlar

```
ham.*            CSV'lerden olduğu gibi yüklenen veri, her tabloda game kolonu var
temiz.*          maçlar (maclar), yarılar (devreler), yarıların içindeki top (top) ve oyuncular (oyuncular),
                 doğru cevaplar (dogru_cevaplar), broadcast ile tactical'ın zaman eşlemesi (yayin_senkronu)
model.*          model/predict.py bir isimle çalışıyor (son_tahminler); model.tahminler bütün run'ları saklıyor
degerlendirme.*  tahmini doğru cevapla karşılaştırıp puanlıyor; degerlendirme.skorlar her run ve maç için bir satır
```

Kodda maça özel bir şey yok. Frame sayısı, fps ve saha ölçüsü her maçın kendi tracking dosyasından, yarılar Smart Tagging ve tracking'den, broadcast kayması iki kameranın top izlerinden hesaplanıyor. Yeni maç gelince ayrıca bir şey yazmak gerekmiyor.

## Çalıştırma

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
