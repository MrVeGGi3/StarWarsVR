class_name AnimationSettings
extends Node

@export var animation_player : AnimationPlayer


## The ignition/retraction clips are one-shots; when they end we fall through
## to the matching looping "held" state.
func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "turn_off":
		animation_player.play("Turned_Off")
	elif anim_name == "turn_on":
		animation_player.play("Turned_On")


func turn_lightsaber_on() -> void:
	animation_player.play("turn_on")


func turn_lightsaber_off() -> void:
	animation_player.play("turn_off")
