extends Node3D
## Hanging arena banner. The cloth is pivoted at its top edge so rotating this
## node swings it from the rail like fabric, and the colour is chosen per
## instance instead of duplicating the scene for every team tint.

## Cloth tint. Set this on the instance; falls back to whatever the mesh
## already carries when left empty.
@export var cloth_material: Material

## Peak swing away from rest, in degrees.
@export var sway_degrees: float = 2.6
## Seconds per full swing cycle.
@export var sway_period: float = 4.5

@onready var _cloth: MeshInstance3D = $Cloth

var _time: float = 0.0
var _phase: float = 0.0
var _rest: Vector3


func _ready() -> void:
	if cloth_material != null:
		_cloth.material_override = cloth_material
	# Offset each banner so a row of them never swings in unison.
	_phase = randf() * TAU
	_rest = rotation


func _process(delta: float) -> void:
	_time += delta

	var t: float = _time * TAU / maxf(sway_period, 0.01) + _phase
	# A slower secondary wave on Z keeps the motion from looking like a metronome.
	var swing_x: float = sin(t) * deg_to_rad(sway_degrees)
	var swing_z: float = sin(t * 0.63) * deg_to_rad(sway_degrees * 0.35)

	rotation = _rest + Vector3(swing_x, 0.0, swing_z)
