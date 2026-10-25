/* @bruin
name: temiz.top
type: duckdb.sql
description: Ball position (0-1) and speed per frame of every game; for competition games the tactical recording, the one submissions are indexed to, inside temiz.devreler only.

depends:
  - ham.top
  - ham.metrica_top
  - temiz.devreler

materialization:
  type: view
@bruin */

SELECT b.game, b.frame, b.x, b.y, b.speed
FROM ham.top b JOIN temiz.devreler p ON p.game = b.game AND b.frame BETWEEN p.start_frame AND p.end_frame
WHERE b.source = 'tactical'
UNION ALL
SELECT game, frame, x, y, speed FROM ham.metrica_top
