"""Convert the Metrica sample games in external_data/metrica into the CSVs the pipeline seeds from.

    python convert/metrica_to_csv.py            # writes data/csv/metrica/*.csv, skips if present
    python convert/metrica_to_csv.py --force

Frames count from 0: a Metrica Frame is frame + 1. Slots number the home players first, then the
away players, in the order of the tracking files. The labels are derived from the event data, see
external_data/metrica/SOURCE.md.
"""

import argparse
import csv
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC_DIR = os.path.join(ROOT, "external_data", "metrica")
OUT_DIR = os.path.join(ROOT, "data", "csv", "metrica")
GAMES = (1, 2)

OWNER_TYPES = {"PASS", "RECOVERY", "SET PIECE", "SHOT"}
DEAD_AT_START = {"FAULT RECEIVED"}
DEAD_SUBTYPES = ("OFFSIDE", "HAND BALL", "END HALF", "REFEREE HIT")


def game_path(game, suffix):
    return os.path.join(SRC_DIR, "Sample_Game_{}".format(game),
                        "Sample_Game_{}_{}".format(game, suffix))


def number(value):
    return "" if value in ("", "NaN", "nan") else value


def read_tracking(game, side):
    """(player ids, rows of [frame, [(x, y) per player], (ball x, ball y)])."""
    with open(game_path(game, "RawTrackingData_{}_Team.csv".format(side)), newline="") as handle:
        reader = csv.reader(handle)
        next(reader)
        next(reader)
        header = next(reader)
        players = [name for name in header[3:-2] if name]
        rows = []
        for index, row in enumerate(reader):
            frame = int(row[1]) - 1
            if frame != index:
                raise ValueError("game {} {}: frames are not contiguous at row {}".format(game, side, index))
            values = [number(v) for v in row[3:]]
            pairs = [(values[i], values[i + 1]) for i in range(0, len(values), 2)]
            rows.append((frame, pairs[:-1], pairs[-1]))
    return players, rows


def dead_frame(event):
    kind, subtype = event["Type"], event["Subtype"]
    start, end = int(event["Start Frame"]), int(event["End Frame"])
    end = end if end > 0 else start
    if kind == "BALL OUT":
        return end
    if kind == "SHOT" and ("OUT" in subtype or "GOAL" in subtype):
        return end
    if kind in DEAD_AT_START:
        return start
    if kind == "BALL LOST" and any(s in subtype for s in DEAD_SUBTYPES):
        return start
    return None


def event_labels(game, n_frames):
    """Per-frame H/A/D/X from the event stream. A contested or loose ball keeps the last owner."""
    with open(game_path(game, "RawEventsData.csv"), newline="") as handle:
        events = list(csv.DictReader(handle))
    halves = {}
    for event in events:
        halves.setdefault(event["Period"], []).append(event)

    labels = ["X"] * n_frames
    for half in halves.values():
        changes = []
        for order, event in enumerate(half):
            if event["Type"] in OWNER_TYPES and event["Team"] in ("Home", "Away"):
                changes.append((int(event["Start Frame"]), order,
                                "H" if event["Team"] == "Home" else "A"))
            frame = dead_frame(event)
            if frame is not None:
                changes.append((frame, order + 0.5, "D"))
        changes.sort()

        last = max(max(int(e["Start Frame"]), int(e["End Frame"])) for e in half)
        for (frame, _, label), (next_frame, _, _) in zip(changes, changes[1:] + [(last + 1, 0, "")]):
            for index in range(max(frame - 1, 0), min(next_frame - 1, n_frames)):
                labels[index] = label
    return labels


def write(name, header, rows):
    path = os.path.join(OUT_DIR, name + ".csv")
    tmp = path + ".tmp"
    count = 0
    with open(tmp, "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for row in rows:
            writer.writerow(row)
            count += 1
    os.replace(tmp, path)
    print("  metrica/{:<16} {:>9} rows".format(name, count))


def convert():
    tracks, balls, players, labels = [], [], [], []
    for game in GAMES:
        name = "metrica_{}".format(game)
        home_ids, home = read_tracking(game, "Home")
        away_ids, away = read_tracking(game, "Away")
        if len(home) != len(away):
            raise ValueError("game {}: home and away tracking differ in length".format(game))

        ids = home_ids + away_ids
        sides = ["H"] * len(home_ids) + ["A"] * len(away_ids)
        tracks += [[name, slot, player_id, side]
                   for slot, (player_id, side) in enumerate(zip(ids, sides), start=1)]

        for (frame, home_xy, ball), (_, away_xy, _) in zip(home, away):
            x, y = ball if "" not in ball else ("", "")
            balls.append([name, frame, x, y, ""])
            for slot, (px, py) in enumerate(home_xy + away_xy, start=1):
                if px and py:
                    players.append([name, frame, slot, px, py, ""])

        labels += [[name, frame, label] for frame, label in enumerate(event_labels(game, len(home)))]

    write("tracks", ["game", "slot", "player_id", "side"], tracks)
    write("ball", ["game", "frame", "x", "y", "speed"], balls)
    write("ground_truth", ["game", "frame", "label"], labels)
    write("players", ["game", "frame", "slot", "x", "y", "speed"], players)


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="rewrite CSVs that already exist")
    args = parser.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    if args.force or not os.path.isfile(os.path.join(OUT_DIR, "players.csv")):
        convert()
    else:
        print("  metrica/          exists, skipped")
