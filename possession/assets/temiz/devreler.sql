/* @bruin
name: temiz.devreler
type: duckdb.sql
description: The two halves of every competition game. A half starts at its Smart Tagging Kick Off (Start) tag and ends when the teams leave the pitch, the first time after its last team phase that fewer than 15 people are tracked for 30 s. Zone tags (players or ball in the box, ball in final third) do not count as phases because Smart Tagging also fires them during halftime.

depends:
  - ham.maclar
  - ham.smart_tagging
  - ham.oyuncular

materialization:
  type: table

custom_checks:
  - name: every game has two halves, in order, not overlapping
    query: |
      SELECT count(*) FROM ham.maclar g
      LEFT JOIN (
        SELECT game, count(*) AS halves, bool_and(start_frame < end_frame) AS ordered,
               max(start_frame) > min(end_frame) AS apart
        FROM temiz.devreler GROUP BY game
      ) p USING (game)
      WHERE p.halves IS DISTINCT FROM 2 OR NOT p.ordered OR NOT p.apart
    value: 0
@bruin */

WITH tags AS (
  SELECT game, half,
         min(start_frame) FILTER (WHERE type = 'Kick Off (Start)') AS start_frame,
         max(end_frame) FILTER (WHERE code NOT IN ('PLAYERS IN THE BOX', 'BALL IN THE BOX', 'BALL IN FINAL THIRD'))
           AS last_phase
  FROM ham.smart_tagging
  GROUP BY game, half
),
tracked AS (
  SELECT g.game, f.frame, count(p.slot) AS people, (count(p.slot) < 15) AS empty
  FROM ham.maclar g
  CROSS JOIN LATERAL range(g.n_frames) f(frame)
  LEFT JOIN ham.oyuncular p ON p.game = g.game AND p.source = 'tactical' AND p.frame = f.frame
  GROUP BY g.game, f.frame
),
stretches AS (
  SELECT game, min(frame) AS first_frame, count(*) AS frames
  FROM (SELECT *, frame - row_number() OVER (PARTITION BY game, empty ORDER BY frame) AS grp FROM tracked)
  WHERE empty
  GROUP BY game, grp
),
emptied AS (
  SELECT s.game, s.first_frame FROM stretches s JOIN ham.maclar g USING (game) WHERE s.frames >= 30 * g.fps
)
SELECT t.game, t.half, t.start_frame,
       coalesce((SELECT min(e.first_frame) - 1 FROM emptied e WHERE e.game = t.game AND e.first_frame > t.last_phase),
                (SELECT n_frames - 1 FROM ham.maclar g WHERE g.game = t.game)) AS end_frame
FROM tags t
