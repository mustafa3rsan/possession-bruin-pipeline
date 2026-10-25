"""@bruin
name: model.son_calistirma
image: python:3.11
connection: possession
description: "Son run'ın adı, zamanı, PARAMS'ı, o anki model kodu ve temizlik kodu (temiz katmanındaki bütün dosyalar). Bir skoru hangi kodun ürettiğini sonradan görebilelim diye."

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

TEMIZ_DIR = os.path.join(os.getcwd(), "possession", "assets", "temiz")


def materialize():
    with open(os.path.join(os.getcwd(), "model", "predict.py")) as handle:
        source = handle.read()
    cleaning = {}
    for name in sorted(n for n in os.listdir(TEMIZ_DIR) if n.endswith((".sql", ".py"))):
        with open(os.path.join(TEMIZ_DIR, name)) as handle:
            cleaning[name] = handle.read()
    return pd.DataFrame([{
        "run_name": json.loads(os.environ["BRUIN_VARS"])["run_name"],
        "created_at": datetime.now(timezone.utc).replace(tzinfo=None),
        "params": json.dumps(PARAMS, sort_keys=True),
        "model_source": source,
        "temizlik_kodu": json.dumps(cleaning, ensure_ascii=False),
    }])
