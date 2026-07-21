class_name Blaster
extends Area3D

## Group carried by the blade Area3D, used to tell a deflecting hit (blade)
## apart from an absorbing hit (hilt), since both share the Saber layer.
const BLADE_GROUP := &"lightsaber_blade"
## Safety cap when walking up the tree looking for the saber root.
const SABER_SEARCH_DEPTH := 8
## How far the bolt is pushed clear of the blade after a deflection, so the
## next frame's ray does not immediately hit the same blade again.
const DEFLECT_CLEARANCE := 0.05
## Widest angle the auto-aim assist will correct towards.
const AUTO_AIM_CONE := deg_to_rad(45.0)

enum DeflectMode {
	VECTOR, ## Physical ricochet off the cylindrical blade
	RETURN_TO_SENDER, ## Send the bolt back down its own firing line
}

@export var start_speed : float = 20.0
@export var max_lifetime : float = 2.0
## Layers the predictive raycast tests against (Player, Environment, Saber).
@export_flags_3d_physics var hit_layers : int = 7

var speed : float
var direction : Vector3 = Vector3.FORWARD

## Where the bolt was fired from, used by RETURN_TO_SENDER. The node is
## preferred so a moving shooter is still tracked; the position is the
## fallback for whoever fired without passing one.
var origin_node : Node3D = null
var origin_position : Vector3 = Vector3.ZERO

var _active : bool = false
var _time : float = 0.0

@export_group("Reflect Settings")
@export var deflect_mode : DeflectMode = DeflectMode.RETURN_TO_SENDER
@export_range(1.0, 3.0) var speed_multiplier : float = 1.5 # Speed-up per deflection
@export var max_speed : float = 60.0 # Ceiling, so repeated deflections cannot run away

@export_subgroup("Return To Sender")
## Blade speed (m/s) at which the return becomes perfectly accurate.
@export var swing_speed_for_perfect : float = 2.0
## Worst-case aim error when the blade is completely still, in degrees.
@export_range(0.0, 90.0) var max_return_deviation : float = 25.0

@export_subgroup("Vector")
@export_range(0.0, 2.0) var swing_power : float = 0.5 # How hard the arm pushes the bolt
@export_range(0.0, 1.0) var auto_aim_assist : float = 0.2 # 0 = none, 1 = homing


func _ready() -> void:
	# The bolt drives its own world transform. top_level must be set before
	# activate() ever writes a global position: flipping it afterwards would
	# reinterpret the local transform as global and teleport the bolt.
	top_level = true
	speed = start_speed
	deactivate()


func _physics_process(delta: float) -> void:
	if not _active:
		return

	var step_distance := speed * delta
	var end := global_position + direction * step_distance

	# Predictive raycast: test where the bolt *will* be before moving it, so a
	# fast bolt cannot tunnel through the blade between two frames.
	var query := PhysicsRayQueryParameters3D.create(global_position, end)
	query.collision_mask = hit_layers
	query.collide_with_areas = true
	query.collide_with_bodies = true
	query.exclude = [get_rid()]

	var result := get_world_3d().direct_space_state.intersect_ray(query)
	if result:
		var collider := result.collider as Node3D
		var saber := _find_saber_root(collider)
		if saber and collider.is_in_group(BLADE_GROUP):
			global_position = result.position
			reflect(collider, saber)
		else:
			# Hilt, wall, floor or player: the bolt is absorbed.
			deactivate()
			return
	else:
		global_position = end

	_time += delta
	if _time >= max_lifetime:
		deactivate()


## Walks up from the hit collider until it finds the node exposing the saber
## API. Returns null when the collider does not belong to a lightsaber.
func _find_saber_root(from: Node) -> Node:
	var node := from
	var depth := 0
	while node and depth < SABER_SEARCH_DEPTH:
		if node.has_method("get_saber_velocity"):
			return node
		node = node.get_parent()
		depth += 1
	return null


func is_active() -> bool:
	return _active


func deactivate() -> void:
	_active = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)


