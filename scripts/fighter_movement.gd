class_name FighterMovement
extends Node3D
## Opponent-relative ground movement, shared by both fighters.
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
## THE ONE THING SUBCLASSES SUPPLY is _read_intent(), which answers "where does
## this fighter want to go" as a stick-shaped Vector2 in that same fight frame.
## player_movement.gd reads it off the keyboard; cpu_movement.gd derives it from
## the spacing it wants to hold. Neither one touches velocity, constraints,
## facing or animation - all of that is below, once, so the two fighters cannot
## drift apart in feel.
##
## Movement only. No combat, no attacks, no jump, no AI beyond the positioning
## a subclass asks for. This script translates and yaws the scene root, and
## hands the fighter's own velocity to the rig's locomotion blend so the legs
## match the travel.
##
## THAT HAND-OFF IS THE WHOLE ANIMATION LAYER. There is no state machine and no
## transition table. The blend space on each fighter scene holds idle at its
## origin with walk_forward, walk_back, hop_left and hop_right pinned around
## it, and every frame this script writes in where the fighter is actually
## going, measured in the same fight frame the intent was resolved in. Changing
## direction moves that point across the space and the blend follows; letting
## the intent fall to zero lets it coast back to the origin, which is idle.
## Both read as smooth for the same reason: the point is driven by _velocity,
## which is already accelerated and decelerated below, so the animation
## inherits the easing the movement was given rather than needing its own.
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
## keeping it here is what stops the first frame of play from snapping a
## fighter into exact profile. It is scaled by how side-on the fighter
## actually is, so it fades to nothing once they already face the camera, and
## it takes its sign from the facing direction - so the two fighters, aimed at
## each other from opposite sides, both roll toward the camera rather than one
## of them rolling away from it.
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
## it a fighter walks through the other and forward flips 180 degrees at the
## crossing point. Both fighters resolve it against the other's current
## position, which is stable: whoever runs second already finds the gap open.
@export var min_separation: float = 0.9

## The one parameter the locomotion blend space exposes. Its value is a
## Vector2 of (strafe, advance), each already divided by the speed that axis
## tops out at, so the clips sit at +/-1 and idle at the origin.
const BLEND_POSITION := "parameters/blend_position"

## The fight frame, refreshed immediately before _read_intent() is called so a
## subclass can resolve its intent in the same basis the result is spent in.
## Unit vectors on the walking plane; `fight_right` is the fighter's own right.
var fight_forward := Vector3.FORWARD
var fight_right := Vector3.RIGHT
## The opponent's position this frame, and the flat distance to it.
var opponent_position := Vector3.ZERO
var distance_to_opponent: float = 0.0

var _velocity := Vector3.ZERO
var _ground_y: float = 0.0
var _anim_tree: AnimationTree


func _ready() -> void:
	# No jumping, so the walking height is captured once and reasserted every
	# frame instead of being integrated.
	_ground_y = global_position.y

	# Looked up rather than exported: the tree is part of the fighter scene
	# this script is attached to, so there is nothing for the arena to wire up
	# and nothing to re-wire if the script moves to the other side.
	_anim_tree = get_node_or_null(^"AnimationTree") as AnimationTree
	if _anim_tree == null:
		push_warning("%s on '%s' found no AnimationTree - the rig will not animate." % [
			get_script().resource_path.get_file(), name,
		])

	if opponent == null:
		push_warning("%s on '%s' has no opponent - movement disabled." % [
			get_script().resource_path.get_file(), name,
		])
		set_physics_process(false)
		return

	opponent_position = opponent.global_position


## Where this fighter wants to go, in the fight frame refreshed just above the
## call: +y toward the opponent, +x the fighter's own right. Treated exactly
## like a gamepad stick - the base clamps it into the unit disc, so a subclass
## cannot outrun its own export by returning something longer.
##
## Subclasses override this. The default stands still.
func _read_intent(_delta: float) -> Vector2:
	return Vector2.ZERO


func _physics_process(delta: float) -> void:
	var start := global_position
	opponent_position = opponent.global_position

	# The fight frame, flattened to the walking plane so an opponent at a
	# different height can never tip the fighter off vertical.
	var to_opponent := Vector3(
		opponent_position.x - start.x, 0.0, opponent_position.z - start.z
	)
	distance_to_opponent = to_opponent.length()
	if distance_to_opponent < 0.001:
		# Standing exactly on the opponent leaves no fight frame to resolve
		# the intent or the blend in. Fall back to idle rather than holding
		# whatever pose the last good frame left behind.
		_set_blend(Vector2.ZERO)
		return

	fight_forward = to_opponent / distance_to_opponent
	# The rig faces local -Z, which makes local +X its own right, and for a
	# -Z-facing vector this cross product is exactly that +X.
	fight_right = fight_forward.cross(Vector3.UP)

	var stick := _read_intent(delta).limit_length(1.0)

	var reach: float = forward_speed if stick.y >= 0.0 else backward_speed
	var desired := fight_forward * (stick.y * reach) + fight_right * (stick.x * strafe_speed)

	var rate := acceleration if desired.length_squared() > 0.0 else deceleration
	_velocity = _velocity.move_toward(desired, rate * delta)

	var pos := start + _velocity * delta

	# Constraints, innermost outward: never stand inside the opponent, never
	# cross the ring-out line, never leave the floor.
	pos = _resolve_separation(pos, opponent_position)
	pos.x = clampf(pos.x, bounds_min.x + body_radius, bounds_max.x - body_radius)
	pos.z = clampf(pos.z, bounds_min.y + body_radius, bounds_max.y - body_radius)
	pos.y = _ground_y

	global_position = pos

	# Take the velocity back from the motion that actually happened. Held into
	# a wall, _velocity would otherwise keep accumulating against a position
	# that never moves, and the fighter would fire off the instant the
	# constraint lifted.
	_velocity = (pos - start) / delta

	# Drive the blend from the velocity the constraints left, not the one that
	# was asked for. Walked into a wall or into the opponent's personal space,
	# the fighter stops travelling and so does the animation - it settles into
	# idle against the obstacle instead of running on the spot.
	_set_blend(Vector2(
		_velocity.dot(fight_right) / strafe_speed,
		_project_advance(_velocity.dot(fight_forward)),
	))

	# Aim from where the fighter ended up, not from where it started.
	var aim := Vector3(opponent_position.x - pos.x, 0.0, opponent_position.z - pos.z)
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


## Advance speed as a fraction of the speed available in that direction.
## Advance and retreat are deliberately not the same speed, so each has to be
## measured against its own maximum - otherwise a full-speed retreat would
## arrive at the blend space as 3.4/4.6 and play a permanently half-hearted
## walk_back.
func _project_advance(advance: float) -> float:
	var reach: float = forward_speed if advance >= 0.0 else backward_speed
	return advance / maxf(reach, 0.001)


## Writes the locomotion blend point, projected onto the diamond the blend
## space's triangles actually cover.
func _set_blend(blend: Vector2) -> void:
	if _anim_tree == null:
		return

	# The intent is clamped into the unit disc before it becomes velocity, so
	# a diagonal arrives here as roughly (0.71, 0.71) - outside the diamond,
	# where the blend space would clamp it to some nearest edge point of its
	# own choosing. Scaling by the L1 norm instead lands it at (0.5, 0.5):
	# half walk, half hop, which is what a diagonal should look like.
	var span := absf(blend.x) + absf(blend.y)
	if span > 1.0:
		blend /= span

	_anim_tree.set(BLEND_POSITION, blend)
