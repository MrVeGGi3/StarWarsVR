class_name ForcePower
extends Node3D

## Force Push and Force Pull for one hand.
##
## Sits under an [XRController3D], next to the [XRToolsFunctionPickup], and only
## acts while that hand is empty: the hand holding the lightsaber cannot use the
## Force. With both hands free the power is multiplied.
##
## Targets are anything in the [code]force_object[/code] group. Selection is pure
## vector math (squared distance plus a dot product against the aim) — no physics
## queries and no line-of-sight checks, so a large scene stays cheap.


## Group every object the Force can move belongs to.
const FORCE_GROUP := "force_object"

## Analog trigger value above which the button counts as held.
const TRIGGER_THRESHOLD := 0.6

## Fraction of push_thrust_speed the hand must slow below to re-arm the push.
const PUSH_REARM_FACTOR := 0.3

## Cap on how fast a pulled object may fly, so distant targets don't teleport.
const PULL_MAX_SPEED := 14.0

## Below this hand speed, letting go simply drops the target instead of throwing.
const THROW_MIN_SPEED := 0.6


@export_group("Push")
## How far the push reaches.
@export var push_range : float = 6.0
## Half-angle of the push cone, in degrees.
@export_range(1.0, 90.0) var push_angle : float = 45.0
## Velocity change applied to a target at point blank, in m/s.
@export var push_impulse : float = 8.0
## Forward hand speed needed to fire the push, in m/s.
@export var push_thrust_speed : float = 1.5

@export_group("Pull")
## How far the pull can reach out for a target.
@export var pull_range : float = 12.0
## Half-angle of the aim cone used to acquire a target, in degrees.
@export_range(1.0, 90.0) var pull_angle : float = 12.0
## Where the target floats, in metres in front of the palm.
@export var pull_hold_distance : float = 0.6
## How hard the target is dragged towards the hold point.
@export var pull_speed : float = 8.0
## Throw speed given to a released target, in m/s.
@export var throw_impulse : float = 6.0

@export_group("Power")
## Multiplier applied while both hands are empty.
@export var empty_hands_multiplier : float = 1.6


var _controller : XRController3D
var _pickup : XRToolsFunctionPickup
var _other_pickup : XRToolsFunctionPickup

# Same averager the pickup function uses to measure throws.
var _velocity_averager := XRToolsVelocityAverager.new(5)

var _target : RigidBody3D = null
var _target_gravity_scale : float = 1.0
var _push_armed : bool = true


func _ready() -> void:
	_controller = XRHelpers.get_xr_controller(self)
	_pickup = XRToolsFunctionPickup.find_instance(self)

	# The other hand decides whether the power is boosted.
	var left := XRToolsFunctionPickup.find_left(self)
	var right := XRToolsFunctionPickup.find_right(self)
	_other_pickup = right if _pickup == left else left

	# Without these the hand-busy test silently reports "free" forever.
	if not _controller or not _pickup or not _other_pickup:
		push_warning("%s: expected to sit under an XRController3D that has an XRToolsFunctionPickup" % name)


func _exit_tree() -> void:
	_release_target()


func _physics_process(delta: float) -> void:
	if not _controller or not _controller.get_is_active():
		_release_target()
		return

	_velocity_averager.add_transform(delta, global_transform)

	# The hand holding the saber - or anything else - cannot use the Force.
	if _is_hand_busy():
		_release_target()
		return

	var trigger := _controller.get_float("trigger") > TRIGGER_THRESHOLD
	var grip := _controller.get_float("grip") > XRTools.get_grip_threshold()

	if trigger and grip:
		_process_pull()
	elif is_instance_valid(_target):
		# Letting go of either button throws whatever is being held.
		_throw()
	elif trigger:
		_process_push()
	else:
		_push_armed = true


func _is_hand_busy() -> bool:
	return is_instance_valid(_pickup) and is_instance_valid(_pickup.picked_up_object)


## Both hands free means a stronger Force.
func _power() -> float:
	if is_instance_valid(_other_pickup) and is_instance_valid(_other_pickup.picked_up_object):
		return 1.0

	return empty_hands_multiplier


# -- Push ---------------------------------------------------------------------


