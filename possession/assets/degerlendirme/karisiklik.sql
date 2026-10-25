/* @bruin
name: degerlendirme.karisiklik
type: duckdb.sql
description: Graded frames per ground-truth label and predicted label, per run and game.

depends:
  - degerlendirme.kareler

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

SELECT run_name, game, gt, pred, count(*) AS frames
FROM degerlendirme.kareler
WHERE run_name = '{{ var.run_name }}'
GROUP BY ALL
