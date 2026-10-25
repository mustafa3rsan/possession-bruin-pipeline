/* @bruin
name: temiz.maclar
type: duckdb.sql
description: "Modeli çalıştırdığımız bütün maçlar, yarışma maçları ve Metrica maçları bir arada. graded true ise elimizde o maçın doğru cevapları var, skor hesaplayabiliyoruz."

depends:
  - ham.maclar
  - ham.dogru_cevaplar
  - ham.metrica_dogru_cevaplar

materialization:
  type: table

columns:
  - name: game
    type: varchar
    checks:
      - name: unique
@bruin */

SELECT game, 'competition' AS dataset, pitch_length, pitch_width, n_frames, fps,
       game IN (SELECT game FROM ham.dogru_cevaplar) AS graded
FROM ham.maclar
UNION ALL
SELECT game, 'metrica sample', 105.0, 68.0, count(*), 25.0, true
FROM ham.metrica_dogru_cevaplar
GROUP BY game
