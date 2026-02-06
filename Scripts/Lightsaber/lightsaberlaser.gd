@tool
class_name LightSaberSettings
extends XRToolsPickable

@export var animation_settings : AnimationSettings 
@export var audios_manager : LightSaberAudioManager


var velocity := Vector3.ZERO
var last_position := Vector3.ZERO


func _physics_process(delta: float) -> void:
	velocity = (global_position - last_position) / delta
	last_position = global_position

func get_saber_velocity() -> Vector3:
	return velocity

enum lightsaber_states {
	ON,
	OFF
}

var current_lightsaber_state = lightsaber_states.OFF
var is_picked = false
var actual_controller : XRController3D = null

func _ready():
	picked_up.connect(_on_picked_up)
	dropped.connect(_on_dropped)
	

func _on_picked_up(_pickable):
	actual_controller = get_picked_up_by_controller()
	
	if actual_controller:
		actual_controller.button_pressed.connect(_on_controller_button_pressed)

func _on_dropped(_pickable):
	if actual_controller:
		if actual_controller.button_pressed.is_connected(_on_controller_button_pressed):
			actual_controller.button_pressed.disconnect(_on_controller_button_pressed)
	
	actual_controller = null
	toggle_lightsaber(false)
	

func _on_controller_button_pressed(button_name : String):
	print(button_name)
	if button_name == "by_button":
		print("Estou pressionando o botão para acionar o sabre de luz")
		toggle_lightsaber()
		

func toggle_lightsaber(force_state = null):
	var new_state
	
	if force_state != null:
		new_state = lightsaber_states.ON if force_state else lightsaber_states.OFF
	else:
		new_state = lightsaber_states.ON if current_lightsaber_state == lightsaber_states.OFF else lightsaber_states.OFF
	
	current_lightsaber_state = new_state
	
	if new_state == lightsaber_states.ON:
		animation_settings.turn_lightsaber_on()
		trigger_haptic_ignition()
		print("Estou ligando o Lightsaber")
	else:
		animation_settings.turn_lightsaber_off()
		trigger_haptic_retract()
		print("Estou desligando o Lightsaber")

func vibrate_controller():
	actual_controller.trigger_haptic_pulse("haptic", 100.0, 1.0, 0.1, 0)

func trigger_haptic_ignition():
	if actual_controller:
		actual_controller.trigger_haptic_pulse("haptic", 60.0, 1.0, 0.25, 0)

func trigger_haptic_retract():
	if actual_controller:
		actual_controller.trigger_haptic_pulse("haptic", 80.0, 0.6, 0.15,0)
