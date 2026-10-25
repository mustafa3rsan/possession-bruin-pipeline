#!/usr/bin/env bash
# Run the model in model/predict.py under a name and score it: ./run.sh <run_name>
set -euo pipefail

if [ $# -ne 1 ]; then
  echo "usage: ./run.sh <run_name>   (letters, digits, _ . -; reusing a name replaces that run)" >&2
  exit 2
fi
if ! [[ "$1" =~ ^[A-Za-z0-9_.-]+$ ]]; then
  echo "run name must match ^[A-Za-z0-9_.-]+$" >&2
  exit 2
fi

cd "$(dirname "$0")"
if [ ! -f .bruin.yml ]; then
  cat > .bruin.yml <<'YML'
default_environment: default
environments:
  default:
    connections:
      duckdb:
        - name: possession
          path: possession.duckdb
        - name: possession_read
          path: possession.duckdb
          read_only: true
YML
fi
if head -c 200 data/csv/players.csv 2>/dev/null | grep -q "git-lfs.github.com/spec"; then
  echo "data/csv/players.csv is a Git LFS pointer, not the data. Run: git lfs install && git lfs pull" >&2
  exit 1
fi
python3 convert/to_csv.py
[ -f data/csv/metrica/players.csv ] || bash convert/fetch_metrica.sh
python3 convert/metrica_to_csv.py

# delete+insert on DuckDB neither creates a missing table nor adds new columns, so the first run, and
# the first run after the tables changed shape, rebuilds them all. That drops the earlier runs.
refresh=()
if ! bruin query --connection possession --query "SELECT game FROM degerlendirme.skorlar LIMIT 0" >/dev/null 2>&1; then
  refresh=(--full-refresh)
fi
bruin run --workers 1 "${refresh[@]+"${refresh[@]}"}" --var "run_name=\"$1\"" possession/
bruin query --connection possession --query "
  WITH per_game AS (PIVOT (SELECT run_name, game, round(spell_f1_mean, 4) AS f FROM degerlendirme.skorlar)
                    ON game USING any_value(f) GROUP BY run_name),
       metrica AS (SELECT run_name, round(avg(spell_f1_mean) FILTER (WHERE dataset = 'metrica sample'), 4) AS metrica_avg
                   FROM degerlendirme.skorlar GROUP BY run_name)
  SELECT * FROM metrica JOIN per_game USING (run_name) ORDER BY metrica_avg DESC NULLS LAST"
echo "spellF1 per game. Pick models on metrica_avg; a competition game's public window is a check, not a ranking."
echo "dashboard: dac serve --dir possession --open"
