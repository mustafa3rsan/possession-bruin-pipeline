/* @bruin
name: degerlendirme.bloklar
type: duckdb.sql
description: "Etiketin değişmediği kesintisiz parçalar, hem doğru cevap hem tahmin için. H ve A blokları possession'lar, D blokları ölü toplar. Hiçbir blok iki yarıya yayılmıyor."

depends:
  - degerlendirme.kareler

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

WITH labelled AS (
    SELECT run_name, game, block, frame, 'gt' AS series, gt AS label
    FROM degerlendirme.kareler WHERE run_name = '{{ var.run_name }}'
    UNION ALL
    SELECT run_name, game, block, frame, 'pred' AS series, pred_filled AS label
    FROM degerlendirme.kareler WHERE run_name = '{{ var.run_name }}'
), islands AS (
    SELECT *,
           row_number() OVER (PARTITION BY game, series, block ORDER BY frame)
             - row_number() OVER (PARTITION BY game, series, block, label ORDER BY frame) AS island
    FROM labelled
)
SELECT run_name, game, series, label,
       min(frame) AS start_frame,
       max(frame) + 1 AS stop_frame,
       count(*) AS frames,
       label IN ('H', 'A') AS is_possession
FROM islands
GROUP BY run_name, game, series, block, label, island
