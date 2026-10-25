/* @bruin
name: degerlendirme.karisiklik
type: duckdb.sql
description: "Hangi etiketi hangisiyle karıştırıyoruz, mesela gerçekte D iken kaç frame H demişiz. Dashboard'daki confusion matrix buradan."

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
