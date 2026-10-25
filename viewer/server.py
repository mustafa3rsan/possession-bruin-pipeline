"""Local viewer of both videos and a radar of temiz.top + temiz.oyuncular: python3 viewer/server.py"""

import json
import os
import re
from decimal import Decimal
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

import duckdb

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DB_PATH = os.path.join(ROOT, "possession.duckdb")
PAGE = os.path.join(ROOT, "viewer", "index.html")
VIDEO_DIR = os.path.join(ROOT, "data", "videos")
SOURCES = ("tactical", "broadcast")
PORT = 8765
MAX_CHUNK = 8 * 1024 * 1024
MAX_WINDOW = 1000

H_COLUMNS = ["h00", "h01", "h02", "h10", "h11", "h12", "h20", "h21", "h22"]


def query(sql, params):
    # A fresh read-only connection per request, so the viewer never blocks ./run.sh from writing.
    with duckdb.connect(DB_PATH, read_only=True) as con:
        cursor = con.execute(sql, params)
        names = [d[0] for d in cursor.description]
        rows = cursor.fetchall()
    return {name: [row[i] for row in rows] for i, name in enumerate(names)}


def video_path(game, source):
    return os.path.join(VIDEO_DIR, source, "{}_{}.mp4".format(game, source))


def competition_games():
    return query("SELECT game FROM temiz.maclar WHERE dataset = 'competition' ORDER BY game", [])["game"]


def meta(game):
    games = competition_games()
    game = game if game in games else games[0]
    info = query("SELECT n_frames, fps, pitch_length, pitch_width FROM temiz.maclar WHERE game = ?", [game])
    first = query("SELECT min(start_frame) AS f FROM temiz.devreler WHERE game = ?", [game])
    broadcast = query("SELECT count(*) AS n FROM ham.homografi WHERE game = ? AND source = 'broadcast'", [game])
    sync = query('SELECT broadcast_start, broadcast_end, "offset" FROM temiz.yayin_senkronu WHERE game = ? '
                 'ORDER BY broadcast_start', [game])
    live = query("""
        SELECT min(frame) AS start, max(frame) AS stop FROM (
          SELECT frame, valid, frame - row_number() OVER (PARTITION BY valid ORDER BY frame) AS grp
          FROM ham.homografi WHERE game = ? AND source = 'broadcast')
        WHERE valid = 1 GROUP BY grp ORDER BY start""", [game])
    return {
        "game": game,
        "games": games,
        "videos": {source: os.path.isfile(video_path(game, source)) for source in SOURCES},
        "fps": info["fps"][0],
        "first_frame": first["f"][0] or 0,
        "n_frames": info["n_frames"][0],
        "pitch_length": info["pitch_length"][0],
        "pitch_width": info["pitch_width"][0],
        "broadcast_frames": broadcast["n"][0],
        "sync": [{"start": a, "end": b, "offset": o}
                 for a, b, o in zip(sync["broadcast_start"], sync["broadcast_end"], sync["offset"])],
        "broadcast_live": list(zip(live["start"], live["stop"])),
    }


def window(game, start, count):
    stop = start + count - 1
    ball = query("""
        SELECT frame, x, y FROM temiz.top
        WHERE game = ? AND frame BETWEEN ? AND ? ORDER BY frame""", [game, start, stop])
    players = query("""
        SELECT frame, slot, side, x, y FROM temiz.oyuncular
        WHERE game = ? AND frame BETWEEN ? AND ? ORDER BY frame, slot""", [game, start, stop])
    homography = query("""
        SELECT frame, {}, reprojection_error, valid FROM ham.homografi
        WHERE game = ? AND source = 'tactical' AND frame BETWEEN ? AND ? ORDER BY frame""".format(
        ", ".join(H_COLUMNS)), [game, start, stop])
    broadcast_homography = query("""
        SELECT h.frame + s."offset" AS frame, h.frame AS broadcast_frame, {}, h.valid
        FROM ham.homografi h
        JOIN temiz.yayin_senkronu s ON s.game = h.game AND h.frame BETWEEN s.broadcast_start AND s.broadcast_end
        WHERE h.game = ? AND h.source = 'broadcast' AND h.frame + s."offset" BETWEEN ? AND ?
        ORDER BY 1""".format(", ".join("h." + c for c in H_COLUMNS)), [game, start, stop])
    raw_ball = query("""
        SELECT frame, x, y FROM ham.top
        WHERE game = ? AND source = 'tactical' AND frame BETWEEN ? AND ? ORDER BY frame""", [game, start, stop])
    raw_players = query("""
        SELECT p.frame, p.slot, t.side, p.x, p.y FROM ham.oyuncular p JOIN ham.slotlar t USING (game, source, slot)
        WHERE p.game = ? AND p.source = 'tactical' AND p.frame BETWEEN ? AND ? ORDER BY p.frame, p.slot""",
                        [game, start, stop])
    return {"start": start, "count": count, "ball": ball, "players": players, "homography": homography,
            "broadcast_homography": broadcast_homography, "raw_ball": raw_ball, "raw_players": raw_players}


