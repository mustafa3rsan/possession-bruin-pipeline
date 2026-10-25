/* @bruin
name: temiz.dogru_cevaplar
type: duckdb.sql
description: "Bütün maçların doğru cevapları tek tabloda, her frame için bir etiket. Puanlanmayan frame'ler X."

depends:
  - ham.dogru_cevaplar
  - ham.metrica_dogru_cevaplar

materialization:
  type: table

custom_checks:
  - name: etiketler sadece H, A, D ya da X
    query: SELECT count(*) FROM temiz.dogru_cevaplar WHERE label NOT IN ('H', 'A', 'D', 'X') OR label IS NULL
    value: 0
@bruin */

SELECT game, frame, label FROM ham.dogru_cevaplar
UNION ALL
SELECT game, frame, label FROM ham.metrica_dogru_cevaplar
