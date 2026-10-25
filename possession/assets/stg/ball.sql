/* @bruin
name: stg.ball
type: duckdb.sql
description: Ball position (0-1) and speed per frame of every game; for competition games the tactical recording, the one submissions are indexed to, inside stg.periods only.

depends:
  - raw.ball
  - raw.metrica_ball
  - stg.periods

materialization:
  type: view
@bruin */

SELECT b.game, b.frame, b.x, b.y, b.speed
FROM raw.ball b JOIN stg.periods p ON p.game = b.game AND b.frame BETWEEN p.start_frame AND p.end_frame
WHERE b.source = 'tactical'
UNION ALL
SELECT game, frame, x, y, speed FROM raw.metrica_ball
