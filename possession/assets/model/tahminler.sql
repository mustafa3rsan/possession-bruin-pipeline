/* @bruin
name: model.tahminler
type: duckdb.sql
description: Every run's labels, one row per run name, game and frame. Re-running a name replaces it.

depends:
  - model.son_tahminler
  - temiz.maclar

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name

columns:
  - name: run_name
    type: varchar
    checks:
      - name: not_null

custom_checks:
  - name: every game has frames 0..n_frames-1 once each for this run
    query: |
      SELECT count(*) FROM temiz.maclar g
      LEFT JOIN (
          SELECT game, count(*) AS n, count(DISTINCT frame) AS n_distinct, min(frame) AS lo, max(frame) AS hi
          FROM model.tahminler WHERE run_name = '{{ var.run_name }}' GROUP BY game
      ) p USING (game)
      WHERE p.n IS DISTINCT FROM g.n_frames OR p.n_distinct <> g.n_frames OR p.lo <> 0 OR p.hi <> g.n_frames - 1
    value: 0
  - name: labels are H, A, D or X
    query: SELECT count(*) FROM model.tahminler WHERE label NOT IN ('H', 'A', 'D', 'X') OR label IS NULL
    value: 0
@bruin */

SELECT run_name, game, frame::INTEGER AS frame, upper(trim(label)) AS label
FROM model.son_tahminler
