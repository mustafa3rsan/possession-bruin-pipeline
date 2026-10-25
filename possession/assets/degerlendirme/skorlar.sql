/* @bruin
name: degerlendirme.skorlar
type: duckdb.sql
description: The scoreboard, one row per run name and game. Ranked on spell_f1_mean like the official board.

depends:
  - degerlendirme.kare_skorlari
  - degerlendirme.blok_istatistikleri
  - degerlendirme.son_spell_f1
  - model.calistirmalar
  - temiz.maclar

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name

custom_checks:
  - name: one row per graded game for this run
    query: |
      SELECT count(*) FROM temiz.maclar g
      LEFT JOIN degerlendirme.skorlar s ON s.game = g.game AND s.run_name = '{{ var.run_name }}'
      WHERE g.graded AND s.game IS NULL
    value: 0
@bruin */

SELECT r.run_name,
       g.game,
       g.dataset,
       r.created_at,
       s.spell_f1_mean,
       f.macro_f1,
       st.n_pred_spells AS poss,
       st.n_gt_spells AS gt_poss,
       st.pred_mean_spell_s AS dur,
       st.gt_mean_spell_s AS gt_dur,
       s.spell_bootstrap_low,
       s.spell_bootstrap_high,
       s.spell_f1_iou_03, s.spell_f1_iou_04, s.spell_f1_iou_05, s.spell_f1_iou_06, s.spell_f1_iou_07,
       f.* EXCLUDE (run_name, game, macro_f1),
       st.n_gt_segments,
       st.n_pred_segments,
       r.params
FROM model.calistirmalar r
CROSS JOIN temiz.maclar g
JOIN degerlendirme.kare_skorlari f ON f.run_name = r.run_name AND f.game = g.game
JOIN degerlendirme.blok_istatistikleri st ON st.run_name = r.run_name AND st.game = g.game
JOIN degerlendirme.son_spell_f1 s ON s.run_name = r.run_name AND s.game = g.game
WHERE r.run_name = '{{ var.run_name }}' AND g.graded
