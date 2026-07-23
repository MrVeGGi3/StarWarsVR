# XRToolsPickable is a @tool script, and the addon's grab-point previews walk
# up the ancestors calling is_xr_class() from the editor. Dropping @tool here
# would turn this node into a placeholder instance and break those previews,
# so the runtime-only logic below is guarded with Engine.is_editor_hint().
@tool
class_name LightSaberSettings
extends XRToolsPickable

enum lightsaber_states {
	ON,
	OFF
}

## Controller action that toggles the blade.
const TOGGLE_BUTTON := "by_button"
## Below this speed the saber counts as settled and can be recalled.
const RECALL_REST_SPEED := 0.5
## Cap on settle retries, so a saber that never comes to rest still returns.
const RECALL_MAX_RETRIES := 5

@export var animation_settings : AnimationSettings
@export var audios_manager : LightSaberAudioManager

@export_group("Recall")
## Seconds after being dropped before the saber flies back to its holster.
## Set to 0 to disable the recall entirely.
@export var recall_delay : float = 1.5

var current_lightsaber_state := lightsaber_states.OFF
var actual_controller : XRController3D = null

## Last snap zone that held the saber; learnt on pickup, so no cross-scene
## wiring is needed as long as the saber starts holstered.
var home_zone : XRToolsSnapZone = null

var velocity := Vector3.ZERO
var last_position := Vector3.ZERO

var _recall_timer : Timer
var _recall_retries := 0

## Pickup function of the hand holding the saber; null while a snap zone holds it.
var _holding_pickup : XRToolsFunctionPickup = null

## Hand mesh of the holder. The grab points carry no hand pose, so the fingers
## would follow the real grip and open up while the saber stays stuck to the palm.
var _holding_hand : XRToolsHand = null

## Hand mesh of the second hand, when the saber is held two-handed. Closed over
## the hilt the same way, and its presence is what a blaster reads as a stronger,
## Djem So style block through [method is_two_handed].
var _second_hand : XRToolsHand = null

## Holster the hilt is currently close enough to stow into, if any.
var _holster_in_range : XRToolsSnapZone = null

## True while a snap zone is the holder, so the next hand pickup knows the saber
## is being drawn from the belt rather than picked up off the floor.
var _was_holstered := false


func _ready() -> void:
	# XRToolsPickable._ready() collects the child grab points. Skipping it
	# leaves that list empty, so the saber gets grabbed by the RigidBody origin
	# instead of the hilt and the snap zone behaves inconsistently.
	super._ready()

	if Engine.is_editor_hint():
		return

	# Seed the position tracker, otherwise the first frame reports a huge
	# velocity measured all the way from the world origin.
	last_position = global_position

	picked_up.connect(_on_picked_up)
	dropped.connect(_on_dropped)

	# grabbed/released fire for BOTH hands and for a primary/secondary swap, which
	# picked_up/dropped do not. Rebinding the hands on these keeps the lock and the
	# blade button on whichever hand is actually primary after a two-handed swap.
	grabbed.connect(_on_grab_changed)
	released.connect(_on_grab_changed)

	_recall_timer = Timer.new()
	_recall_timer.one_shot = true
	_recall_timer.timeout.connect(_recall_to_holster)
	add_child(_recall_timer)


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint():
		return

	velocity = (global_position - last_position) / delta
	last_position = global_position

	_update_hand_lock()


func get_saber_velocity() -> Vector3:
	return velocity


## Colour of this blade's glow, read live from the blade shader so each saber —
## whatever its kyber crystal — reports its own, and a colour changed at runtime
## is picked up too. Returns white-hot when the blade node or its shader
## parameter is missing, so callers never have to special-case a saber.
func get_blade_color() -> Color:
	const FALLBACK := Color(1, 0.95, 0.8)

	var mesh := get_node_or_null("Area3D/MeshInstance3D") as MeshInstance3D
	if not mesh:
		return FALLBACK

	var material := mesh.get_active_material(0) as ShaderMaterial
	if not material:
		return FALLBACK

	var value = material.get_shader_parameter("glow_color")
	return value if value is Color else FALLBACK


func _on_picked_up(_pickable) -> void:
	_recall_timer.stop()

	# Remember the holster we came from, so being left on the floor can send
	# the saber back to it.
	var zone := get_picked_up_by() as XRToolsSnapZone
	if zone:
		home_zone = zone

	_sync_hands()

	# Drawing from the belt ignites the blade. Picking the saber up off the floor
	# leaves it as it was.
	if _holding_pickup and _was_holstered:
		toggle_lightsaber(true)

	_was_holstered = zone != null


func _on_grab_changed(_pickable, _by) -> void:
	_sync_hands()


func _on_dropped(_pickable) -> void:
	# The grab driver is already gone here, so _sync_hands restores both hands'
	# grips, re-enables the pickup and clears the state.
	_sync_hands()

	_holster_in_range = null
	toggle_lightsaber(false)

	# A hand taking the saber out of the holster also fires this, but it picks
	# the saber up in the same frame, which stops the timer again.
	if recall_delay > 0.0 and is_instance_valid(home_zone):
		_recall_retries = 0
		_recall_timer.start(recall_delay)


