extends Node3D
## Opponent-relative ground movement for the player fighter.
##
## Everything here is expressed in the frame a fighter actually thinks in.
## FORWARD is straight at the opponent and BACK is straight away from it, so
## the advance/retreat axis stays meaningful no matter where on the stage the
## two end up. LEFT and RIGHT sidestep along the perpendicular of that same
## line, and because the fighter is re-aimed at the opponent every frame,
## holding one of them walks an arc around the opponent rather than a straight
## line across the floor. That re-aiming is the whole reason the movement
## reads as circling instead of strafing.
##
## Movement only. No combat, no attacks, no animation, no jump, no AI. The rig
## keeps its bind pose; this script translates and yaws the scene root and
## touches nothing else.
##
## KINEMATIC BY CHOICE. A fighting stage is a flat rectangle with hard edges,
## so the position is integrated and then clamped analytically instead of
## being pushed through the physics server. That is exact at any frame rate,
## cannot tunnel a wall, will not snag on the decorative crates, and leaves
## the fighter scenes as the pure geometry their headers promise. The arena's
## boundary StaticBody3D stays what it always was: the authored reference the
## numbers below are read off.

## The fighter this one orients itself against. Forward is toward it.
@export var opponent: Node3D

## Walk speed straight at the opponent, in arena units per second. The arena
## is authored at roughly 1 unit = 0.68 m, so this is a brisk ~3.1 m/s.
@export var forward_speed: float = 4.6
## Retreat is slower than advance, as it is in every fighting game - backing
## out of range should cost something.
@export var backward_speed: float = 3.4
## Sidestep speed. Slowest of the three, so circling is a commitment.
@export var strafe_speed: float = 3.8

## Units per second squared toward the requested velocity. High on purpose:
## full walk speed lands in about five physics frames, which still reads as
## responsive while taking the hard edge off an instant velocity swap.
@export var acceleration: float = 60.0
## Units per second squared back to a standstill when nothing is held.
@export var deceleration: float = 90.0
## Degrees per second the fighter turns to keep facing the opponent.
@export var turn_speed: float = 720.0

## Extra yaw, in degrees, rolling the fighter's front toward the camera so a
## side-on stance still shows brow, nose and eyes instead of a blank edge.
## This is the 12-degree cheat the arena bakes into both round-start poses;
## keeping it here is what stops the first frame of play from snapping Kestrel
## into exact profile. It is scaled by how side-on the fighter actually is, so
## it fades to nothing once they already face the camera.
@export var facing_offset_degrees: float = 12.0

## Playable rectangle as (min_x, min_z) and (max_x, max_z). These are the
## glowing ring-out lines in arena.tscn, which sit exactly on the inner faces
## of the boundary collision walls - what the player sees is what stops them.
@export var bounds_min := Vector2(-13.2, -7.2)
@export var bounds_max := Vector2(13.2, 7.2)
## Half-width of the fighter, held clear of the lines so the body stops at the
## boundary rather than straddling it.
@export var body_radius: float = 0.35
## Closest the two fighters may stand, centre to centre. Not a combat pushbox
## - it is what keeps "toward the opponent" a well-defined direction. Without
## it the player walks through the CPU and forward flips 180 degrees at the
## crossing point.
@export var min_separation: float = 0.9

var _velocity := Vector3.ZERO
var _ground_y: float = 0.0


func _ready() -> void:
	# No jumping, so the walking height is captured once and reasserted every
	# frame instead of being integrated.
	_ground_y = global_position.y

	if opponent == null:
		push_warning("player_movement on '%s' has no opponent - movement disabled." % name)
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	var start := global_position
	var target := opponent.global_position

	# The fight frame, flattened to the walking plane so an opponent at a
	# different height can never tip the fighter off vertical.
	var to_opponent := Vector3(target.x - start.x, 0.0, target.z - start.z)
	if to_opponent.length_squared() < 0.000001:
		return

	var forward := to_opponent.normalized()
	# The rig faces local -Z, which makes local +X its own right, and for a
	# -Z-facing vector this cross product is exactly that +X.
	var right := forward.cross(Vector3.UP)

	# +y is toward the opponent, +x is the fighter's right. get_vector
	# normalises, so a diagonal is never faster than a cardinal.
	var stick := Input.get_vector("move_left", "move_right", "move_back", "move_forward")

	var reach: float = forward_speed if stick.y >= 0.0 else backward_speed
	var desired := forward * (stick.y * reach) + right * (stick.x * strafe_speed)

	var rate := acceleration if desired.length_squared() > 0.0 else deceleration
	_velocity = _velocity.move_toward(desired, rate * delta)

	var pos := start + _velocity * delta

	# Constraints, innermost outward: never stand inside the opponent, never
	# cross the ring-out line, never leave the floor.
	pos = _resolve_separation(pos, target)
	pos.x = clampf(pos.x, bounds_min.x + body_radius, bounds_max.x - body_radius)
	pos.z = clampf(pos.z, bounds_min.y + body_radius, bounds_max.y - body_radius)
	pos.y = _ground_y

	global_position = pos

	# Take the velocity back from the motion that actually happened. Held into
	# a wall, _velocity would otherwise keep accumulating against a position
	# that never moves, and the fighter would fire off the instant the
	# constraint lifted.
	_velocity = (pos - start) / delta

	# Aim from where the fighter ended up, not from where it started.
	var aim := Vector3(target.x - pos.x, 0.0, target.z - pos.z)
	if aim.length_squared() > 0.000001:
		_turn_toward(aim.normalized(), delta)


## Yaws toward `dir` at no more than turn_speed, carrying the camera cheat.
func _turn_toward(dir: Vector3, delta: float) -> void:
	# For a yaw of t the rig's -Z axis points at (-sin t, 0, -cos t), so this
	# is the yaw that aims it down `dir`.
	var aimed := atan2(-dir.x, -dir.z)

	# Rolling the front toward the camera means shrinking the z of the facing
	# direction, and d(z)/d(yaw) is -dir.x, so the offset takes dir.x's sign.
	# Using dir.x itself rather than its sign also fades the cheat out as the
	# fighter turns to face the camera, and keeps it continuous at dir.x = 0.
	aimed += deg_to_rad(facing_offset_degrees) * dir.x

	var step := wrapf(aimed - global_rotation.y, -PI, PI)
	var limit := deg_to_rad(turn_speed) * delta
	global_rotation.y += clampf(step, -limit, limit)


## Pushes `pos` radially out of the opponent's personal space.
func _resolve_separation(pos: Vector3, target: Vector3) -> Vector3:
	var offset := Vector2(pos.x - target.x, pos.z - target.z)
	var distance := offset.length()
	if distance >= min_separation:
		return pos

	# Dead centre on the opponent leaves no direction to push along; back off
	# down the fight axis so the result is at least deterministic.
	var push := offset / distance if distance > 0.0001 else Vector2(-1.0, 0.0)
	push *= min_separation
	return Vector3(target.x + push.x, pos.y, target.z + push.y)
