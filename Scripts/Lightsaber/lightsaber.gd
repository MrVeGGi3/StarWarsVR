class_name LightSaber
extends Node3D


@export var audios_manager : LightSaberAudioManager
@export var pickable_lightsaber : LightSaberSettings

var velocity := Vector3.ZERO
var last_position := Vector3.ZERO

func _physics_process(delta: float) -> void:
	velocity = (global_position - last_position) / delta
	last_position = global_position
	

func get_saber_velocity() -> Vector3:
	return velocity

func vibrate_controller():
	pickable_lightsaber.vibrate_controller()
