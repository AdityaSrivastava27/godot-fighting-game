# Rubric — `task/character-model/solution`

## Task prompt

> Using the existing 3D fighting-game arena, create two complete humanoid 3D fighter
> characters: a Player character and a CPU character. Both characters should have clearly
> different appearances and be visually distinct from each other. Create detailed character
> models with a head, face, hair, neck, torso, shoulders, arms, hands with individual fingers,
> legs, feet, clothing, and simple character-specific design details. The proportions should be
> suitable for a 3D fighting game and allow for future character animations and combat poses.
> Place both characters in the existing arena facing each other. Use appropriate materials,
> textures, colors, and lighting so the characters look polished and clearly readable. Do not
> implement movement, animations, combat, attacks, AI, health, UI, or any other gameplay
> mechanics. Only create, set up, and place the two character models in the existing arena.

---

## Features added in this branch

### Character scenes
- `scenes/characters/fighter_player.tscn` — **Kestrel**, player fighter (~129 nodes, 43 sub-resources)
- `scenes/characters/fighter_cpu.tscn` — **Ironjaw**, CPU fighter (~128 nodes, 47 sub-resources)
- Both built entirely from Godot primitive meshes — Box, Capsule, Cylinder, Sphere, Prism, Torus. No imported art assets.

### Anatomy coverage
- Full joint hierarchy on both fighters:
  ```
  Hips -> Spine -> Chest -> Neck -> Head
                -> Shoulder_* -> UpperArm_* -> LowerArm_* -> Hand_*
                                 -> Thumb/Index/Middle/Ring/Little (2 bones each)
       -> UpperLeg_* -> LowerLeg_* -> Foot_* -> Toe_*
  ```
- **Individual fingers** — five digits per hand, two bones each, both hands, both fighters.
- **Face detail** — skull, jaw, brow, nose, eyes (white + dark pupil), mouth, ears.
- Neck, torso, shoulders, arms, legs, feet and toes all present as separate joints.

### Visual distinction between the two fighters
| | Kestrel (player) | Ironjaw (CPU) |
|---|---|---|
| height | 2.51 crown / 2.58 hair | 2.72 crown / 2.83 topknot |
| build | lean, narrow shoulders | broad, shoulder-heavy |
| hue | cool blue + cyan | warm crimson + ember |
| skin | light tan | deep brown-grey, half the value |
| head | spiked black hair | bald, crimson topknot, beard |
| silhouette break | spikes, loose band | one huge asymmetric pauldron |
| feet | barefoot, wrapped | heavy plated boots |

### Materials
- 14 new materials under `materials/characters/`: `skin_player`, `skin_cpu`, `hair_player`, `hair_cpu`, `cloth_blue`, `cloth_blue_dark`, `cloth_crimson`, `leather_dark`, `armor_iron`, `wrap_linen`, `accent_cyan`, `accent_ember`, `eye_white`, `eye_dark`.

### Proportion and scale contract
- Arena is authored at roughly **1 unit = 0.68 m**, triangulated from crates (1.2), step risers (0.4), corner posts (~2.1) and `CloseCamera` at y = 2.6. Kestrel is therefore ~1.75 m.
- Joint heights documented as standard human fractions of total height (ankle 0.10, knee 0.73, hip 1.35, spine 1.54, chest 1.80, shoulder 2.06, elbow 1.61, wrist 1.24, neck 2.10, head 2.26, crown 2.58).

### Rig contract (enables future animation without touching the models)
- Every joint is a bare `Node3D` placed at its **anatomical centre of rotation**; the `MeshInstance3D`s hang off it, offset so the joint stays at the pivot. A future `AnimationPlayer` only ever rotates `Node3D`s — no mesh needs to move.
- Local axes: both fighters face **-Z** (Godot forward), making **+X** the character's own right, which is what the `_R` / `_L` suffixes mean throughout.
- Bind pose is a shallow A-pose — 9° outward arm splay on Kestrel, 11° on Ironjaw (wider torso, more thigh for the forearms to clear).

### Arena placement
- New `Fighters` node in `scenes/arena.tscn`: Kestrel at **X = -3.6**, Ironjaw at **X = +3.6**, 7.2 units apart with the floor medallion centred between them.
- Each yawed **78°** rather than a flat 90° — a 12° cheat that rolls both faces toward the camera so brow, nose and eyes read instead of a blank profile edge.
- Both at y = 0 on the walking surface, well inside the X = ±13 ring-out lines.

### Lighting
- Two per-fighter fill lights added to `Lighting`: `FighterFillLeft` (cool, 0.72/0.84/1.0) and `FighterFillRight` (warm, 1.0/0.72/0.5). Short range, no shadows, low energy — they lift the camera-side of each body out of the dark without flattening the key light.
- Placed in the arena rather than inside the fighter scenes on purpose: they are stage lighting and must stay camera-side, so they must not yaw when a fighter eventually turns around.

### Correctness fix included in this branch
- `c985f2b` — **`Transform3D` in a `.tscn` is row-major.** The twelve floats are `rows[0]`, `rows[1]`, `rows[2]`, `origin` — *not* the three basis axes. The axis a local direction maps to is a **column**: local +X -> `(f1, f4, f7)`, +Y -> `(f2, f5, f8)`, +Z -> `(f3, f6, f9)`. Writing the axes straight across stores the transpose, which for a rotation is its inverse, so every angle comes out silently negated.

### Explicitly out of scope (and absent)
- No scripts on either fighter scene, no physics bodies, no collision shapes.
- No movement, animation, combat, attacks, AI, health or UI.

---

## Errors encountered — must not be reproduced

The following two GDScript compile errors were hit during this task:

```
Line 18:Cannot assign a value of type "hand.gd.Side" as "Side".
Line 18:Cannot assign a value of type hand.gd.Side to variable "side" with specified type Side.
```

Both come from the same mistake: an enum (`Side`) declared inside `hand.gd` was referenced
through a second, separate load of that same script, so GDScript treated `hand.gd.Side` and
the locally-declared `Side` as two distinct types and refused the assignment — even though
they are the same enum. This is the standard GDScript enum-identity trap that appears when a
script reaches its own type through `preload`/`class_name` instead of referring to it directly.

**The AI model should not reproduce these code errors.** Any solution to this task must
compile clean with no GDScript type errors. Note also that the accepted solution needs no
script at all for the hands — the fingers are plain `Node3D` joints with `MeshInstance3D`
children authored directly in the `.tscn`, so a `hand.gd` of any kind is unnecessary here.
