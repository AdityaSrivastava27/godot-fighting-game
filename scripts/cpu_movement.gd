extends FighterMovement
## Combat-aware positioning for the CPU fighter.
##
## The whole of the movement - the fight frame, acceleration, the ring-out and
## separation clamps, the facing, and the hand-off to the locomotion blend -
## lives in fighter_movement.gd, exactly as it does for the player. All this
## adds is the stick. Where player_movement.gd reads that stick off the
## keyboard, this derives it from two questions asked fresh every frame:
##
##   ADVANCE  am I at the range I want to fight at?   -> _spacing_intent()
##   STRAFE   is the opponent sliding around me?      -> _mirror_intent()
##
## Both answers come back as a fraction of this fighter's own top speed in that
## direction, which is the same shape a stick has, so everything downstream -
## the easing, the constraints, the blend - treats the CPU exactly as it treats
## the player. The animation is not chosen anywhere in this file: the base
## writes the blend point from the velocity that actually survived the
## constraints, so walk_forward, walk_back and the two hops fall out of where
## the fighter is really going. Closing plays the walk, giving ground plays the
## retreat, mirroring a circling opponent plays the hop, and standing at the
## range it wants coasts back to idle.
##
## POSITIONING ONLY, deliberately. No attacks, no blocking, no reactions, no
## health, no state machine, no prediction, no difficulty tiers. The fighter
## holds a range and stays squared up, and that is the whole of it.
##
## Two consequences worth knowing rather than fixing, because the fix in each
## case is a behaviour this is explicitly not supposed to have:
##   - Backed onto a ring-out line it stops retreating, because the base clamps
##     the position and hands back the velocity that survived. It stands its
##     ground in the corner instead of sidestepping out, which would need wall
##     awareness this does not have.
##   - Mirroring is slightly under-unity by construction (see mirror_deadzone),
##     so a committed player still wins ground by circling. That is the right
##     way round: the CPU should make circling cost something, not make it
##     impossible.

## Centre-to-centre distance this fighter tries to hold, in arena units. At
## roughly 1 unit = 0.68 m this is about 1.9 m between navels - a step outside
## the range either of them could reach from, which is where a fighter with no
## attack yet ought to want to stand.
@export var preferred_distance: float = 2.8

## Half-width of the band around preferred_distance that counts as "close
## enough". Without a deadband the fighter would hunt for the exact number
## forever, trading tiny advances and retreats; with it, anything from 2.3 to
## 3.3 units is simply accepted and the fighter holds still and idles.
@export var distance_tolerance: float = 0.5

## How far past the edge of that band, in units, the fighter has to be before
## it commits to a full-speed walk. Inside that it ramps, so it eases into the
## band rather than arriving at top speed and overshooting out the far side.
@export var spacing_ramp: float = 1.5

## How much of the opponent's sideways travel this fighter matches. 1.0 is a
## one-for-one mirror.
@export var mirror_gain: float = 1.0

## Sideways speed, in units per second, below which the opponent is treated as
## not circling at all. This filters the small lateral drift that comes out of
## a diagonal walk or a separation push, so the fighter is not twitching into
## a hop every time the opponent's path bends slightly. It also costs the
## mirror its first few percent, which is what leaves a determined player able
## to gain angle - see the header.
@export var mirror_deadzone: float = 0.4

## Seconds for the intent to close most of the way onto a new target. This is
## the fighter's reaction time: it is what stops the intent snapping between
## values the instant the opponent changes direction, and it is applied to the
## intent rather than the velocity so the base's acceleration still shapes the
## result on top of it.
@export var reaction_time: float = 0.12

var _intent := Vector2.ZERO
var _last_opponent_position := Vector3.ZERO


func _ready() -> void:
	super()
	# The mirror is a finite difference on the opponent's position, so it needs
	# a previous sample before the first frame or it would read the opponent's
	# whole starting offset as one enormous sideways lunge. The base leaves
	# opponent_position populated when it found an opponent, and disables
	# physics processing when it did not.
	_last_opponent_position = opponent_position


## The stick, in the fight frame the base refreshed immediately before this
## call. Smoothed toward the target rather than set to it; the filter is
## written against delta rather than per frame so the reaction time is the
## same at any physics rate.
func _read_intent(delta: float) -> Vector2:
	var target := Vector2(_mirror_intent(delta), _spacing_intent())
	var blend := 1.0 - exp(-delta / maxf(reaction_time, 0.001))
	_intent = _intent.lerp(target, blend)
	return _intent


## Advance, as a fraction of top speed: positive closes, negative gives ground.
func _spacing_intent() -> float:
	var error := distance_to_opponent - preferred_distance
	if absf(error) <= distance_tolerance:
		return 0.0

	# Measure from the edge of the band, not from its centre, so the intent is
	# continuous as the fighter crosses in and out - it leaves the band at zero
	# and grows from there, instead of jumping to whatever the centre offset
	# happened to be.
	var beyond := error - signf(error) * distance_tolerance
	return clampf(beyond / maxf(spacing_ramp, 0.001), -1.0, 1.0)


## Strafe, as a fraction of top speed, matching the opponent's own sideways
## travel.
##
## Moving the SAME way the opponent is moving is what holds the angle between
## them: the two slide along together, the line joining them stays where it
## was, and the opponent gets nowhere. Moving the opposite way would hand them
## the flank twice as fast. Because the base re-aims at the opponent every
## frame, this is only ever about position - the facing takes care of itself.
func _mirror_intent(delta: float) -> float:
	# The opponent's displacement over the last physics step, projected onto
	# this fighter's own right. Both fighters run in the same step and the
	# player runs first, so this is a fresh reading, not a frame stale.
	var step := opponent_position - _last_opponent_position
	_last_opponent_position = opponent_position

	var lateral := step.dot(fight_right) / maxf(delta, 0.0001)
	if absf(lateral) <= mirror_deadzone:
		return 0.0

	# Measured from the edge of the deadzone for the same continuity reason as
	# the spacing ramp above.
	var excess := lateral - signf(lateral) * mirror_deadzone
	return clampf(excess * mirror_gain / maxf(strafe_speed, 0.001), -1.0, 1.0)
