/* @bruin
name: temiz.oyuncular
type: duckdb.sql
description: "Modelin okuduğu oyuncu verisi, her oyuncunun takımıyla birlikte. temiz.top ile aynı filtreler. Bir de kaleci düzeltmesi var. Tracker iki kalecinin kimliğini sık sık karıştırıyor, o yüzden kaleci etiketli birinin takımını bulunduğu yarı sahadan belirliyoruz; o yarıda hangi takım o kaleyi koruyorsa onun kalecisi. Aynı kalede iki kaleci çıkarsa kaleye en yakın olanı tutup diğerini kopya sayıp siliyoruz."

depends:
  - ham.oyuncular
  - ham.slotlar
  - ham.metrica_oyuncular
  - ham.metrica_slotlar
  - temiz.devreler
  - temiz.kaleciler

materialization:
  type: view
@bruin */

WITH kale_sahipleri AS (
  SELECT game, start_frame, end_frame,
         any_value(side) FILTER (WHERE savundugu_kale = 'sol') AS sol_takim,
         any_value(side) FILTER (WHERE savundugu_kale = 'sag') AS sag_takim
  FROM temiz.kaleciler
  GROUP BY game, start_frame, end_frame
),
yarisma AS (
  SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed, k.slot IS NOT NULL AS kaleci
  FROM ham.oyuncular p JOIN ham.slotlar t USING (game, source, slot)
  JOIN temiz.devreler h ON h.game = p.game AND p.frame BETWEEN h.start_frame AND h.end_frame
  LEFT JOIN temiz.kaleciler k ON k.game = p.game AND k.slot = p.slot AND p.frame BETWEEN k.start_frame AND k.end_frame
  WHERE p.source = 'tactical'
),
kaleciler AS (
  SELECT y.game, y.frame, y.slot, CASE WHEN y.x < 0.5 THEN s.sol_takim ELSE s.sag_takim END AS side, y.x, y.y, y.speed
  FROM yarisma y JOIN kale_sahipleri s ON s.game = y.game AND y.frame BETWEEN s.start_frame AND s.end_frame
  WHERE y.kaleci
  QUALIFY row_number() OVER (PARTITION BY y.game, y.frame, CASE WHEN y.x < 0.5 THEN s.sol_takim ELSE s.sag_takim END
                             ORDER BY least(y.x, 1 - y.x)) = 1
)
SELECT game, frame, slot, side, x, y, speed FROM yarisma WHERE NOT kaleci
UNION ALL
SELECT game, frame, slot, side, x, y, speed FROM kaleciler
UNION ALL
SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.metrica_oyuncular p JOIN ham.metrica_slotlar t USING (game, slot)
