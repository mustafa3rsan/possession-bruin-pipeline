/* @bruin
name: model.calistirmalar
type: duckdb.sql
description: One row per run name, with the PARAMS and model/predict.py source that produced it.

depends:
  - model.son_calistirma

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
FROM model.son_calistirma