func _process_push() -> void:
	var forward := -global_transform.basis.z
	var thrust := _velocity_averager.linear_velocity().dot(forward)

	if not _push_armed:
		# One blast per thrust: re-arm once the hand has slowed back down, so the
		# player can keep shoving without releasing the trigger.
		if thrust < push_thrust_speed * PUSH_REARM_FACTOR:
			_push_armed = true
		return

	if thrust < push_thrust_speed:
		return

	_push_armed = false

	var power := _power()
	var origin := global_position
	var pushed := false

	for body in _targets_in_cone(push_range, push_angle):
		var to_target := body.global_position - origin
		var distance := to_target.length()
		var direction := to_target / distance if distance > 0.001 else forward
		var strength := push_impulse * power * (1.0 - distance / push_range)

		if body is RigidBody3D:
			# Scaling by mass makes push_impulse read as a velocity change, so
			# heavy props resist the shove instead of ignoring their weight.
			body.sleeping = false
			body.apply_central_impulse(direction * strength * body.mass)
		else:
			body.force_push(direction * strength)

		pushed = true

	if pushed:
		_controller.trigger_haptic_pulse("haptic", 50.0, 1.0, 0.2, 0)


# -- Pull ---------------------------------------------------------------------


func _process_pull() -> void:
	if not is_instance_valid(_target):
		var found := _find_pull_target()
		if not found:
			return

		_grab_target(found)

	# Telekinetic hold: drive the body towards a point in front of the palm.
	# Rewriting the velocity every frame damps itself as the target arrives.
	var hold := global_position - global_transform.basis.z * pull_hold_distance
	var velocity := (hold - _target.global_position) * pull_speed * _power()

	if velocity.length() > PULL_MAX_SPEED:
		velocity = velocity.normalized() * PULL_MAX_SPEED

	_target.linear_velocity = velocity
	_target.angular_velocity *= 0.9


## Picks the object nearest the aim line, biased slightly towards closer ones.
func _find_pull_target() -> RigidBody3D:
	var origin := global_position
	var forward := -global_transform.basis.z
	var best : RigidBody3D = null
	var best_score := INF

	for node in _targets_in_cone(pull_range, pull_angle):
		var body := node as RigidBody3D
		if not body:
			continue

		var to_target := body.global_position - origin
		var along := to_target.dot(forward)
		var score := (to_target - forward * along).length() + to_target.length() * 0.1

		if score < best_score:
			best_score = score
			best = body

	return best


func _grab_target(body : RigidBody3D) -> void:
	_target = body
	_target_gravity_scale = body.gravity_scale
	body.gravity_scale = 0.0
	body.sleeping = false

	_controller.trigger_haptic_pulse("haptic", 80.0, 0.5, 0.1, 0)


func _throw() -> void:
	var body := _target
	_release_target()

	# The trigger is very likely still held; don't let it fire a push as well.
	_push_armed = false

	if not is_instance_valid(body):
		return

	var hand_velocity := _velocity_averager.linear_velocity()
	var speed := hand_velocity.length()

	# Letting go without a shove just drops the object.
	if speed < THROW_MIN_SPEED:
		return

	var boost := clampf(speed / push_thrust_speed, 0.0, 1.0)
	body.linear_velocity = (hand_velocity / speed) * throw_impulse * _power() * boost

	_controller.trigger_haptic_pulse("haptic", 60.0, 0.8, 0.15, 0)


func _release_target() -> void:
	if is_instance_valid(_target):
		_target.gravity_scale = _target_gravity_scale

	_target = null


# -- Target selection ---------------------------------------------------------


## All movable targets inside the cone. Squared distance first, dot product
## second - no physics query, and no walls are taken into account.
func _targets_in_cone(max_distance : float, half_angle : float) -> Array[Node3D]:
	var result : Array[Node3D] = []

	var origin := global_position
	var forward := -global_transform.basis.z
	var max_distance_sq := max_distance * max_distance
	var min_dot := cos(deg_to_rad(half_angle))

	for node in get_tree().get_nodes_in_group(FORCE_GROUP):
		var body := node as Node3D
		if not _is_movable(body):
			continue

		var to_target := body.global_position - origin
		var distance_sq := to_target.length_squared()
		if distance_sq > max_distance_sq or distance_sq < 0.0001:
			continue

		if forward.dot(to_target / sqrt(distance_sq)) < min_dot:
			continue

		result.push_back(body)

	return result


func _is_movable(body : Node3D) -> bool:
	if not is_instance_valid(body):
		return false

	# Never yank something out of a hand or a holster.
	if body.has_method("is_picked_up") and body.is_picked_up():
		return false

	return body is RigidBody3D or body.has_method("force_push")
