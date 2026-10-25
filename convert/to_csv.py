"""Convert every game's provided XML and TXT files into the CSVs the Bruin pipeline seeds from.

    python convert/to_csv.py            # writes data/csv/*.csv, skips the ones already there
    python convert/to_csv.py --force    # rewrites all of them

A game is every <GAME>_tactical_atd.txt under <data>/tactical; its broadcast files are used when
they exist, and evaluation/gt/<GAME>_possession_gt_public.csv when it exists. Every CSV starts
with a game column. Frames are video frames counting from 0, the submission index: an ATD frame_id
is video_frame + 1. Coordinates are copied as text, unchanged, so nothing is lost to a float round
trip.
"""

import argparse
import csv
import os
import re
import sys
import xml.etree.ElementTree as ET

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
# The organisers' bundle: <data>/tactical and <data>/broadcast, one file per asset named <GAME>_<source><suffix>.
DATA_DIR = os.environ.get("MTAH_DATA_DIR") or os.path.join(ROOT, "data")
SOURCES = {
    "tactical": {"assets": ("video", "atd_meta", "atd_raw", "homography", "smart_tagging")},
    "broadcast": {"assets": ("video", "atd_meta", "atd_raw", "homography")},
}
SUFFIXES = {
    "video": ".mp4",
    "atd_meta": "_atd.xml",
    "atd_raw": "_atd.txt",
    "homography": "_homography.csv",
    "smart_tagging": "_smart_tagging.xml",
}

# Always inside the repository, where the seeds look, even when MTAH_DATA_DIR points elsewhere.
OUT_DIR = os.path.join(ROOT, "data", "csv")
GT_DIR = os.path.join(ROOT, "evaluation", "gt")
GAME_FILE = re.compile(r"^(.+)_tactical" + re.escape(SUFFIXES["atd_raw"]) + "$")


def snake(name):
    return re.sub(r"[^a-z0-9]+", "_", name.strip().lower()).strip("_")


def find_games():
    folder = os.path.join(DATA_DIR, "tactical")
    names = os.listdir(folder) if os.path.isdir(folder) else []
    games = sorted(match.group(1) for match in map(GAME_FILE.match, names) if match)
    if not games:
        sys.exit("no <GAME>_tactical{} in {}; see DATA.md or set MTAH_DATA_DIR".format(
            SUFFIXES["atd_raw"], folder))
    return games


def asset_path(game, source, asset):
    return os.path.join(DATA_DIR, source, "{}_{}{}".format(game, source, SUFFIXES[asset]))


def sources_with(asset):
    """(game, source, path) for every game and source that provides the asset."""
    found = []
    for game in find_games():
        for source in SOURCES:
            path = asset_path(game, source, asset)
            if asset in SOURCES[source]["assets"] and os.path.isfile(path):
                found.append((game, source, path))
    return found


def atd_root(game, source="tactical"):
    return ET.parse(asset_path(game, source, "atd_meta")).getroot()


def frame_rate(root):
    return float(root.find(".//GlobalConfig/FrameRate").text)


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
    print("  {:<16} {:>9} rows".format(name, count))


def games_table():
    rows = []
    for game in find_games():
        root = atd_root(game)
        field = root.find(".//FieldSize")
        with open(asset_path(game, "tactical", "atd_raw")) as handle:
            n_frames = sum(1 for _ in handle)
        rows.append([game, n_frames, frame_rate(root), field.findtext("Width"), field.findtext("Height"),
                     os.path.isfile(asset_path(game, "broadcast", "atd_raw"))])
    write("games", ["game", "n_frames", "fps", "pitch_length", "pitch_width", "has_broadcast"], rows)


def gt_public():
    def rows():
        for game in find_games():
            path = os.path.join(GT_DIR, "{}_possession_gt_public.csv".format(game))
            if not os.path.isfile(path):
                continue
            with open(path, newline="") as handle:
                for row in csv.DictReader(handle):
                    yield [game, row["frame"], row["label"]]

    write("gt_public", ["game", "frame", "label"], rows())


