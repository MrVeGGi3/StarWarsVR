## Holds the saber's positional audio players. Node3D so the AudioStreamPlayer3D
## children inherit the saber's transform and actually spatialise.
class_name LightSaberAudioManager
extends Node3D


@onready var blaster_block: AudioStreamPlayer3D = $BlasterBlock
@onready var hum: AudioStreamPlayer3D = $Stable


func play_blaster_block_sound() -> void:
	blaster_block.play()


## Starts or stops the looping blade hum, following the blade state.
func set_hum_active(active: bool) -> void:
	if active:
		if not hum.playing:
			hum.play()
	else:
		hum.stop()
