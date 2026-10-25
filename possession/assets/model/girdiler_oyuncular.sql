/* @bruin
name: model.girdiler_oyuncular
type: duckdb.sql
description: "Her run'da modelin okuduğu temiz oyuncu verisinin kopyası, run adıyla. Kaleci düzeltmesi gibi temizlik kuralları değiştikçe her run'ın kendi halini görebilelim diye. Sadece yarışma maçları."

depends:
  - temiz.oyuncular
  - temiz.maclar

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name

columns:
  - name: run_name
    type: varchar
    checks:
      - name: not_null
@bruin */

SELECT '{{ var.run_name }}' AS run_name, t.game, t.frame, t.slot, t.side, t.x, t.y, t.speed
FROM temiz.oyuncular t
JOIN temiz.maclar g ON g.game = t.game AND g.dataset = 'competition'
