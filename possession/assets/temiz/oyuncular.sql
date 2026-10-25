/* @bruin
name: temiz.oyuncular
type: duckdb.sql
description: "Modelin okuduğu oyuncu verisi, her oyuncunun takımıyla birlikte. temiz.top ile aynı filtreler. Bir de kaleci kuralı var: kaleci olarak işaretli biri o yarıda takımının hücum ettiği yarı sahada görünüyorsa o konumu siliyoruz, çünkü kaleci orta sahayı geçmez; bu genelde tracker'ın iki kalecinin kimliğini karıştırdığı anlar."

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

SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.oyuncular p JOIN ham.slotlar t USING (game, source, slot)
JOIN temiz.devreler h ON h.game = p.game AND p.frame BETWEEN h.start_frame AND h.end_frame
LEFT JOIN temiz.kaleciler k ON k.game = p.game AND k.slot = p.slot AND p.frame BETWEEN k.start_frame AND k.end_frame
WHERE p.source = 'tactical'
  AND NOT coalesce((k.savundugu_kale = 'sol' AND p.x > 0.5) OR (k.savundugu_kale = 'sag' AND p.x < 0.5), false)
UNION ALL
SELECT p.game, p.frame, p.slot, t.side, p.x, p.y, p.speed
FROM ham.metrica_oyuncular p JOIN ham.metrica_slotlar t USING (game, slot)
