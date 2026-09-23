# Rubric — `task/CPU-movement/solution`

## Features added

1. `scripts/fighter_movement.gd` — shared base class refactored out of `player_movement.gd`, holding the fight frame, acceleration, the ring-out and separation clamps, the facing and the locomotion blend hand-off; subclasses supply only `_read_intent()`, so the player and the CPU demonstrably run the same body with different heads.
2. `scripts/cpu_movement.gd` — combat-aware positioning for Ironjaw from two questions asked every frame: spacing holds a preferred distance (2.8, with a deadband and a ramp so it eases in rather than hunting) and mirroring matches the opponent's lateral travel to deny angle, both smoothed by a delta-correct reaction time. Positioning only: no attacks, blocking, reactions or difficulty tiers.
3. `animations/ironjaw_locomotion.tres` plus the `BlendSpace2D` on `fighter_cpu.tscn`, and the arena wiring that names each fighter as the other's opponent — so the CPU's animation is never chosen anywhere, it falls out of the velocity the constraints left.
