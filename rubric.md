# Rubric — `task/camera-movement/solution`

## Features added

1. `scripts/fight_camera.gd` on `MainCamera` — keeps both fighters framed by holding their midpoint at screen centre and dollying along a single fixed view axis, which supplies the up/down travel as well as the in/out; the rotation is read once in `_ready()` and never written back, so the authored viewing angle is permanent.
2. The dolly distance is solved rather than tuned — each sampled body point (feet and crown of both fighters) rearranges to a lower bound on distance, so zooming in as they close and out as they separate is a consequence of the geometry, not a rule; keeping the camera off the stage is expressed as one more bound on the same axis, so it can only widen the shot.
3. Robustness details — the aspect ratio is read live so framing survives a resize, zoom-out eases far faster than zoom-in so a pull-out never crops, and the margins are sized to absorb the focus lag. Settled range is 6.1 → 26.9 units; verified headless over ten static extremes at three aspect ratios and a 2107-frame motion sweep against the real movement systems.
