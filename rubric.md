# Rubric — `task/character-model/solution`

## Features added

1. Two humanoid fighter scenes built from Godot primitives — `fighter_player.tscn` (Kestrel, lean/cool blue) and `fighter_cpu.tscn` (Ironjaw, broad/warm crimson), visually distinct, with head, face, hair, neck, torso, shoulders, arms, hands with individual fingers, legs, feet and clothing.
2. Full `Node3D` joint rig at anatomical pivots plus 14 character materials, so future animation only rotates joints.
3. Both placed in the arena facing each other at X = ±3.6, with a per-fighter fill light each.

## Errors that must not be reproduced

```
Line 18:Cannot assign a value of type "hand.gd.Side" as "Side".
Line 18:Cannot assign a value of type hand.gd.Side to variable "side" with specified type Side.
```

The AI model should not reproduce these code errors.
