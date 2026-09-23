extends Camera3D
## Dynamic match camera: keeps both fighters framed at all times.
##
## The camera does exactly two things - it slides its position to keep the
## fighters centred, and it dollies along its own view axis to keep them both
## inside the frustum. ITS ROTATION IS NEVER TOUCHED. The angle authored on the
## node in arena.tscn is read once in _ready() and becomes the fixed basis
## everything below is solved in, so the stage keeps the viewing angle it was
## lit and composed for no matter where the fight travels.
##
## TWO NUMBERS DESCRIBE THE SHOT.
##
##   FOCUS     the world point held at screen centre: the midpoint of the two
##             fighters, lifted by focus_height so the frame is shared between
##             their feet and their heads rather than centred on the floor.
##   DISTANCE  how far back along the view axis the camera sits from it.
##
## Position is then just `focus - forward * distance`. Because forward is a
## fixed direction with both a horizontal and a vertical component, that single
## dolly axis is what produces the up/down travel as well as the in/out: the
## camera rises as it pulls back and settles as it closes, which is the arc a
## fighting-game camera is expected to sweep. Left/right and near/far come from
## the focus tracking the midpoint.
##
## THE DISTANCE IS SOLVED, NOT TUNED. Because the rotation is fixed and the
## camera is constrained to the focus-and-dolly line, the framing test for a
## world point W collapses to a single inequality. Write the camera-space
## offset of W from the focus as
##
##     lateral = (W - focus) . right      (screen x)
##     rise    = (W - focus) . up         (screen y)
##     ahead   = (W - focus) . forward    (along the dolly axis)
##
## then at dolly distance d the point sits at depth `ahead + d` from the
## camera, and it is on screen exactly when
##
##     |lateral| <= tan_x * (ahead + d)   and   |rise| <= tan_y * (ahead + d)
##
## Each of those rearranges to a LOWER BOUND on d, so the smallest distance
## that frames everything is simply the largest bound any sampled point asks
## for. That is exact - there is no iteration, no binary search and no
## per-frame guesswork - and it means "zoom out as they separate, zoom in as
## they close" is not a rule this script implements but a consequence of the
## geometry it solves. Four points are sampled: each fighter's feet and the
## top of its head, which bounds the whole body for a camera that only ever
## slides and dollies.
##
## No combat, no gameplay, no match state - this only reads the two fighters'
## positions. The movement scripts and the locomotion blend are untouched, and
## nothing here writes to them.

## The two fighters to keep in frame. Both are required; the camera holds its
## authored transform and does nothing if either is missing.
@export var fighter_a: Node3D
@export var fighter_b: Node3D

## How far above the fighters' feet the screen centre is held, in arena units
## (1 unit ~ 0.68 m). The fighters are ~2.9 units tall, so a value near half
## that shares the frame evenly between soles and crowns; lower than that
## trades headroom for more of the arena floor, which reads as more grounded.
@export var focus_height: float = 1.3

## Height of the tallest fighter, crown included - Ironjaw's topknot reaches
## 2.83. This is the upper sample point on each body, so anything taller than
## this can have its head cropped on a close-up.
@export var fighter_height: float = 2.9

## Clear space held outside each fighter, in arena units.
##
## These are not just taste. The solve frames the fighters against the focus
## the camera is CURRENTLY holding, and that focus is still easing toward the
## midpoint, so the frame is always a little behind the fight. The margins are
## what absorb that lag, and they have to beat the worst of it: a fighter
## travelling at its top speed of 4.6 units/second leaves the focus about
## `4.6 * focus_smooth_time` behind, which is roughly 0.8 units. Anything less
## than that and a hard direction change clips a shoulder.
##
## The side margin is the larger of the two on purpose: lateral gap is how a
## fighting game reads spacing, so the fighters should never sit hard against
## the screen edge, while gap above a head is mostly wasted frame. The
## vertical figure still has to clear the lag, though - the view axis is
## pitched, so travel in Z moves a fighter up and down the screen as well as
## into and out of the shot.
@export var side_margin: float = 1.8
@export var vertical_margin: float = 0.7

## Dolly limits.
##
## The lower bound only matters in degenerate cases - the framing solve above
## almost always asks for more.
##
## The upper bound is a backstop and nothing else: it is the ONE thing here
## that can crop a fighter, because it is the only bound that overrides the
## solve rather than feeding it. The genuine worst case is the two fighters in
## opposite corners of the playable rectangle, which at 16:9 asks for about 28
## units, so this is set well clear of that. Two things pull on the value in
## opposite directions - the arena's depth fog starts at 30 units, so a camera
## much beyond that begins washing the fighters out, while a narrower window
## needs MORE distance for the same shot (the solve reads the live aspect
## ratio). Keeping a fighter on screen is worth more than keeping it out of
## the fog, so the limit is set high enough that only an extreme window shape
## can reach it.
@export var min_distance: float = 4.0
@export var max_distance: float = 45.0

