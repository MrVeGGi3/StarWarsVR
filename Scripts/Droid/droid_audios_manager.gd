## Holds the droid's positional audio players. Node3D so the players inherit the
## transform and actually spatialise.
##
## Every method no-ops while a player has no stream, so the droid runs silent and
## error-free until the audio files are dropped into the slots.
##
## The charge and fire players are meant to live under the muzzle marker, which
## [TrainingDroid] parks on whichever port it drew - so the wind-up is heard
## coming out of the actual hole, not out of the droid's centre. That is the cue
## a player needs to block the shot with their eyes closed.
class_name DroidAudioManager
extends Node3D


## Continuous hover/servo loop. The anchor the player locates the droid by.
@export var hover : AudioStreamPlayer3D
## One-shot click when the droid stops and swings a port around.
@export var servo : AudioStreamPlayer3D
## Wind-up while a port is aiming. Put this under the muzzle.
@export var charge : AudioStreamPlayer3D
## The shot itself. Put this under the muzzle.
@export var fire : AudioStreamPlayer3D

@export_group("Hover Pitch")
## Pitch of the hover loop while the droid hangs still.
@export var pitch_idle : float = 0.9
## Pitch of the hover loop at full travel speed.
@export var pitch_moving : float = 1.15


func _ready() -> void:
	# mp3 and ogg carry the loop flag on the resource. A wav does not: its loop
	# points are baked at import, so a wav hover needs Loop Mode = Forward in the
	# Import dock (edit/loop_mode=2 in the .import file).
	if hover and hover.stream and "loop" in hover.stream:
		hover.stream.loop = true

	set_hover_active(true)


func set_hover_active(active: bool) -> void:
	if not _playable(hover):
		return

	if active:
		if not hover.playing:
			hover.play()
	else:
		hover.stop()


## Rides the hover pitch up with the droid's speed, so the ear can tell it is
## accelerating away or settling into a stop.
func set_hover_speed(ratio: float) -> void:
	if not hover:
		return

	hover.pitch_scale = lerpf(pitch_idle, pitch_moving, clampf(ratio, 0.0, 1.0))


func play_servo() -> void:
	if _playable(servo):
		servo.play()


## Starts the wind-up. [param duration] is the warning window: the sample is
## stretched by pitch to fit it, so the sound always lands on the shot even after
## aim_time is retuned.
func start_charge(duration: float) -> void:
	if not _playable(charge):
		return

	var length := charge.stream.get_length()
	if length > 0.0 and duration > 0.0:
		charge.pitch_scale = clampf(length / duration, 0.5, 2.0)

	charge.play()


func stop_charge() -> void:
	if charge and charge.playing:
		charge.stop()


func play_fire() -> void:
	if _playable(fire):
		fire.play()


func _playable(player : AudioStreamPlayer3D) -> bool:
	return player != null and player.stream != null
