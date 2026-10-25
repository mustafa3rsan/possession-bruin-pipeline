"""@bruin
name: model.son_calistirma
image: python:3.11
connection: possession
description: "Son run'ın adı, zamanı, PARAMS'ı ve o anki model kodu. Bir skoru hangi kodun ürettiğini sonradan görebilelim diye."

materialization:
  type: table
  strategy: create+replace

@bruin"""

import json
import os
import sys
from datetime import datetime, timezone

import pandas as pd

sys.path.insert(0, os.getcwd())
from model.predict import PARAMS  # noqa: E402


def materialize():
    with open(os.path.join(os.getcwd(), "model", "predict.py")) as handle:
        source = handle.read()
    return pd.DataFrame([{
        "run_name": json.loads(os.environ["BRUIN_VARS"])["run_name"],
        "created_at": datetime.now(timezone.utc).replace(tzinfo=None),
        "params": json.dumps(PARAMS, sort_keys=True),
        "model_source": source,
    }])
