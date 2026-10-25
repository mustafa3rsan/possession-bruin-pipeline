#!/usr/bin/env bash
# Metrica's two public sample games into external_data/metrica, unless they are already there.
set -euo pipefail
cd "$(dirname "$0")/.."
BASE=https://raw.githubusercontent.com/metrica-sports/sample-data/e706dd5/data
for game in 1 2; do
  for file in RawEventsData RawTrackingData_Away_Team RawTrackingData_Home_Team; do
    target="external_data/metrica/Sample_Game_${game}/Sample_Game_${game}_${file}.csv"
    if [ ! -f "$target" ]; then
      mkdir -p "$(dirname "$target")"
      echo "  downloading $(basename "$target")"
      curl -fsSL "$BASE/Sample_Game_${game}/Sample_Game_${game}_${file}.csv" -o "$target.tmp"
      mv "$target.tmp" "$target"
    fi
  done
done
