class_name  LightSaberAudioManager
extends Node


@onready var blaster_block: AudioStreamPlayer = $BlasterBlock


func play_blaster_block_sound():
	blaster_block.play()