## Rebinds which hand is primary (locked to the saber, blade button, forced grip)
## and which is secondary (forced grip), from the live grab state. Safe and
## idempotent on every grab change: first pickup, a second hand grabbing, either
## hand letting go, and the full drop.
func _sync_hands() -> void:
	# Null when a snap zone holds us: only hands are locked and gripped.
	var primary_pickup := get_picked_up_by() as XRToolsFunctionPickup
	var primary_controller := get_picked_up_by_controller()
	var primary_hand : XRToolsHand = null
	if primary_pickup:
		primary_hand = XRToolsHand.find_instance(primary_pickup)

	var secondary_grab = _grab_driver.secondary if _grab_driver else null
	var second_hand : XRToolsHand = null
	if secondary_grab:
		var second_pickup := secondary_grab.by as XRToolsFunctionPickup
		if second_pickup:
			second_hand = XRToolsHand.find_instance(second_pickup)

	# Blade toggle and haptics follow the primary controller across a hand swap.
	if primary_controller != actual_controller:
		if actual_controller and actual_controller.button_pressed.is_connected(_on_controller_button_pressed):
			actual_controller.button_pressed.disconnect(_on_controller_button_pressed)
		actual_controller = primary_controller
		if actual_controller:
			actual_controller.button_pressed.connect(_on_controller_button_pressed)

	# Any hand that just let go gets its real grip animation back.
	for hand in [_holding_hand, _second_hand]:
		if is_instance_valid(hand) and hand != primary_hand and hand != second_hand:
			hand.force_grip_trigger()

	# A former primary that is no longer primary must be re-enabled, or the lock
	# would strand its pickup disabled.
	if is_instance_valid(_holding_pickup) and _holding_pickup != primary_pickup:
		_holding_pickup.enabled = true

	_holding_pickup = primary_pickup
	_holding_hand = primary_hand
	_second_hand = second_hand

	# Close both holding hands over the hilt (visual; input is still read).
	if is_instance_valid(_holding_hand):
		_holding_hand.force_grip_trigger(1.0)
	if is_instance_valid(_second_hand):
		_second_hand.force_grip_trigger(1.0)


## True while both hands hold the saber. A two-handed grip stiffens the blade,
## which a deflecting blaster reads to return the bolt harder and tighter.
func is_two_handed() -> bool:
	return _grab_driver != null and _grab_driver.primary != null and _grab_driver.secondary != null


## Keeps the saber stuck to the hand: the holding hand's pickup function is only
## live while a holster is within reach, so the grip can never drop the saber
## anywhere else. XRToolsFunctionPickup ignores the grip entirely while disabled.
func _update_hand_lock() -> void:
	if not is_instance_valid(_holding_pickup):
		return

	var holster := _find_holster_in_range()

	if holster:
		# Only hand the grip back once it is released, otherwise reaching for the
		# hip with the grip already squeezed would stow the saber by itself.
		if not _holding_pickup.enabled and not _is_grip_held():
			_holding_pickup.enabled = true

		# Nudge the player when a holster becomes usable.
		if holster != _holster_in_range:
			vibrate_controller()
	else:
		_holding_pickup.enabled = false

	_holster_in_range = holster


## Finds an empty holster close enough to the hilt to stow the saber into.
func _find_holster_in_range() -> XRToolsSnapZone:
	var hilt := _hilt_position()

	for node in get_tree().get_nodes_in_group("saber_holster"):
		var zone := node as XRToolsSnapZone
		if not is_instance_valid(zone) or not zone.enabled or zone.has_snapped_object():
			continue

		if hilt.distance_to(zone.global_position) <= zone.grab_distance:
			return zone

	return null


## Where the hand actually holds the saber. Measuring from here (rather than the
## body origin) guarantees the hilt collider overlaps the zone sphere, which is
## what lets the zone catch the saber on the "dropped" signal.
func _hilt_position() -> Vector3:
	var point := get_active_grab_point()
	return point.global_position if is_instance_valid(point) else global_position


func _is_grip_held() -> bool:
	if not actual_controller:
		return false

	return actual_controller.get_float(_holding_pickup.pickup_axis_action) > XRTools.get_grip_threshold()


## Returns the saber to its holster once it has been left lying around.
func _recall_to_holster() -> void:
	if is_picked_up() or not is_instance_valid(home_zone):
		return

	# Do not fight the player if something else filled the holster meanwhile.
	if is_instance_valid(home_zone.picked_up_object):
		return

	# Still tumbling or mid-fall: give it another moment to settle.
	if linear_velocity.length() > RECALL_REST_SPEED and _recall_retries < RECALL_MAX_RETRIES:
		_recall_retries += 1
		_recall_timer.start(recall_delay)
		return

	home_zone.pick_up_object(self)


func _on_controller_button_pressed(button_name : String) -> void:
	if button_name == TOGGLE_BUTTON:
		toggle_lightsaber()


func toggle_lightsaber(force_state = null) -> void:
	var new_state : int

	if force_state != null:
		new_state = lightsaber_states.ON if force_state else lightsaber_states.OFF
	else:
		new_state = lightsaber_states.ON if current_lightsaber_state == lightsaber_states.OFF else lightsaber_states.OFF

	# Already there: stowing a blade that is off must not replay the retraction.
	if new_state == current_lightsaber_state:
		return

	current_lightsaber_state = new_state

	if new_state == lightsaber_states.ON:
		animation_settings.turn_lightsaber_on()
		trigger_haptic_ignition()
	else:
		animation_settings.turn_lightsaber_off()
		trigger_haptic_retract()

	if audios_manager:
		audios_manager.set_hum_active(new_state == lightsaber_states.ON)


func vibrate_controller() -> void:
	if actual_controller:
		actual_controller.trigger_haptic_pulse("haptic", 100.0, 1.0, 0.1, 0)


## Ignition: high amplitude, low frequency, to sell the raw energy surge.
func trigger_haptic_ignition() -> void:
	if actual_controller:
		actual_controller.trigger_haptic_pulse("haptic", 60.0, 1.0, 0.25, 0)


## Retraction: short and higher frequency, for the mechanical power-down feel.
func trigger_haptic_retract() -> void:
	if actual_controller:
		actual_controller.trigger_haptic_pulse("haptic", 80.0, 0.6, 0.15, 0)
