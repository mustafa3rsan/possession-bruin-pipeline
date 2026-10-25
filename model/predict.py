"""Pipeline'ın çalıştırdığı model. Değişikliği burada yap, sonra yeni bir isimle çalıştır:
bruin run --workers 1 --var 'run_name="yeni_isim"' possession/

predict(con, game) bir maç için temiz.top ve temiz.oyuncular'ı okuyor, her frame için bir satır
döndürüyor: frame (0..n_frames-1) ve label (H, A, D ya da X). Aynı kod her maçta çalışıyor.
PARAMS her run ile birlikte kaydediliyor, hangi ayarla çalıştığını sonra görebilelim diye.
"""

import numpy as np
import pandas as pd

HOME, AWAY, NOBODY = 0, 1, -1

PARAMS = {"window": 50}

NEAREST_PLAYER_SQL = """
SELECT b.frame,
       arg_min(p.side, [power(p.x * $length - b.x * $length, 2) + power(p.y * $width - b.y * $width, 2), p.slot]) AS side
FROM temiz.top b
JOIN temiz.oyuncular p ON p.game = b.game AND p.frame = b.frame
WHERE b.game = $game AND b.x IS NOT NULL
GROUP BY b.frame
"""


# smooth() organizatörün starter/baseline.py dosyasından kopya, MIT Lisansı, (c) 2026-2027 Metrica Sports.
def smooth(codes, window):
    """Her frame için önündeki ve arkasındaki `window` frame'de çoğunluk hangi takımdaysa onu seçiyor; kimse yoksa D."""
    if window <= 0:
        return np.where(codes == HOME, "H", np.where(codes == AWAY, "A", "D"))

    home_cumulative = np.concatenate(([0], np.cumsum(codes == HOME)))
    away_cumulative = np.concatenate(([0], np.cumsum(codes == AWAY)))

    index = np.arange(len(codes))
    low = np.maximum(0, index - window)
    high = np.minimum(len(codes), index + window + 1)
    home = home_cumulative[high] - home_cumulative[low]
    away = away_cumulative[high] - away_cumulative[low]

    labels = np.full(len(codes), "D", dtype="<U1")
    seen = (home + away) > 0
    labels[seen] = np.where(home[seen] >= away[seen], "H", "A")
    return labels


def predict(con, game):
    n_frames, length, width = con.execute(
        "SELECT n_frames, pitch_length, pitch_width FROM temiz.maclar WHERE game = ?", [game]).fetchone()
    nearest = con.execute(NEAREST_PLAYER_SQL, {"game": game, "length": length, "width": width}).df()
    codes = np.full(n_frames, NOBODY, dtype=np.int8)
    codes[nearest["frame"].values] = np.where(nearest["side"].values == "H", HOME, AWAY)
    return pd.DataFrame({"frame": np.arange(n_frames), "label": smooth(codes, PARAMS["window"])})
