/* @bruin
name: stg.ground_truth
type: duckdb.sql
description: One label per frame of every game; X where the frame is not graded.

depends:
  - raw.gt_public
  - raw.metrica_ground_truth

materialization:
  type: table

custom_checks:
  - name: labels are H, A, D or X
    query: SELECT count(*) FROM stg.ground_truth WHERE label NOT IN ('H', 'A', 'D', 'X') OR label IS NULL
    value: 0
@bruin */

SELECT game, frame, label FROM raw.gt_public
UNION ALL
SELECT game, frame, label FROM raw.metrica_ground_truth
