/* @bruin
name: eval.frame_scores
type: duckdb.sql
description: Frame-level metrics per run and game, defined as in evaluation/possession_metrics.py (a predicted X on a graded frame is a miss).

depends:
  - eval.frames

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name
@bruin */

WITH f AS (
    SELECT * FROM eval.frames WHERE run_name = '{{ var.run_name }}'
), per_class AS (
    SELECT f.game, k.label,
           count(*) FILTER (WHERE f.gt = k.label AND f.pred = k.label) AS tp,
           count(*) FILTER (WHERE f.pred = k.label) AS predicted,
           count(*) FILTER (WHERE f.gt = k.label) AS actual
    FROM f CROSS JOIN (VALUES ('H'), ('A'), ('D')) AS k(label)
    GROUP BY f.game, k.label
), prf AS (
    SELECT game, label,
           CASE WHEN predicted > 0 THEN tp / predicted ELSE 0 END AS p,
           CASE WHEN actual > 0 THEN tp / actual ELSE 0 END AS r
    FROM per_class
), class_f1 AS (
    SELECT game, label, p, r, CASE WHEN p + r > 0 THEN 2 * p * r / (p + r) ELSE 0 END AS f1
    FROM prf
), by_class AS (
    SELECT game,
           avg(f1) AS macro_f1,
           any_value(f1) FILTER (WHERE label = 'H') AS f1_h,
           any_value(f1) FILTER (WHERE label = 'A') AS f1_a,
           any_value(f1) FILTER (WHERE label = 'D') AS f1_d,
           any_value(p) FILTER (WHERE label = 'H') AS precision_h,
           any_value(r) FILTER (WHERE label = 'H') AS recall_h,
           any_value(p) FILTER (WHERE label = 'A') AS precision_a,
           any_value(r) FILTER (WHERE label = 'A') AS recall_a,
           any_value(p) FILTER (WHERE label = 'D') AS precision_d,
           any_value(r) FILTER (WHERE label = 'D') AS recall_d
    FROM class_f1
    GROUP BY game
), totals AS (
    SELECT game,
           count(*) AS n_graded,
           count(*) FILTER (WHERE pred = 'X') AS n_abstain_on_graded,
           count(*) FILTER (WHERE pred = gt) AS correct,
           count(*) FILTER (WHERE gt IN ('H', 'A') AND pred IN ('H', 'A')) AS alive_tp,
           count(*) FILTER (WHERE gt = 'D' AND pred IN ('H', 'A')) AS alive_fp,
           count(*) FILTER (WHERE gt IN ('H', 'A') AND pred NOT IN ('H', 'A')) AS alive_fn,
           count(*) FILTER (WHERE gt IN ('H', 'A') AND pred = gt) AS team_correct,
           count(*) FILTER (WHERE gt IN ('H', 'A')) AS gt_alive,
           count(*) FILTER (WHERE pred IN ('H', 'A')) AS pred_alive,
           count(*) FILTER (WHERE gt = 'H') AS gt_home,
           count(*) FILTER (WHERE pred = 'H') AS pred_home
    FROM f
    GROUP BY game
), alive AS (
    SELECT *,
           CASE WHEN alive_tp + alive_fp > 0 THEN alive_tp / (alive_tp + alive_fp) ELSE 0 END AS alive_p,
           CASE WHEN alive_tp + alive_fn > 0 THEN alive_tp / (alive_tp + alive_fn) ELSE 0 END AS alive_r
    FROM totals
)
SELECT '{{ var.run_name }}' AS run_name,
       a.game,
       c.macro_f1,
       a.correct / a.n_graded AS accuracy,
       CASE WHEN a.alive_p + a.alive_r > 0 THEN 2 * a.alive_p * a.alive_r / (a.alive_p + a.alive_r) ELSE 0 END AS alive_dead_f1,
       CASE WHEN a.gt_alive > 0 THEN a.team_correct / a.gt_alive ELSE 0 END AS team_acc_gt_alive,
       CASE WHEN a.alive_tp > 0 THEN a.team_correct / a.alive_tp ELSE 0 END AS team_acc_both_alive,
       CASE WHEN a.gt_alive > 0 THEN a.gt_home / a.gt_alive ELSE 0 END AS gt_home_share,
       CASE WHEN a.pred_alive > 0 THEN a.pred_home / a.pred_alive END AS pred_home_share,
       c.f1_h, c.f1_a, c.f1_d,
       c.precision_h, c.recall_h, c.precision_a, c.recall_a, c.precision_d, c.recall_d,
       a.n_graded,
       a.n_abstain_on_graded
FROM alive a JOIN by_class c USING (game)