def clean_json(value):
    if isinstance(value, float) and value != value:
        return None
    if isinstance(value, Decimal):
        return float(value)
    if isinstance(value, dict):
        return {k: clean_json(v) for k, v in value.items()}
    if isinstance(value, list):
        return [clean_json(v) for v in value]
    return value


class Handler(BaseHTTPRequestHandler):
    def log_message(self, fmt, *args):
        pass

    def send_json(self, payload, status=200):
        body = json.dumps(clean_json(payload), allow_nan=False).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_file(self, path, content_type):
        with open(path, "rb") as handle:
            body = handle.read()
        self.send_response(200)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def send_video(self, path):
        size = os.path.getsize(path)
        match = re.match(r"bytes=(\d*)-(\d*)", self.headers.get("Range", ""))
        if match and (match.group(1) or match.group(2)):
            if match.group(1):
                start = int(match.group(1))
                end = int(match.group(2)) if match.group(2) else size - 1
            else:
                start, end = size - int(match.group(2)), size - 1
            end = min(end, start + MAX_CHUNK - 1, size - 1)
            self.send_response(206)
            self.send_header("Content-Range", "bytes {}-{}/{}".format(start, end, size))
        else:
            start, end = 0, min(MAX_CHUNK, size) - 1
            self.send_response(206)
            self.send_header("Content-Range", "bytes {}-{}/{}".format(start, end, size))
        self.send_header("Content-Type", "video/mp4")
        self.send_header("Accept-Ranges", "bytes")
        self.send_header("Content-Length", str(end - start + 1))
        self.end_headers()
        with open(path, "rb") as handle:
            handle.seek(start)
            remaining = end - start + 1
            try:
                while remaining > 0:
                    block = handle.read(min(1024 * 1024, remaining))
                    if not block:
                        break
                    self.wfile.write(block)
                    remaining -= len(block)
            except (BrokenPipeError, ConnectionResetError):
                pass

    def do_GET(self):
        url = urlparse(self.path)
        try:
            if url.path in ("/", "/index.html"):
                self.send_file(PAGE, "text/html; charset=utf-8")
            elif url.path.startswith("/video/"):
                parts = url.path[len("/video/"):].split("/")
                if len(parts) == 2 and parts[0] in competition_games() and parts[1] in SOURCES \
                        and os.path.isfile(video_path(*parts)):
                    self.send_video(video_path(*parts))
                else:
                    self.send_error(404)
            elif url.path == "/api/meta":
                self.send_json(meta(parse_qs(url.query).get("game", [""])[0]))
            elif url.path == "/api/window":
                args = parse_qs(url.query)
                start = max(0, int(args["start"][0]))
                count = min(MAX_WINDOW, max(1, int(args["count"][0])))
                self.send_json(window(args["game"][0], start, count))
            else:
                self.send_error(404)
        except duckdb.IOException as error:
            self.send_json({"error": "possession.duckdb is busy (is ./run.sh running?): {}".format(error)}, 503)
        except (BrokenPipeError, ConnectionResetError):
            pass


if __name__ == "__main__":
    print("videos are read from {}/<source>/<GAME>_<source>.mp4".format(VIDEO_DIR))
    server = ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print("viewer: http://localhost:{}".format(PORT))
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        pass