## Furthest the camera itself may travel toward the stage, in world Z.
##
## The focus follows the midpoint in all three axes, so a pair that clusters
## at the back of the arena would otherwise pull the camera forward over the
## fight surface. This caps that, and because the cap is expressed as yet
## another lower bound on the dolly distance rather than as a clamp on the
## final position, it can only ever widen the shot - it can never break the
## framing the solve just guaranteed.
##
## The value sits over the back half of the floor rather than off the slab
## entirely (whose front face is at Z = -9): pushed out that far, the cap
## would bind at every ordinary range and flatten the zoom to a constant.
@export var max_camera_z: float = -6.0

## Seconds for the focus to close most of the way onto the midpoint. This is
## the camera's weight - it is what stops the frame snapping sideways the
## instant a fighter changes direction.
@export var focus_smooth_time: float = 0.18

## Zoom easing, deliberately asymmetric. Pulling out is quick because the
## distance it is chasing is the one that keeps a fighter on screen, and the
## margins above are the only thing covering the lag. Pushing in is slow
## because nothing is at stake in arriving late, and a leisurely close is what
## makes the arena feel like it is tightening around the fight.
@export var zoom_out_time: float = 0.10
@export var zoom_in_time: float = 0.45

## The authored viewing angle, resolved once into the three world-space axes
## the solve is written in. `_forward` is the camera's own -Z.
var _forward := Vector3.FORWARD
var _right := Vector3.RIGHT
var _up := Vector3.UP

var _focus := Vector3.ZERO
var _distance: float = 0.0


func _ready() -> void:
	if fighter_a == null or fighter_b == null:
		push_warning("%s on '%s' needs both fighters - camera will not track." % [
			get_script().resource_path.get_file(), name,
		])
		set_process(false)
		return

	# The one read of the node's own rotation. Taken from the global transform
	# rather than the local one so the camera frames correctly however the
	# arena parents it, and never written back.
	var view_basis := global_transform.basis.orthonormalized()
	_right = view_basis.x
	_up = view_basis.y
	_forward = -view_basis.z

	# Solve and apply the shot outright rather than easing into it, so the
	# first drawn frame is already framed instead of swooping in from wherever
	# the scene happened to park the camera.
	_focus = _focus_point()
	_distance = _required_distance(_focus)
	global_position = _focus - _forward * _distance


func _process(delta: float) -> void:
	# Idle processing, not physics: the fighters move in _physics_process, so
	# by here their positions are settled for this frame, and smoothing against
	# the display rate keeps the camera fluid when the two rates differ.
	_focus = _focus.lerp(_focus_point(), _smoothing(delta, focus_smooth_time))

	# Solved against the focus the camera is ACTUALLY holding, not the one it
	# is heading for. While the focus is still catching up the frame is off
	# centre, and asking the solve to cover the fighters from where the camera
	# really points is what keeps them on screen through that lag.
	var target := _required_distance(_focus)
	var ease: float = zoom_out_time if target > _distance else zoom_in_time
	_distance = lerpf(_distance, target, _smoothing(delta, ease))

	global_position = _focus - _forward * _distance


## The point held at screen centre: the fighters' midpoint, lifted to chest
## height. The Y term is carried through rather than assumed flat so the frame
## would still follow if a fighter ever left the ground.
func _focus_point() -> Vector3:
	var middle := (fighter_a.global_position + fighter_b.global_position) * 0.5
	middle.y += focus_height
	return middle


## Smallest dolly distance that keeps both fighters inside the frustum, given
## the focus the camera is pointing at. See the header for the derivation.
func _required_distance(focus: Vector3) -> float:
	var half := tan(deg_to_rad(fov) * 0.5)
	var view := get_viewport().get_visible_rect().size
	var aspect: float = view.x / maxf(view.y, 1.0)

	# fov measures whichever axis the camera keeps fixed as the window is
	# reshaped, and the other follows from the aspect ratio. Reading it live
	# rather than baking a number in is what lets the framing survive a resize
	# - the project stretches on "expand", so the aspect really does vary.
	var tan_y: float = half if keep_aspect == KEEP_HEIGHT else half / maxf(aspect, 0.001)
	var tan_x: float = half * aspect if keep_aspect == KEEP_HEIGHT else half

	var needed := min_distance

	for fighter in [fighter_a, fighter_b]:
		var sole: Vector3 = fighter.global_position
		# Feet and crown bound the body for a camera that only slides and
		# dollies: it never rolls, so nothing can swing outside that span.
		for height in [0.0, fighter_height]:
			var offset := Vector3(sole.x, sole.y + height, sole.z) - focus
			var ahead := offset.dot(_forward)
			needed = maxf(needed, (absf(offset.dot(_right)) + side_margin) / tan_x - ahead)
			needed = maxf(needed, (absf(offset.dot(_up)) + vertical_margin) / tan_y - ahead)

	# Keep the camera off the stage, as another bound on the same dolly axis.
	# Only meaningful while the camera looks along +Z, which is the arena's
	# convention: the shot is composed from -Z looking back at the platform.
	if _forward.z > 0.001:
		needed = maxf(needed, (focus.z - max_camera_z) / _forward.z)

	return minf(needed, max_distance)


## Blend factor for an exponential approach with a time constant of `tau`,
## written against delta so the easing is identical at any frame rate.
func _smoothing(delta: float, tau: float) -> float:
	return 1.0 - exp(-delta / maxf(tau, 0.001))
