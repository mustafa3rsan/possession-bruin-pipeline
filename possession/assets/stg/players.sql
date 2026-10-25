/* @bruin
name: stg.players
type: duckdb.sql
description: Observed player positions (0-1) and speed per frame of every game, with each slot's side; for competition games the tactical recording inside stg.periods only.

depends:
  - raw.players
  - raw.tracks
  - raw.metrica_players
  - raw.metrica_tracks
  - stg.periods

materialization:
  type: view
@bruin */

SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM raw.players p JOIN raw.tracks t USING (game, source, slot)
JOIN stg.periods h ON h.game = p.game AND p.frame BETWEEN h.start_frame AND h.end_frame
WHERE p.source = 'tactical'
UNION ALL
SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM raw.metrica_players p JOIN raw.metrica_tracks t USING (game, slot)
