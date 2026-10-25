/* @bruin
name: stg.games
type: duckdb.sql
description: Every game a model is run on. Competition games come from the data bundle with their own frame count, frame rate and pitch size; graded is true where a ground truth exists to score against.

depends:
  - raw.games
  - raw.gt_public
  - raw.metrica_ground_truth

materialization:
  type: table

columns:
  - name: game
    type: varchar
    checks:
      - name: unique
@bruin */

SELECT game, 'competition' AS dataset, pitch_length, pitch_width, n_frames, fps,
       game IN (SELECT game FROM raw.gt_public) AS graded
FROM raw.games
UNION ALL
SELECT game, 'metrica sample', 105.0, 68.0, count(*), 25.0, true
FROM raw.metrica_ground_truth
GROUP BY game