def smart_tagging():
    games = [(game, ET.parse(path).getroot()) for game, _, path in sources_with("smart_tagging")]
    groups = []
    for _, root in games:
        for label in root.iter("label"):
            group = snake(label.findtext("group"))
            if group not in groups:
                groups.append(group)

    def rows():
        for game, root in games:
            fps = frame_rate(atd_root(game))
            for instance in root.iter("instance"):
                start_s, end_s = float(instance.findtext("start")), float(instance.findtext("end"))
                tags = {snake(label.findtext("group")): label.findtext("text")
                        for label in instance.findall("label")}
                yield ([game, int(instance.findtext("ID")), instance.findtext("code"), start_s, end_s,
                        int(round(start_s * fps)), int(round(end_s * fps))]
                       + [tags.get(group) for group in groups])

    write("smart_tagging", ["game", "id", "code", "start_s", "end_s", "start_frame", "end_frame"] + groups,
          rows())


def atd_meta():
    teams, tracks, parameters = [], [], []
    for game, source, path in sources_with("atd_meta"):
        root = ET.parse(path).getroot()
        team_ids = [team.get("id") for team in root.iter("Team")]
        side = {team_ids[0]: "H", team_ids[1]: "A"}
        for team in root.iter("Team"):
            teams.append([game, source, team.get("id"), team.findtext("Name"), side[team.get("id")]])
        for slot, player in enumerate(root.iter("Player"), start=1):
            tracks.append([game, source, slot, player.get("id"), player.findtext("Name"),
                           player.findtext("ShirtNumber"), player.get("teamId"),
                           side[player.get("teamId")]])
        for scope, owner_tag in (("global", "ProviderGlobalParameters"),
                                 ("session", "ProviderSessionParameters"),
                                 ("team", "Team"), ("player", "Player")):
            for owner in root.iter(owner_tag):
                for parameter in owner.iter("ProviderParameter"):
                    parameters.append([game, source, scope, owner.get("id"),
                                       parameter.findtext("Name"), parameter.findtext("Value")])
        field = root.find(".//FieldSize")
        for name in ("Width", "Height"):
            parameters.append([game, source, "match", None, "FieldSize" + name, field.findtext(name)])
        parameters.append([game, source, "match", None, "FrameRate",
                           root.find(".//GlobalConfig/FrameRate").text])

    write("teams", ["game", "source", "team_id", "name", "side"], teams)
    write("tracks", ["game", "source", "slot", "player_id", "name", "shirt_number", "team_id", "side"],
          tracks)
    write("atd_parameters", ["game", "source", "scope", "owner_id", "name", "value"], parameters)


def nan_to_empty(value):
    return "" if value[:1] == "N" else value


def atd_raw():
    def ball_rows():
        for game, source, path in sources_with("atd_raw"):
            with open(path) as handle:
                for line in handle:
                    frame_id, _, ball = line.rstrip("\n").split(":")
                    x, y, s = (nan_to_empty(v) for v in ball.split(","))
                    yield [game, source, int(frame_id) - 1, x, y, s]

    def player_rows():
        for game, source, path in sources_with("atd_raw"):
            with open(path) as handle:
                for line in handle:
                    frame_id, players, _ = line.rstrip("\n").split(":")
                    frame = int(frame_id) - 1
                    for slot, group in enumerate(players.split(";"), start=1):
                        if group[:1] == "N":
                            continue
                        x, y, s = (nan_to_empty(v) for v in group.split(","))
                        yield [game, source, frame, slot, x, y, s]

    write("ball", ["game", "source", "frame", "x", "y", "speed"], ball_rows())
    write("players", ["game", "source", "frame", "slot", "x", "y", "speed"], player_rows())


def homography():
    def rows():
        for game, source, path in sources_with("homography"):
            with open(path, newline="") as handle:
                reader = csv.reader(handle)
                next(reader)
                for row in reader:
                    yield [game, source] + row

    (_, _, first), = sources_with("homography")[:1]
    with open(first, newline="") as handle:
        header = next(csv.reader(handle))
    write("homography", ["game", "source"] + header, rows())


# Keyed by the last file each step writes, so an interrupted step is redone on the next run.
STEPS = {
    "games": games_table,
    "gt_public": gt_public,
    "smart_tagging": smart_tagging,
    "atd_parameters": atd_meta,
    "players": atd_raw,
    "homography": homography,
}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--force", action="store_true", help="rewrite CSVs that already exist")
    args = parser.parse_args()

    os.makedirs(OUT_DIR, exist_ok=True)
    print("writing to {}".format(OUT_DIR))
    for marker, step in STEPS.items():
        if args.force or not os.path.isfile(os.path.join(OUT_DIR, marker + ".csv")):
            step()
        else:
            print("  {:<16} exists, skipped".format(marker))
