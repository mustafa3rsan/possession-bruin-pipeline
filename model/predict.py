"""The model the pipeline runs. Change it here, then bruin run --var 'run_name="<new_name>"' possession/.

predict(con, game) gets a DuckDB connection and one game from temiz.maclar, reads temiz.top and
temiz.oyuncular for that game, and returns one row per frame: frame (0..n_frames-1) and label
(H, A, D or X). The same code runs on every game. PARAMS is stored with every run.
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


# smooth() is copied from the organisers' starter/baseline.py, MIT Licence, (c) 2026-2027 Metrica Sports.
def smooth(codes, window):
    """Majority vote over a centred window of +/- `window` frames. D where nobody has the ball."""
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
