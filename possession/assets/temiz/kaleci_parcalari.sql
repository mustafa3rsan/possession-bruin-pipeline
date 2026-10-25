/* @bruin
name: temiz.kaleci_parcalari
type: duckdb.sql
description: "Kaleci izlerini parçalara bölüyoruz. Parça, bir kaleci etiketinin kesintisiz takip edildiği dilim. Takip koptuğunda ya da kaleci tek frame'de 1 metreden fazla sıçradığında (saniyede 25 metre, hiçbir insan o kadar hızlı koşamaz) yeni parça başlıyor. Parçanın içinde aynı kişi olduğundan eminiz; parçalar arasında tracker kimliği karıştırmış olabilir, o yüzden her parçanın kime ait olduğuna temiz.kaleciler yeniden karar veriyor. Yarım saniyeden kısa parçalar kisa olarak işaretleniyor, bunlar genelde tracker'ın kayma anları."

depends:
  - ham.oyuncular
  - ham.slotlar
  - ham.atd_parametreleri
  - temiz.devreler
  - temiz.maclar

materialization:
  type: table

columns:
  - name: parca_id
    type: varchar
    checks:
      - name: unique
@bruin */

WITH kaleci_slotlari AS (
  SELECT s.game, s.slot, s.side
  FROM ham.slotlar s
  JOIN ham.atd_parametreleri a ON a.game = s.game AND a.source = s.source AND a.owner_id = s.player_id
  WHERE s.source = 'tactical' AND a.name = 'position_type' AND a.value = 'Goalkeeper'
),
yarilar AS (
  SELECT game, start_frame, end_frame, row_number() OVER (PARTITION BY game ORDER BY start_frame) AS yari
  FROM temiz.devreler
),
izler AS (
  SELECT o.game, o.slot, k.side AS etiket, y.yari, o.frame, o.x, o.y, g.pitch_length, g.pitch_width
  FROM ham.oyuncular o
  JOIN kaleci_slotlari k USING (game, slot)
  JOIN yarilar y ON y.game = o.game AND o.frame BETWEEN y.start_frame AND y.end_frame
  JOIN temiz.maclar g ON g.game = o.game
  WHERE o.source = 'tactical'
),
isaretli AS (
  SELECT *,
         CASE WHEN lag(frame) OVER w IS NULL
                OR frame - lag(frame) OVER w > 1
                OR sqrt(power((x - lag(x) OVER w) * pitch_length, 2) + power((y - lag(y) OVER w) * pitch_width, 2)) > 1
              THEN 1 ELSE 0 END AS yeni_parca
  FROM izler
  WINDOW w AS (PARTITION BY game, slot, yari ORDER BY frame)
),
numarali AS (
  SELECT *, sum(yeni_parca) OVER (PARTITION BY game, slot, yari ORDER BY frame) AS parca_no
  FROM isaretli
)
SELECT n.game, n.game || ':' || n.slot || ':' || n.yari || ':' || n.parca_no AS parca_id,
       n.slot, n.etiket, n.yari, n.parca_no,
       min(n.frame) AS ilk_frame, max(n.frame) AS son_frame, count(*) AS frames,
       arg_min(n.x, n.frame) AS basla_x, arg_min(n.y, n.frame) AS basla_y,
       arg_max(n.x, n.frame) AS bitis_x, arg_max(n.y, n.frame) AS bitis_y,
       count(*) < 0.5 * any_value(g.fps) AS kisa
FROM numarali n
JOIN temiz.maclar g ON g.game = n.game
GROUP BY n.game, n.slot, n.etiket, n.yari, n.parca_no
