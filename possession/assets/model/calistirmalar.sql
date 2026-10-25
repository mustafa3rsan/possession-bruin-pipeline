/* @bruin
name: model.calistirmalar
type: duckdb.sql
description: "Bütün run'ların kaydı, her run için bir satır; hangi kodla ve hangi parametrelerle çalıştığı."

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
