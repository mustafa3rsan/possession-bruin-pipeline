/* @bruin
name: temiz.maclar
type: duckdb.sql
description: Every game a model is run on. Competition games come from the data bundle with their own frame count, frame rate and pitch size; graded is true where a ground truth exists to score against.

depends:
  - ham.maclar
  - ham.dogru_cevaplar
  - ham.metrica_dogru_cevaplar

materialization:
  type: table

columns:
  - name: game
    type: varchar
    checks:
      - name: unique
@bruin */

SELECT game, 'competition' AS dataset, pitch_length, pitch_width, n_frames, fps,
       game IN (SELECT game FROM ham.dogru_cevaplar) AS graded
FROM ham.maclar
UNION ALL
SELECT game, 'metrica sample', 105.0, 68.0, count(*), 25.0, true
FROM ham.metrica_dogru_cevaplar
GROUP BY game
