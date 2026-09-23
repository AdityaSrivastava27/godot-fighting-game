extends FighterMovement
## Keyboard control for the player fighter.
##
## The whole of the movement - the fight frame, acceleration, the ring-out and
## separation clamps, the facing, and the hand-off to the locomotion blend -
## lives in fighter_movement.gd. All this adds is the stick, so that the player
## and the CPU are demonstrably running the same body with different heads.
##
## Movement only. No combat, no attacks, no jump.


## WASD and the arrow keys, resolved straight into the fight frame: holding
## "forward" walks at the opponent wherever it has got to, not up the world
## axis. Input.get_vector normalises, so a diagonal is never faster than a
## cardinal, and it already lands inside the unit disc the base clamps to.
func _read_intent(_delta: float) -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_back", "move_forward")
