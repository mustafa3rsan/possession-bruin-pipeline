/* @bruin
name: temiz.dogru_cevaplar
type: duckdb.sql
description: One label per frame of every game; X where the frame is not graded.

depends:
  - ham.dogru_cevaplar
  - ham.metrica_dogru_cevaplar

materialization:
  type: table

custom_checks:
  - name: labels are H, A, D or X
    query: SELECT count(*) FROM temiz.dogru_cevaplar WHERE label NOT IN ('H', 'A', 'D', 'X') OR label IS NULL
    value: 0
@bruin */

SELECT game, frame, label FROM ham.dogru_cevaplar
UNION ALL
SELECT game, frame, label FROM ham.metrica_dogru_cevaplar
