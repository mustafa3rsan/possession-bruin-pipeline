/* @bruin
name: temiz.kaleciler
type: duckdb.sql
description: "Her yarışma maçında kaleciler ve her yarıda hangi kaleyi korudukları. Kaleciyi tracking metadata'sındaki mevkiden, kaleyi takımın ilk yarıdaki hücum yönünden buluyoruz; ikinci yarıda taraf değişiyor. Soldan sağa hücum eden takım ilk yarıda sol kaleyi korur."

depends:
  - ham.slotlar
  - ham.takimlar
  - ham.atd_parametreleri
  - temiz.devreler

materialization:
  type: table

columns:
  - name: savundugu_kale
    type: varchar
    description: "sol (x < 0.5 tarafı) ya da sag (x > 0.5 tarafı)"
    checks:
      - name: accepted_values
        value: [sol, sag]

custom_checks:
  - name: her maçta her yarı için iki takımın da kalecisi var
    query: |
      SELECT count(*) FROM temiz.devreler d
      LEFT JOIN (SELECT game, start_frame, count(DISTINCT side) AS takimlar FROM temiz.kaleciler GROUP BY ALL) k
        USING (game, start_frame)
      WHERE k.takimlar IS DISTINCT FROM 2
    value: 0
@bruin */

WITH yarilar AS (
  SELECT game, start_frame, end_frame, row_number() OVER (PARTITION BY game ORDER BY start_frame) AS yari
  FROM temiz.devreler
),
hucum_yonleri AS (
  SELECT t.game, t.side, a.value AS ilk_yari_yonu
  FROM ham.atd_parametreleri a
  JOIN ham.takimlar t ON t.game = a.game AND t.source = a.source AND t.team_id = a.owner_id
  WHERE a.source = 'tactical' AND a.name = 'attack_direction_first_half'
),
kaleciler AS (
  SELECT s.game, s.slot, s.side
  FROM ham.slotlar s
  JOIN ham.atd_parametreleri a ON a.game = s.game AND a.source = s.source AND a.owner_id = s.player_id
  WHERE s.source = 'tactical' AND a.name = 'position_type' AND a.value = 'Goalkeeper'
)
SELECT k.game, k.slot, k.side, y.yari, y.start_frame, y.end_frame,
       CASE WHEN (h.ilk_yari_yonu = 'left_to_right') = (y.yari = 1) THEN 'sol' ELSE 'sag' END AS savundugu_kale
FROM kaleciler k
JOIN hucum_yonleri h USING (game, side)
JOIN yarilar y USING (game)
