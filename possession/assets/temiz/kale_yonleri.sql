/* @bruin
name: temiz.kale_yonleri
type: duckdb.sql
description: "Her yarıda hangi takım hangi kaleyi koruyor. Takımın ilk yarıdaki hücum yönünden buluyoruz, ikinci yarıda taraf değişiyor; soldan sağa hücum eden takım ilk yarıda sol kaleyi korur. Bunu sadece yarı başında kalecilerin nereden başladığını tahmin etmek için kullanıyoruz, kalecinin sonradan nereye gittiğine karışmıyor."

depends:
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
  - name: her maçta her yarı için iki takımın da kalesi var
    query: |
      SELECT count(*) FROM temiz.devreler d
      LEFT JOIN (SELECT game, start_frame, count(DISTINCT side) AS takimlar FROM temiz.kale_yonleri GROUP BY ALL) k
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
)
SELECT y.game, y.yari, y.start_frame, y.end_frame, h.side,
       CASE WHEN (h.ilk_yari_yonu = 'left_to_right') = (y.yari = 1) THEN 'sol' ELSE 'sag' END AS savundugu_kale
FROM hucum_yonleri h
JOIN yarilar y USING (game)
