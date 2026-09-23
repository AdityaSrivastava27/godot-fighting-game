# Dusk Colosseum — 3D fighting arena

A complete, self-contained stage environment for a one-on-one 3D fighting game.
Environment only — no characters, combat, AI, UI or other gameplay systems.

`res://scenes/arena.tscn` is the project's main scene. Press **F5** to run it.

---

## Layout and conventions

| | |
|---|---|
| Fight axis | **X** |
| Fight plane | **Z = 0** |
| Walking surface | **Y = 0** |
| Playable area | X ∈ [-13, 13], Z ∈ [-7, 7] |
| Platform slab | 30 × 18, top face flush at Y = 0 |
| Camera side | −Z, looking toward +Z |

The playable area is 26 × 14 units. The glowing inlaid boundary line sits at
exactly X = ±13.2 / Z = ±7.2, and the invisible ring-out collision walls sit at
±13.5 / ±7.5 — so what a player sees is what actually stops them.

### Depth layers

Each layer is darker than the one in front of it, which is what keeps the
background from competing with the fighters:

1. **Platform** — Z ±9, suspended over a chasm, with stepped skirts running off
   both ends into the fog.
2. **Chasm** — pit floor at Y = −10, lit from below by a single warm omni.
3. **Terrace and colonnade** — Z 15–26. Eight columns, an architrave, hanging
   banners and lanterns. Two bridges at X = ±11 cross the chasm.
4. **Arcaded back wall** — Z = 28. Ten piers leave 5.2-unit openings at
   X = 0, ±8.4, ±16.8 …
5. **City silhouette** — Z 44–92, read only through those openings and heavily
   fogged.

---

## Cameras

Three `Camera3D` nodes sit at the scene root. Only `MainCamera` is `current`.

| Node | Position | Frames |
|---|---|---|
| `MainCamera` | (0, 6, −19) | the entire playable area — the widest a tracking camera would need to pull back |
| `CloseCamera` | (0, 2.6, −9.5) | round-start distance, fighters at roughly a third of frame height |
| `WideCamera` | (0, 9, −34) | the whole set, for screenshots |

All three use a 45° vertical FOV. A tracking camera can interpolate between the
close and main positions as the fighters separate.

**Nothing occludes the fight plane.** Every prop is pushed outside the playable
area, the front rim is half the height of the other three sides so it cannot
crop a fighter's feet, the two overhead stage spots are above frame, and both
particle emitters are kept off the fight plane.

---

## Readability

Verified by rendering the stage with a black and a white fighter-sized capsule
at X = ±3.5; both silhouettes hold, with visible contact shadows.

- The fight surface is the brightest plane on screen; the terrace behind it is
  deliberately darker so the two never merge at foot level.
- Stone materials are desaturated, so saturated character colours stay distinct.
- Banners are held at low chroma — they sit directly behind the fighters.
- A cool directional rim light from behind separates silhouettes from the
  background.
- Depth fog starts at 26 units (clear of the whole platform) and saturates by
  88, flattening everything behind the stage into bands of value.

---

## Lighting

| Light | Role |
|---|---|
| `KeyLight` | warm directional from front-left, **only shadow-casting directional**, 4 splits, 70-unit range |
| `FillLight` | cool directional, no shadows |
| `RimLight` | cool directional from behind, no shadows — silhouette separation |
| `StageSpotLeft/Right` | overhead spots pooling light on the playfield, shadowed |
| `ChasmGlow` | warm omni under the platform |
| 8 × brazier | warm omni, flickering, unshadowed |
| 6 × lantern | small warm omni, unshadowed |

Shadow casting is disabled on every background mesh; the shadow budget is spent
on the platform and its props.

---

## Renderer notes

The project uses the **GL Compatibility** renderer, so the environment uses only
what that backend supports: sky ambient, depth fog, and glow. SSAO, SSIL, SDFGI
and volumetric fog are Forward+ only and are deliberately not enabled.
Atmospherics use `CPUParticles3D` rather than GPU particles for the same reason.

`rendering/limits/opengl/max_lights_per_object` is raised to 16 in
`project.godot`. Large meshes such as the terrace deck are touched by more than
the default eight lights, and without this some of them pop in and out.

---

## Optimisation

- The whole stage is built from **two shared primitives** — one unit `BoxMesh`
  and one unit `CylinderMesh` — scaled by node transforms. Stone materials use
  world-space triplanar UVs, so texture scale stays constant no matter how a
  block is stretched.
- **No external texture files.** Surface detail comes from `NoiseTexture2D`
  (generated at load) and soft particle sprites from radial `GradientTexture2D`.
  Every noise texture is squeezed through a narrow colour ramp — raw 0–1 noise
  in albedo turns stone into camouflage.
- Repeated set dressing (braziers, columns, banners, lanterns, crates, barrels,
  rubble) is instanced from `res://scenes/props/`.
- Two particle emitters totalling 88 particles.

---

## Files

```
scenes/arena.tscn              the stage
scenes/props/                  brazier, pillar, banner, lantern, crate, barrel, rubble
materials/                     16 StandardMaterial3D resources
environment/arena_env.tres     Environment (fog, glow, ambient, tonemap)
environment/sky_dusk.tres      procedural dusk sky
scripts/brazier_flicker.gd     fire flicker — cosmetic only
scripts/banner.gd              banner sway + per-instance cloth tint
```

Banner colour is an exported script property, so red and blue banners share one
scene: set `cloth_material` on the instance.

---

## Collision

- `Platform/Collision/ArenaFloor` — the walking surface.
- `Platform/Collision/Boundaries` — four ring-out walls, 9 units tall.
- `Background/Terrace/TerraceBody` — the background walkway.

Background architecture and props have no collision, by design.
