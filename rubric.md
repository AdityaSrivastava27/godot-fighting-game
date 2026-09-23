# Rubric — `task/movement-animation/solution`

## Features added

1. `animations/kestrel_locomotion.tres` — five hand-keyed looping clips (idle 2.6s, walk_forward 0.72s, walk_back 0.8s, hop_left and hop_right 0.52s) authored as one shared orthodox stance with a different motion laid over each, so any blend of two is a blend of one pose; no root motion, and every in-rig hip offset returns to zero.
2. `AnimationPlayer` + `AnimationTree` on `fighter_player.tscn` driving a `BlendSpace2D` — idle at the origin with the four travel clips pinned at ±1 on the strafe and advance axes, fixed triangles bounding the reachable set to the diamond, and `sync` off so the long idle cannot be dragged onto a hop's clock.
3. `player_movement.gd` writes `parameters/blend_position` from the velocity that survived the constraints, projected onto that same diamond — no state machine and no transition table, so direction changes, diagonals and coasting back to idle all fall out of the easing the movement already had.
