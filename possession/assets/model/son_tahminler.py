"""@bruin
name: model.son_tahminler
image: python:3.11
connection: possession
description: This run's labels from model/predict.py for every game in temiz.maclar; model.tahminler keeps every run.

secrets:
  - key: possession
    inject_as: POSSESSION_DB

depends:
  - temiz.maclar
  - temiz.top
  - temiz.oyuncular

materialization:
  type: table
  strategy: create+replace

@bruin"""

import json
import os
import sys

import duckdb
import pandas as pd

sys.path.insert(0, os.getcwd())
from model.predict import predict  # noqa: E402


def materialize():
    run_name = json.loads(os.environ["BRUIN_VARS"])["run_name"]
    frames = []
    with duckdb.connect(json.loads(os.environ["POSSESSION_DB"])["path"], read_only=True) as con:
        for (game,) in con.sql("SELECT game FROM temiz.maclar ORDER BY game").fetchall():
            labels = predict(con, game)
            labels.insert(0, "game", game)
            frames.append(labels)
    labels = pd.concat(frames, ignore_index=True)
    labels.insert(0, "run_name", run_name)
    return labels
