"""@bruin
name: temiz.yayin_senkronu
image: python:3.11
connection: possession
description: Where each part of a game's broadcast recording sits on its tactical timeline, tactical frame = broadcast frame + offset. Found by sliding the broadcast ball track along the tactical one on the live broadcast shots; a part ends where the broadcast was cut, BAR-ATH's at halftime.

secrets:
  - key: possession
    inject_as: POSSESSION_DB

depends:
  - ham.maclar
  - ham.top
  - ham.homografi

materialization:
  type: table
  strategy: create+replace

columns:
  - name: game
    type: varchar
  - name: broadcast_start
    type: integer
  - name: broadcast_end
    type: integer
  - name: offset
    type: integer
    description: tactical frame = broadcast frame + offset
  - name: shots
    type: integer
    description: Live broadcast shots that agreed on this offset
  - name: median_error_m
    type: double
    description: Median distance between the two ball tracks at this offset, in metres
@bruin"""

import json
import os
import warnings

import duckdb
import numpy as np
import pandas as pd

MIN_SHOT = 250
COARSE_STEP = 5
MAX_ERROR_M = 2.0
MIN_SHOTS_PER_PART = 3
SAME_OFFSET = 5


def ball(con, game, source, pitch):
    d = con.execute("""
        SELECT frame, coalesce(x, 'nan'::DOUBLE) AS x, coalesce(y, 'nan'::DOUBLE) AS y
        FROM ham.top WHERE game = ? AND source = ? ORDER BY frame""", [game, source]).fetchnumpy()
    xy = np.full((int(d["frame"].max()) + 1, 2), np.nan)
    xy[d["frame"]] = np.c_[d["x"], d["y"]] * pitch
    return xy


def live_shots(con, game, n_frames):
    d = con.execute("SELECT frame, valid FROM ham.homografi WHERE game = ? AND source = 'broadcast'",
                    [game]).fetchnumpy()
    valid = np.zeros(n_frames, dtype=int)
    valid[d["frame"]] = d["valid"] == 1
    edges = np.flatnonzero(np.diff(np.r_[0, valid, 0]))
    return [(a, b) for a, b in zip(edges[::2], edges[1::2]) if b - a >= MIN_SHOT]


def errors(tactical, broadcast, frames, offsets):
    """Median ball distance for each offset; inf where the tracks overlap on too few frames."""
    out = np.full(len(offsets), np.inf)
    for i in range(0, len(offsets), 5000):
        block = offsets[i:i + 5000]
        idx = frames[:, None] + block[None, :]
        inside = (idx >= 0) & (idx < len(tactical))
        t = tactical[np.clip(idx, 0, len(tactical) - 1)]
        dist = np.hypot(t[..., 0] - broadcast[frames, 0][:, None], t[..., 1] - broadcast[frames, 1][:, None])
        dist[~inside] = np.nan
        enough = np.isfinite(dist).mean(axis=0) > 0.5
        with warnings.catch_warnings():
            warnings.simplefilter("ignore", RuntimeWarning)
            med = np.nanmedian(dist, axis=0)
        out[i:i + len(block)] = np.where(enough, med, np.inf)
    return out


def best_offset(tactical, broadcast, a, b):
    seen = np.arange(a, b)[np.isfinite(broadcast[a:b, 0])]
    if len(seen) < MIN_SHOT // 2:
        return None
    coarse = np.arange(-len(broadcast), len(tactical), COARSE_STEP)
    err = errors(tactical, broadcast, seen[::25], coarse)
    guess = coarse[int(np.argmin(err))]
    fine = np.arange(guess - COARSE_STEP, guess + COARSE_STEP + 1)
    err = errors(tactical, broadcast, seen, fine)
    k = int(np.argmin(err))
    return int(fine[k]), float(err[k])


def sync(tactical, broadcast, shots):
    matched = []
    for a, b in shots:
        found = best_offset(tactical, broadcast, a, b)
        if found and found[1] <= MAX_ERROR_M:
            matched.append((a, b) + found)

    parts = []
    for shot in matched:
        if parts and abs(shot[2] - parts[-1][-1][2]) <= SAME_OFFSET:
            parts[-1].append(shot)
        else:
            parts.append([shot])
    parts = [p for p in parts if len(p) >= MIN_SHOTS_PER_PART]

    merged = []
    for part in parts:
        if merged and abs(np.median([s[2] for s in part]) - np.median([s[2] for s in merged[-1]])) <= SAME_OFFSET:
            merged[-1].extend(part)
        else:
            merged.append(part)

    rows = []
    for i, part in enumerate(merged):
        start = 0 if i == 0 else (merged[i - 1][-1][1] + part[0][0]) // 2
        end = len(broadcast) - 1 if i == len(merged) - 1 else (part[-1][1] + merged[i + 1][0][0]) // 2 - 1
        rows.append({
            "broadcast_start": int(start),
            "broadcast_end": int(end),
            "offset": int(round(np.median([s[2] for s in part]))),
            "shots": len(part),
            "median_error_m": float(np.median([s[3] for s in part])),
        })
    return rows


def materialize():
    rows = []
    with duckdb.connect(json.loads(os.environ["POSSESSION_DB"])["path"], read_only=True) as con:
        games = con.execute("SELECT game, pitch_length, pitch_width FROM ham.maclar WHERE has_broadcast "
                            "ORDER BY game").fetchall()
        for game, length, width in games:
            pitch = np.array([length, width])
            tactical, broadcast = ball(con, game, "tactical", pitch), ball(con, game, "broadcast", pitch)
            shots = live_shots(con, game, len(broadcast))
            rows += [{"game": game, **row} for row in sync(tactical, broadcast, shots)]
    columns = ["game", "broadcast_start", "broadcast_end", "offset", "shots", "median_error_m"]
    return pd.DataFrame(rows, columns=columns)
