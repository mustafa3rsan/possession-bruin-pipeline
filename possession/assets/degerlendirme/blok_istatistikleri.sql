/* @bruin
name: degerlendirme.blok_istatistikleri
type: duckdb.sql
description: Possession counts and mean durations per run and game, for the ground truth and the prediction.

depends:
  - degerlendirme.bloklar

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

SELECT run_name, game,
       count(*) FILTER (WHERE series = 'gt' AND is_possession) AS n_gt_spells,
       count(*) FILTER (WHERE series = 'pred' AND is_possession) AS n_pred_spells,
       avg(frames) FILTER (WHERE series = 'gt' AND is_possession) / 25.0 AS gt_mean_spell_s,
       avg(frames) FILTER (WHERE series = 'pred' AND is_possession) / 25.0 AS pred_mean_spell_s,
       count(*) FILTER (WHERE series = 'gt') AS n_gt_segments,
       count(*) FILTER (WHERE series = 'pred') AS n_pred_segments
FROM degerlendirme.bloklar
WHERE run_name = '{{ var.run_name }}'
GROUP BY run_name, game
