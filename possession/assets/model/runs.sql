/* @bruin
name: model.runs
type: duckdb.sql
description: One row per run name, with the PARAMS and model/predict.py source that produced it.

depends:
  - model.latest_run

materialization:
  type: table
  strategy: delete+insert
  incremental_key: run_name

columns:
  - name: run_name
    type: varchar
    checks:
      - name: unique
@bruin */

SELECT run_name, created_at, params, model_source
FROM model.latest_run
