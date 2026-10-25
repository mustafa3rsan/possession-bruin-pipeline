/* @bruin
name: temiz.oyuncular
type: duckdb.sql
description: Observed player positions (0-1) and speed per frame of every game, with each slot's side; for competition games the tactical recording inside temiz.devreler only.

depends:
  - ham.oyuncular
  - ham.slotlar
  - ham.metrica_oyuncular
  - ham.metrica_slotlar
  - temiz.devreler

materialization:
  type: view
@bruin */

SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.oyuncular p JOIN ham.slotlar t USING (game, source, slot)
JOIN temiz.devreler h ON h.game = p.game AND p.frame BETWEEN h.start_frame AND h.end_frame
WHERE p.source = 'tactical'
UNION ALL
SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.metrica_oyuncular p JOIN ham.metrica_slotlar t USING (game, slot)
