/* @bruin
name: temiz.oyuncular
type: duckdb.sql
description: "Modelin okuduğu oyuncu verisi, her oyuncunun takımıyla birlikte. temiz.top ile aynı filtreler. Bir de kaleci düzeltmesi var. Tracker iki kalecinin kimliğini karıştırabiliyor, o yüzden kaleci satırlarının takımını temiz.kaleciler'deki karardan alıyoruz. Aynı anda aynı takıma iki kaleci düşerse uzun süredir kesintisiz takip edilen parçayı tutup diğerini kopya sayıp siliyoruz. Kayma anlarındaki kısa parçalar da siliniyor."

depends:
  - ham.oyuncular
  - ham.slotlar
  - ham.metrica_oyuncular
  - ham.metrica_slotlar
  - temiz.devreler
  - temiz.kaleci_parcalari
  - temiz.kaleciler

materialization:
  type: view
@bruin */

WITH yarisma AS (
  SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed, kp.parca_id, kp.frames AS parca_uzunlugu
  FROM ham.oyuncular p JOIN ham.slotlar t USING (game, source, slot)
  JOIN temiz.devreler h ON h.game = p.game AND p.frame BETWEEN h.start_frame AND h.end_frame
  LEFT JOIN temiz.kaleci_parcalari kp ON kp.game = p.game AND kp.slot = p.slot AND p.frame BETWEEN kp.ilk_frame AND kp.son_frame
  WHERE p.source = 'tactical'
),
kaleciler AS (
  SELECT y.game, y.frame, y.slot, k.takim AS side, y.x, y.y, y.speed
  FROM yarisma y JOIN temiz.kaleciler k USING (parca_id)
  QUALIFY row_number() OVER (PARTITION BY y.game, y.frame, k.takim ORDER BY y.parca_uzunlugu DESC) = 1
)
SELECT game, frame, slot, side, x, y, speed FROM yarisma WHERE parca_id IS NULL
UNION ALL
SELECT game, frame, slot, side, x, y, speed FROM kaleciler
UNION ALL
SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.metrica_oyuncular p JOIN ham.metrica_slotlar t USING (game, slot)
