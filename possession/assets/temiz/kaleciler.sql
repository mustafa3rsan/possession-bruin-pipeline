/* @bruin
name: temiz.kaleciler
type: duckdb.sql
description: "Her kaleci parçasının gerçekte hangi takımın kalecisi olduğu. Parçaları zaman sırasıyla tek tek dolaşıyoruz ve iki takımın kalecisinin en son nerede görüldüğünü aklımızda tutuyoruz. Yeni parça hangi takımın kalecisinin son yerine daha yakın başlıyorsa o takımın kalecisi, sonra o takımın son yeri bu parçanın bittiği yer oluyor. Yarı başında iki kalecinin son yeri korudukları kalenin ortası. Kaleci koşarak karşı sahaya geçerse izi kopmadığı için tek parça kalır, kurala takılmaz. Kısa parçalar (kayma anları) dağıtılmıyor."

depends:
  - temiz.kaleci_parcalari
  - temiz.kale_yonleri
  - temiz.maclar

materialization:
  type: table

columns:
  - name: takim
    type: varchar
    description: "Parçanın ait olduğu takım (H ya da A); tracker'ın etiketinden farklıysa kimlik karışmış demek"
    checks:
      - name: accepted_values
        value: [H, A]
  - name: mesafe_h
    type: double
    description: "Parçanın başladığı yerin, Barça (H) kalecisinin o ana kadarki son yerine uzaklığı, metre"
  - name: mesafe_a
    type: double
    description: "Parçanın başladığı yerin, Athletic (A) kalecisinin o ana kadarki son yerine uzaklığı, metre"

custom_checks:
  - name: kısa olmayan her parçaya bir takım verildi
    query: |
      SELECT count(*) FROM temiz.kaleci_parcalari p
      LEFT JOIN temiz.kaleciler k USING (parca_id)
      WHERE NOT p.kisa AND k.takim IS NULL
    value: 0
@bruin */

WITH RECURSIVE
parcalar AS (
  SELECT p.*, g.pitch_length, g.pitch_width,
         row_number() OVER (PARTITION BY p.game ORDER BY p.ilk_frame, p.slot) AS sira
  FROM temiz.kaleci_parcalari p
  JOIN temiz.maclar g USING (game)
  WHERE NOT p.kisa
),
-- Yarı başında iki takımın kalecisinin "son yeri": korudukları kalenin ortası.
baslangic AS (
  SELECT game, yari,
         any_value(CASE WHEN savundugu_kale = 'sol' THEN 0.0 ELSE 1.0 END) FILTER (WHERE side = 'H') AS h_x,
         any_value(CASE WHEN savundugu_kale = 'sol' THEN 0.0 ELSE 1.0 END) FILTER (WHERE side = 'A') AS a_x
  FROM temiz.kale_yonleri
  GROUP BY game, yari
),
-- Her parça için: kararı vermeden önceki son yerler (yeni yarıda baştan başlıyor).
dagitim AS (
  SELECT s.*,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN 'H' ELSE 'A' END AS takim,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.bitis_x ELSE s.onceki_h_x END AS son_h_x,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.bitis_y ELSE s.onceki_h_y END AS son_h_y,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.onceki_a_x ELSE s.bitis_x END AS son_a_x,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.onceki_a_y ELSE s.bitis_y END AS son_a_y
  FROM (
    SELECT p.game, p.sira, p.parca_id, p.yari, p.bitis_x, p.bitis_y, p.basla_x, p.basla_y, p.pitch_length, p.pitch_width,
           b.h_x AS onceki_h_x, 0.5 AS onceki_h_y, b.a_x AS onceki_a_x, 0.5 AS onceki_a_y,
           sqrt(power((p.basla_x - b.h_x) * p.pitch_length, 2) + power((p.basla_y - 0.5) * p.pitch_width, 2)) AS mesafe_h,
           sqrt(power((p.basla_x - b.a_x) * p.pitch_length, 2) + power((p.basla_y - 0.5) * p.pitch_width, 2)) AS mesafe_a
    FROM parcalar p
    JOIN baslangic b ON b.game = p.game AND b.yari = p.yari
    WHERE p.sira = 1
  ) s

  UNION ALL

  SELECT s.*,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN 'H' ELSE 'A' END,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.bitis_x ELSE s.onceki_h_x END,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.bitis_y ELSE s.onceki_h_y END,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.onceki_a_x ELSE s.bitis_x END,
         CASE WHEN s.mesafe_h <= s.mesafe_a THEN s.onceki_a_y ELSE s.bitis_y END
  FROM (
    SELECT t.*,
           sqrt(power((t.basla_x - t.onceki_h_x) * t.pitch_length, 2) + power((t.basla_y - t.onceki_h_y) * t.pitch_width, 2)) AS mesafe_h,
           sqrt(power((t.basla_x - t.onceki_a_x) * t.pitch_length, 2) + power((t.basla_y - t.onceki_a_y) * t.pitch_width, 2)) AS mesafe_a
    FROM (
      SELECT p.game, p.sira, p.parca_id, p.yari, p.bitis_x, p.bitis_y, p.basla_x, p.basla_y, p.pitch_length, p.pitch_width,
             CASE WHEN p.yari = r.yari THEN r.son_h_x ELSE b.h_x END AS onceki_h_x,
             CASE WHEN p.yari = r.yari THEN r.son_h_y ELSE 0.5 END AS onceki_h_y,
             CASE WHEN p.yari = r.yari THEN r.son_a_x ELSE b.a_x END AS onceki_a_x,
             CASE WHEN p.yari = r.yari THEN r.son_a_y ELSE 0.5 END AS onceki_a_y
      FROM dagitim r
      JOIN parcalar p ON p.game = r.game AND p.sira = r.sira + 1
      JOIN baslangic b ON b.game = p.game AND b.yari = p.yari
    ) t
  ) s (game, sira, parca_id, yari, bitis_x, bitis_y, basla_x, basla_y, pitch_length, pitch_width,
       onceki_h_x, onceki_h_y, onceki_a_x, onceki_a_y, mesafe_h, mesafe_a)
)
SELECT p.game, p.parca_id, p.slot, p.etiket, p.yari, p.ilk_frame, p.son_frame, p.frames,
       d.takim, d.takim <> p.etiket AS etiket_degisti, d.mesafe_h, d.mesafe_a
FROM dagitim d
JOIN parcalar p USING (parca_id)
