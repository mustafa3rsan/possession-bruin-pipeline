#!/usr/bin/env bash
# Adım adım veri turu: ./onboarding.sh  (önce en az bir kez ./run.sh çalışmış olmalı)
set -euo pipefail
cd "$(dirname "$0")"

step() {
  echo
  echo "================================================================================"
  echo "$1"
  echo "--------------------------------------------------------------------------------"
  echo "$2" | fold -s -w 100
  echo
  bruin query --connection possession --query "$3"
  if [ -t 0 ]; then read -r -p "devam için Enter..." _; fi
}

step "1/10  Elimizdeki tablolar" \
"Her şey possession.duckdb içinde. raw.* ham veriden gelen seed'ler, model.* tahminler, eval.* skorlar. ball ve players iki kameranın verisini birlikte tutar; hangisi olduğu source kolonunda yazar." \
"SELECT schema_name || '.' || table_name AS tablo, estimated_size AS satir
 FROM duckdb_tables() ORDER BY 1"

step "2/10  İki kamera: tactical ve broadcast" \
"Submission tactical videoya göre: satır i = tactical videonun i. frame'i (25 fps). Broadcast ayrı bir kayıt, kesmeler ve tekrarlar var, tactical ile senkron değil. Frame sayıları ve maç süresi:" \
"SELECT source, count(*) AS frame, round(count(*) / 25 / 60, 1) AS dakika,
        round(avg((x IS NOT NULL)::INT) * 100, 1) AS top_gorunur_yuzde
 FROM ham.top GROUP BY source ORDER BY source"

step "3/10  Ground truth: neyi tahmin ediyoruz" \
"Her frame için H (Barcelona'da top), A (Athletic'te), D (top ölü) veya X (puanlanmıyor). Public GT sadece ilk 5 dakikayı veriyor (frame 11185-18684); geri kalanı X. Asıl skor tüm maç üzerinden, gizli GT ile hesaplanıyor." \
"SELECT label, count(*) AS frame, min(frame) AS ilk_frame, max(frame) AS son_frame
 FROM ham.dogru_cevaplar GROUP BY label ORDER BY label"

step "4/10  Possession'lar: spellF1'in saydığı şey" \
"GT'deki kesintisiz H veya A blokları possession'dır. spellF1 her possession'ı tek bir nesne olarak sayar: senin tahminin bir possession'ı IoU >= 0.3..0.7 ile yakalarsa isabet. 5 dakikada sadece 17 possession olduğu için skor çok oynak." \
"SELECT label, count(*) AS adet, round(avg(frames) / 25.0, 1) AS ort_saniye,
        round(min(frames) / 25.0, 1) AS en_kisa_s, round(max(frames) / 25.0, 1) AS en_uzun_s
 FROM degerlendirme.bloklar
 WHERE game = 'BAR-ATH' AND series = 'gt' AND run_name = (SELECT min(run_name) FROM degerlendirme.bloklar)
 GROUP BY label ORDER BY label"

step "5/10  İlk 60 saniyenin GT zaman çizelgesi" \
"Maçın nasıl aktığına bir örnek: kim, ne zaman, ne kadar süre. Saniye, tactical videodaki zaman." \
"SELECT round(start_frame / 25.0, 1) AS bas_s, round(stop_frame / 25.0, 1) AS bit_s,
        round(frames / 25.0, 1) AS sure_s, label
 FROM degerlendirme.bloklar
 WHERE game = 'BAR-ATH' AND series = 'gt' AND run_name = (SELECT min(run_name) FROM degerlendirme.bloklar)
   AND start_frame < 11185 + 60 * 25
 ORDER BY start_frame"

step "6/10  Top: en değerli ve en güvenilmez sinyal" \
"Konumlar 0-1 arası normalize (metre için x*105.3, y*68). Top puanlanan 5 dakikada ne sıklıkla görünüyor ve görünmediğinde GT ne diyor? Top görünmüyor diye ölü değil: oyuncuların arkasında, havada veya ceza sahasında kalabalıkta kaybolur." \
"SELECT g.label AS gt, count(*) AS frame,
        round(avg((b.x IS NOT NULL)::INT) * 100, 1) AS top_gorunur_yuzde,
        round(avg(b.speed), 1) AS ort_top_hizi_ms
 FROM ham.dogru_cevaplar g JOIN ham.top b ON b.source = 'tactical' AND b.frame = g.frame
 WHERE g.label <> 'X' GROUP BY g.label ORDER BY g.label"

step "7/10  Oyuncular: track slot'ları kişi değil" \
"46 slot var ama sahada 22 oyuncu. Slot bir tracklet: tracker birini kaybedip bulunca yeni slot açabilir, kimlik değişebilir. Bildiğin şey konum, hız ve takım. Frame başına kaç nesne izleniyor:" \
"SELECT t.side AS takim, count(DISTINCT p.slot) AS kullanilan_slot,
        round(count(*) / count(DISTINCT p.frame), 1) AS frame_basina_oyuncu,
        round(avg(p.speed), 2) AS ort_hiz_ms
 FROM ham.oyuncular p JOIN ham.slotlar t USING (source, slot)
 WHERE p.source = 'tactical' AND p.frame BETWEEN 11185 AND 18684
 GROUP BY t.side ORDER BY t.side"

step "8/10  Smart Tagging: otomatik taktik etiketler" \
"Metrica'nın videodan otomatik çıkardığı fazlar ve duran toplar. Ground truth değil, hata içerir; ama her fazın takımı var ve her duran top bir ölü top dönemini bitirir. Faz possession demek değil." \
"SELECT code, count(*) AS adet, round(avg(end_s - start_s), 1) AS ort_sure_s,
        string_agg(DISTINCT team, ', ') AS takim_degerleri
 FROM ham.smart_tagging GROUP BY code ORDER BY adet DESC"

step "9/10  Homography: saha <-> video pikseli" \
"Her frame için 3x3 matris; saha koordinatını videodaki piksele çevirir. Tactical'da her frame geçerli; broadcast'ta tekrar, yakın çekim ve seyirci planlarında yok. İleride hatalı frame'leri videoda göstermek için lazım olacak." \
"SELECT source, round(avg(valid) * 100, 1) AS gecerli_yuzde,
        round(median(reprojection_error), 2) AS medyan_hata
 FROM ham.homografi GROUP BY source ORDER BY source"

step "10/10  Baseline nerede yanılıyor" \
"Satır = gerçek, sütun = tahmin, değer = frame sayısı. Baseline D'yi sadece top görünmediğinde söylüyor, o yüzden ölü topları kaçırıp oynanan topu ölü sanıyor. Model geliştirirken buradan başla." \
"PIVOT (SELECT gt, pred, frames FROM degerlendirme.karisiklik
        WHERE game = 'BAR-ATH' AND run_name = 'baseline_smooth50')
 ON pred USING sum(frames) GROUP BY gt ORDER BY gt"

echo
echo "Bitti. Dashboard: dac serve --dir possession --open    Model: model/predict.py"
