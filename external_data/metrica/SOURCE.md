# Metrica Sports sample data

Two anonymised full matches from Metrica's public sample repository:
https://github.com/metrica-sports/sample-data (commit `e706dd5`, 2021-04-15). `convert/fetch_metrica.sh`
downloads them here unchanged; they are not committed. The event definitions are
`documentation/events-definitions.pdf` in that repository.

- `Sample_Game_N_RawTrackingData_{Home,Away}_Team.csv`: player and ball positions, 0-1 on each axis,
  25 fps, pitch 105 x 68 m.
- `Sample_Game_N_RawEventsData.csv`: Metrica's event data, synchronised with the tracking.

These are other games than the competition match, which the competition rules allow, and the
organisers can access them at the link above.

## Possession labels

`convert/metrica_to_csv.py` derives one H/A/D/X label per frame from the event data, by algorithm,
not by hand:

- A `PASS`, `RECOVERY`, `SET PIECE` or `SHOT` gives the ball to the acting team from its start frame.
- `BALL OUT`, a shot that goes out or in, a `FAULT RECEIVED`, and a `BALL LOST` for offside, hand
  ball, end of half or hitting the referee make the ball dead (D) until the next owning event.
- A contested or loose ball keeps the last owner. Frames outside the two halves are X.

These labels follow Metrica's event definitions, not the competition's ground truth, so their
absolute scores differ from the competition's. They are used to compare model versions with each
other, not to predict the competition score.
