/* @bruin
name: model.girdiler_top
type: duckdb.sql
description: "Her run'da modelin okuduğu temiz top verisinin kopyası, run adıyla. temiz.top her run'da üzerine yazıldığı için, bir run'ın hangi veriyle çalıştığını sonradan görebilelim diye burada saklıyoruz. Sadece yarışma maçları; Metrica'yı viewer'da göstermiyoruz."

depends:
  - temiz.top
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

SELECT '{{ var.run_name }}' AS run_name, t.game, t.frame, t.x, t.y, t.speed
FROM temiz.top t
JOIN temiz.maclar g ON g.game = t.game AND g.dataset = 'competition'
