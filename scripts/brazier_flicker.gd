extends Node3D
## Drives the fire ambience on a brazier: the point light pulses and the flame
## cone bobs and squashes. Purely cosmetic - no gameplay state is touched.
##
## Three summed sine waves at incommensurate rates read as organic flicker
## without the cost of sampling noise every frame.

## Baseline light energy. The flicker modulates around this value.
@export var base_energy: float = 3.2
## How far the light energy swings, as a fraction of base_energy.
@export_range(0.0, 1.0) var flicker_amount: float = 0.28
## Overall speed of the flicker.
@export var flicker_speed: float = 5.5
## How much the flame mesh stretches and squashes.
@export_range(0.0, 0.5) var flame_bob: float = 0.14

@onready var _light: OmniLight3D = $Light
@onready var _flame: Node3D = $Flame

var _time: float = 0.0
var _phase: float = 0.0


func _ready() -> void:
	# Offset each brazier so a row of them never flickers in unison.
	_phase = randf() * TAU
	_light.light_energy = base_energy


func _process(delta: float) -> void:
	_time += delta * flicker_speed

	var wave: float = (
		sin(_time + _phase) * 0.6
		+ sin(_time * 2.37 + _phase * 1.7) * 0.28
		+ sin(_time * 4.11 + _phase * 0.4) * 0.12
	)

	_light.light_energy = base_energy * (1.0 + wave * flicker_amount)

	var stretch: float = 1.0 + wave * flame_bob
	var pinch: float = 1.0 - wave * flame_bob * 0.45
	_flame.scale = Vector3(pinch, stretch, pinch)
