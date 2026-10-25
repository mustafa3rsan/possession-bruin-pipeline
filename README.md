# Possession pipeline

A [Bruin](https://getbruin.com) pipeline for [More than a Hack 2027 – Phase 1: Ball Possession](https://github.com/metrica-sports/more-than-a-hack-2027): predict who has the ball (H, A, D, X) on every frame of a match's tactical video, and score each named run.

The match data is not here. It is licensed to enrolled participants only, so `data/` is ignored and the pipeline reads CSVs you generate from your own copy of the bundle.

## Layers

```
raw.*    seeds from data/csv/*.csv, one game column throughout
stg.*    games, halves (stg.periods), ball and players inside the halves, ground truth,
         broadcast-to-tactical sync (stg.broadcast_sync)
model.*  model/predict.py run under a name; model.predictions keeps every run
eval.*   per-frame and per-possession scores; eval.scores is one row per run and game
```

Nothing is specific to one match: frame counts, frame rate and pitch size come from each game's tracking metadata, the halves from Smart Tagging and tracking, the broadcast offset from the two ball tracks.

## Run

```bash
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

bruin run --workers 1 --var 'run_name="baseline"' possession/
bruin lineage possession/assets/eval/scores.sql
dac serve --dir possession --open
```

The seeds expect `data/csv/` (see the `path` of each asset under `possession/assets/raw`). `--workers 1` runs one step at a time, because DuckDB lets only one process write to the file.

## Credits

`evaluation/possession_metrics.py` and `smooth()` in `model/predict.py` are from the organisers' repository, MIT Licence, (c) 2026-2027 Metrica Sports.
