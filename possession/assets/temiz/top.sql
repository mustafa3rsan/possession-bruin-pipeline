/* @bruin
name: temiz.top
type: duckdb.sql
description: "Modelin okuduğu top verisi. Yarışma maçlarında sadece tactical kamera (submission ona göre) ve sadece yarıların içi; devre arası, maç öncesi ve sonrası atılıyor. Henüz başka temizlik yok, sıçramalar falan hâlâ içinde."

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