func activate(start_position : Vector3, start_rotation : Vector3, p_origin : Node3D = null) -> void:
	speed = start_speed
	_time = 0.0
	visible = true
	global_position = start_position
	global_rotation = start_rotation

	origin_node = p_origin
	origin_position = start_position

	# -Z is forward in Godot, matching the look_at() used after a deflection.
	direction = -global_transform.basis.z.normalized()

	_active = true
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)


func reflect(blade : Node3D, saber : Node) -> void:
	var saber_velocity : Vector3 = saber.get_saber_velocity()

	match deflect_mode:
		DeflectMode.RETURN_TO_SENDER:
			direction = _return_direction(saber_velocity)
		_:
			direction = _ricochet_direction(blade, saber_velocity)

	speed = minf(speed * speed_multiplier, max_speed)
	_time = 0.0 # A deflected bolt gets a fresh lifetime

	# Step clear of the blade so the next ray does not hit it again.
	global_position += direction * DEFLECT_CLEARANCE

	if "audios_manager" in saber:
		var audios : Node = saber.audios_manager
		if audios and audios.has_method("play_blaster_block_sound"):
			audios.play_blaster_block_sound()

	if saber.has_method("vibrate_controller"):
		saber.vibrate_controller()

	# look_at() fails when the direction is parallel to the up vector.
	if absf(direction.dot(Vector3.UP)) < 0.999:
		look_at(global_position + direction)


## Sends the bolt back down its own firing line. A still blade only deflects it
## roughly homewards; the faster the blade is moving, the tighter the return.
func _return_direction(saber_velocity: Vector3) -> Vector3:
	var target := origin_position
	if is_instance_valid(origin_node):
		target = origin_node.global_position

	var to_origin := target - global_position
	if to_origin.length_squared() < 0.000001:
		# Already on top of the shooter, nothing sensible to aim at.
		return -direction

	var accuracy := clampf(saber_velocity.length() / swing_speed_for_perfect, 0.0, 1.0)
	return _spread(to_origin.normalized(), deg_to_rad(max_return_deviation) * (1.0 - accuracy))


## Rotates a direction by a random angle up to `spread`, around a random axis
## perpendicular to it, giving an even cone of error.
func _spread(dir: Vector3, spread: float) -> Vector3:
	if spread <= 0.0:
		return dir

	var axis := dir.cross(Vector3.UP)
	if axis.length_squared() < 0.000001:
		axis = dir.cross(Vector3.RIGHT)
	axis = axis.normalized().rotated(dir, randf() * TAU)

	return dir.rotated(axis, randf() * spread)


## Physical ricochet: treats the blade as a cylinder and drops the component
## along its axis, so bolts always bounce outwards horizontally instead of
## erratically upwards.
func _ricochet_direction(blade: Node3D, saber_velocity: Vector3) -> Vector3:
	var blade_axis := blade.global_transform.basis.y.normalized()
	var hit_offset := global_position - blade.global_position
	var cylinder_normal := hit_offset - hit_offset.dot(blade_axis) * blade_axis

	if cylinder_normal.length_squared() < 0.000001:
		# Impact dead on the blade axis: there is no meaningful surface normal,
		# so bounce the bolt straight back rather than let it pass through and
		# re-collide every frame.
		cylinder_normal = -direction
	cylinder_normal = cylinder_normal.normalized()

	# A stationary blade blocks passively; swinging adds the arm's force vector.
	var raw_direction := direction.bounce(cylinder_normal) + saber_velocity * swing_power
	return apply_auto_aim(raw_direction, auto_aim_assist).normalized()


func apply_auto_aim(current_dir: Vector3, strength: float) -> Vector3:
	if strength <= 0.0 or current_dir.length_squared() < 0.000001:
		return current_dir

	var best_dir := Vector3.ZERO
	var best_angle := AUTO_AIM_CONE
	var has_target := false

	for target in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := target as Node3D
		if not enemy:
			continue
		var to_enemy := (enemy.global_position - global_position).normalized()
		var angle := current_dir.angle_to(to_enemy)
		if angle < best_angle:
			best_angle = angle
			best_dir = to_enemy
			has_target = true

	return current_dir.lerp(best_dir, strength) if has_target else current_dir
