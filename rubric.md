# Rubric — `task/player-movement/solution`

## Features added

1. `scripts/player_movement.gd` — opponent-relative ground movement for Kestrel: the fight frame is rebuilt every frame so forward is always straight at the opponent and back is straight away, and because the fighter is re-aimed each frame, holding a strafe walks an arc around the opponent rather than a straight line.
2. Tuned feel through exports — separate advance (4.6), retreat (3.4) and strafe (3.8) speeds, acceleration/deceleration ramps, and yaw-toward-opponent at 720°/s carrying the 12° cheat that keeps faces rolled toward the camera.
3. Kinematic constraints and input — ring-out bounds clamp, minimum separation so "toward the opponent" stays well defined, fixed ground height; WASD + arrow keys added to `project.godot` and the script wired onto Kestrel in `arena.tscn` with Ironjaw as its opponent.
