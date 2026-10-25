/* @bruin
name: eval.confusion
type: duckdb.sql
description: Graded frames per ground-truth label and predicted label, per run and game.

depends:
  - eval.frames

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

SELECT run_name, game, gt, pred, count(*) AS frames
FROM eval.frames
WHERE run_name = '{{ var.run_name }}'
GROUP BY ALL
