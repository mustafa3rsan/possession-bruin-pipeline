/* @bruin
name: degerlendirme.kareler
type: duckdb.sql
description: "Puanlanan her frame'de tahminimiz ile doğru cevap yan yana. Modelin X dediği yerleri organizatörün skor kodu nasıl dolduruyorsa öyle dolduruyoruz. Diğer değerlendirme tabloları buradan besleniyor."

depends:
  - model.tahminler
  - temiz.dogru_cevaplar

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

WITH graded AS (
    SELECT p.run_name, g.game, g.frame, g.label AS gt, p.label AS pred,
           g.frame - row_number() OVER (PARTITION BY g.game ORDER BY g.frame) AS block
    FROM model.tahminler p
    JOIN temiz.dogru_cevaplar g USING (game, frame)
    WHERE p.run_name = '{{ var.run_name }}' AND g.label <> 'X'
)
SELECT run_name, game, frame, block, gt, pred,
       coalesce(
           last_value(nullif(pred, 'X') IGNORE NULLS) OVER (
               PARTITION BY game, block ORDER BY frame ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW),
           first_value(nullif(pred, 'X') IGNORE NULLS) OVER (
               PARTITION BY game, block ORDER BY frame ROWS BETWEEN UNBOUNDED PRECEDING AND UNBOUNDED FOLLOWING),
           'X') AS pred_filled
FROM graded
