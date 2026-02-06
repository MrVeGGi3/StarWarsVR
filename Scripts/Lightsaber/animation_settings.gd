class_name AnimationSettings
extends Node

@export var animation_player : AnimationPlayer 
@onready var light_saber: LightSaberSettings = $".."


func _on_animation_player_animation_finished(anim_name: StringName) -> void:
	if anim_name == "turn_off":
		animation_player.play("Turned_Off")
		#light_saber_settings.current_lightsaber_state = light_saber_settings.lightsaber_states.OFF
	elif anim_name == "turn_on":
		animation_player.play("Turned_On")
		#light_saber_settings.current_lightsaber_state = light_saber_settings.lightsaber_states.ON

func turn_lightsaber_on():
	animation_player.play("turn_on")

func turn_lightsaber_off():
	animation_player.play("turn_off")
