"""@bruin
name: eval.latest_spell_f1
image: python:3.11
connection: possession
description: This run's spellF1 per game from evaluation/possession_metrics.py, so it is the scorer's number exactly.

secrets:
  - key: possession
    inject_as: POSSESSION_DB

depends:
  - model.predictions
  - stg.ground_truth
  # Only so the two Python steps never hold possession.duckdb at the same time.
  - model.latest_run

materialization:
  type: table
  strategy: create+replace
@bruin"""

import json
import os
import sys

import duckdb
import pandas as pd

sys.path.insert(0, os.path.join(os.getcwd(), "evaluation"))
import possession_metrics as pm  # noqa: E402

BOOTSTRAP_DRAWS = 1000


def score(gt, pred):
    gt_codes, pred_codes = pm.label_codes(gt), pm.label_codes(pred)
    runs = pm.valid_runs(gt_codes)
    filled = pm.fill_abstentions(pred_codes, runs)
    spells = pm.spell_scores(gt_codes, filled, runs)
    low, high = pm.bootstrap_spell_f1(gt_codes, filled, runs, BOOTSTRAP_DRAWS)
    row = {"spell_f1_mean": spells["mean_f1"], "spell_bootstrap_low": low, "spell_bootstrap_high": high}
    for iou, scores in spells["per_iou"].items():
        row["spell_f1_iou_{:02d}".format(int(round(iou * 10)))] = scores["f1"]
    return row


def materialize():
    run_name = json.loads(os.environ["BRUIN_VARS"])["run_name"]
    rows = []
    with duckdb.connect(json.loads(os.environ["POSSESSION_DB"])["path"], read_only=True) as con:
        for (game,) in con.sql("SELECT DISTINCT game FROM stg.ground_truth ORDER BY game").fetchall():
            gt = con.execute("SELECT label FROM stg.ground_truth WHERE game = ? ORDER BY frame",
                             [game]).df()["label"].values
            pred = con.execute("SELECT label FROM model.predictions WHERE run_name = ? AND game = ? "
                               "ORDER BY frame", [run_name, game]).df()["label"].values
            rows.append({"run_name": run_name, "game": game, **score(gt, pred)})
    return pd.DataFrame(rows)
