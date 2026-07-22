class_name TrainingDroid
extends Turret

## Jedi training remote.
##
## Loops: circles the player at head height, stops, draws one of its firing
## ports, swings that port around to face the player while a red light winds up
## as a warning, shoots, then goes back to circling.
##
## Reuses [Turret] for the blaster pool and for [method Turret.shoot]: the
## exported [member Turret.muzzle] marker is moved onto the drawn port, so the
## bolt leaves the right hole and deflections return to it. Keep
## [member Turret.fire_interval] at 0 in the scene - the cadence lives here.


enum State {
	ORBIT, ## Circling the player
	AIM, ## Stopped, port turning towards the player, warning light rising
	BURST, ## Between shots of a burst, swinging onto the next height
	RECOVER, ## Brief beat after the shot
}


@export_group("Orbit")
## Distance kept from the player while circling.
@export var orbit_distance : float = 2.5
## How fast the droid sweeps around the player, in radians per second.
@export var orbit_speed : float = 0.9
## How fast the droid closes on its orbit anchor, in m/s.
@export var move_speed : float = 1.8
## How far above and below the player's head the droid may hover.
@export var height_range : float = 0.35
## Random length of a circling stretch, in seconds.
@export var orbit_time : Vector2 = Vector2(1.2, 2.4)
## Idle tumble while circling, in radians per second.
@export var idle_spin_speed : float = 0.8

@export_group("Attack")
## Warning time between drawing a port and firing it.
@export var aim_time : float = 1.1
## Pause after the shot before circling again.
@export var recover_time : float = 0.6
## How briskly the droid swings the port onto the player.
@export var aim_sharpness : float = 6.0
## How far out of the droid's centre the port sits, in metres.
@export var muzzle_offset : float = 0.09
## Random miss radius around the aim point, in metres.
@export var aim_scatter : float = 0.15
## Emission the warning light reaches right before the shot.
@export var warning_energy : float = 6.0
## Heights the droid picks between, drawn fresh per shot, as a fraction of the
## player's head-above-floor height: 1.0 head, ~0.6 chest, ~0.4 thigh. Being a
## fraction and not a fixed drop, the bands follow the player up and down. The
## lowest is deliberately thigh height, not the knee, so shots never read as
## aimed at the feet.
@export var aim_height_fractions : Array[float] = [1.0, 0.6, 0.4]
## Lowest the droid aims while the player stands, in metres above the floor.
## Set to the upper thigh so the low band never drops to the knees or feet.
@export var min_aim_height : float = 0.65
## Lowest the droid aims while the player sits, in metres above the floor.
## Higher than standing: a seated body has no target near the floor, so the low
## band is lifted towards the lap/torso instead of the feet. Capped just under
## the head so shots never rise above it however low the player sits.
@export var seated_min_aim_height : float = 0.8
## Head-above-floor counted as fully standing, in metres. At or above this the
## standing clamp is used.
@export var standing_head_height : float = 1.5
## Head-above-floor counted as fully seated, in metres. At or below this the
## seated clamp is used; between the two the clamp blends.
@export var seated_head_height : float = 0.9
## Head-above-floor assumed when no [XROrigin3D] floor can be found (flat play),
## in metres.
@export var assumed_standing_height : float = 1.7

@export_group("Burst")
## Most shots the droid may loose in one stop. The count is drawn per stop.
@export_range(1, 8) var max_burst : int = 3
## Gap between the shots of a burst, in seconds.
@export var burst_interval : float = 0.35
## How briskly the port swings onto the next height mid-burst. Higher than
## aim_sharpness because there is far less time to get there.
@export var burst_aim_sharpness : float = 14.0

@export_group("Feint")
## Odds that a stop is a bluff: the droid draws a port and turns it on the
## player, then breaks off without firing.
@export_range(0.0, 1.0) var fake_chance : float = 0.3
## How much of the warning window a feint plays before breaking off. Under 1.0
## the light never reaches full, which is the tell.
@export_range(0.1, 1.0) var fake_time_scale : float = 0.6

@export_group("Nodes")
## Parent of the [RayCast3D] nodes marking each firing port.
@export var ports_root : Node3D
## Mesh that glows red while a port is winding up. Child of the muzzle, so it
## rides along to whichever port was drawn.
@export var warning_light : MeshInstance3D
## Who to circle and shoot at. Falls back to the active camera, which in XR is
## the player's head.
@export var target : Node3D
## Positional audio players.
@export var audios_manager : DroidAudioManager


var _state : int = State.ORBIT
var _state_time : float = 0.0
var _orbit_duration : float = 0.0
var _orbit_angle : float = 0.0
var _orbit_direction : float = 1.0
var _height_offset : float = 0.0

# Port geometry, in droid space: it never changes as the droid turns.
var _port_directions : Array[Vector3] = []
var _port_origins : Array[Vector3] = []
var _current_port : int = -1

var _aim_duration : float = 0.0
var _is_feint : bool = false
var _shots_left : int = 0
var _aim_height_fraction : float = 1.0
var _aim_scatter_offset : Vector3 = Vector3.ZERO
var _warning_material : StandardMaterial3D
var _warning_tween : Tween
var _camera : Camera3D


func _ready() -> void:
	# Builds the blaster pool. No fire timer while fire_interval is 0.
	super._ready()

	_collect_ports()

	if warning_light:
		_warning_material = warning_light.material_override as StandardMaterial3D
		warning_light.visible = false

	_enter_orbit(_target_position())


func _physics_process(delta: float) -> void:
	var head := _target_position()

	match _state:
		State.ORBIT:
			_process_orbit(delta, head)
		State.AIM:
			_process_aim(delta, head)
		State.BURST:
			_process_burst(delta, head)
		State.RECOVER:
			_process_recover(delta, head)


# -- States -------------------------------------------------------------------


func _enter_orbit(head : Vector3) -> void:
	_state = State.ORBIT
	_state_time = 0.0
	_orbit_duration = randf_range(orbit_time.x, orbit_time.y)
	_orbit_direction = 1.0 if randf() < 0.5 else -1.0
	_height_offset = randf_range(-height_range, height_range)

	# Pick the orbit up from where the droid already is, so it never snaps.
	var offset := global_position - head
	_orbit_angle = atan2(offset.z, offset.x)


func _process_orbit(delta: float, head : Vector3) -> void:
	_orbit_angle += orbit_speed * _orbit_direction * delta

	var anchor := head + Vector3(
			cos(_orbit_angle) * orbit_distance,
			_height_offset,
			sin(_orbit_angle) * orbit_distance)

	var step := move_speed * delta
	var before := global_position
	global_position = global_position.move_toward(anchor, step)
	rotate_y(idle_spin_speed * delta)

	if audios_manager:
		# How much of the available step was actually used: 0 parked, 1 flat out.
		audios_manager.set_hover_speed(before.distance_to(global_position) / maxf(step, 0.000001))

	_state_time += delta
	if _state_time >= _orbit_duration:
		_enter_aim()


func _enter_aim() -> void:
	if _port_directions.is_empty():
		return

	_state = State.AIM
	_state_time = 0.0
	_draw_port()

	# A feint runs the same draw and turn, just cut short and with no shot.
	_is_feint = randf() < fake_chance
	_aim_duration = aim_time * (fake_time_scale if _is_feint else 1.0)
	_shots_left = 0 if _is_feint else randi_range(1, max_burst)

	_draw_aim_point()

	# Always wound up over the full aim_time, so a feint visibly and audibly
	# breaks off before the light tops out.
	_start_warning(aim_time)

	if audios_manager:
		audios_manager.set_hover_speed(0.0)
		audios_manager.play_servo()
		audios_manager.start_charge(aim_time)


func _process_aim(delta: float, head : Vector3) -> void:
	# Keep tracking: the player is free to move during the wind-up.
	_turn_port_towards(_aim_point(head), delta, aim_sharpness)

	_state_time += delta
	if _state_time < _aim_duration:
		return

	if _is_feint:
		_enter_recover()
	else:
		_fire_shot()


## Fires, then either lines up the next shot of the burst or breaks off.
func _fire_shot() -> void:
	shoot()
	if audios_manager:
		audios_manager.play_fire()

	_shots_left -= 1
	if _shots_left <= 0:
		_enter_recover()
		return

	# Next shot goes somewhere else on the player.
	_draw_aim_point()

	_state = State.BURST
	_state_time = 0.0

	_start_warning(burst_interval)
	if audios_manager:
		audios_manager.start_charge(burst_interval)


func _process_burst(delta: float, head : Vector3) -> void:
	_turn_port_towards(_aim_point(head), delta, burst_aim_sharpness)

	_state_time += delta
	if _state_time >= burst_interval:
		_fire_shot()


func _enter_recover() -> void:
	_state = State.RECOVER
	_state_time = 0.0
	_stop_warning()

	if audios_manager:
		audios_manager.stop_charge()


func _process_recover(delta: float, head : Vector3) -> void:
	_state_time += delta
	if _state_time >= recover_time:
		_enter_orbit(head)


# -- Aiming -------------------------------------------------------------------


## Where the current shot is headed: the player's line at the drawn height band,
## plus scatter, clamped so it never drops to the feet (posture-aware) nor rises
## above the head.
func _aim_point(head : Vector3) -> Vector3:
	var floor_y := _floor_height(head)
	var head_above_floor := head.y - floor_y
	var y := lerpf(floor_y, head.y, _aim_height_fraction)

	var point := Vector3(head.x, y, head.z) + _aim_scatter_offset
	point.y = clampf(point.y, floor_y + _min_aim_above_floor(head_above_floor), head.y)
	return point


## The low clamp, blended from the standing value to the seated value as the head
## drops. Kept just below the head so a low seated player is never shot overhead.
func _min_aim_above_floor(head_above_floor : float) -> float:
	var t := clampf(
			inverse_lerp(seated_head_height, standing_head_height, head_above_floor),
			0.0, 1.0)
	var minimum := lerpf(seated_min_aim_height, min_aim_height, t)

	# Never let the floor clamp reach the head, or the whole band collapses onto
	# (or above) it and there is no spread left.
	return minf(minimum, maxf(head_above_floor - 0.15, 0.0))


## Height of the player's floor. The XR origin sits on it, so bands measured up
## from here shrink when the player sits. Falls back to a fixed drop below the
## head when there is no origin (flat play).
func _floor_height(head : Vector3) -> float:
	var ref : Node3D = target if is_instance_valid(target) else _camera
	var origin := XRHelpers.get_xr_origin(ref) if is_instance_valid(ref) else null
	if is_instance_valid(origin):
		return origin.global_position.y

	return head.y - assumed_standing_height


## Draws the height this shot goes for - head, midriff or legs - and the miss
## offset around it.
func _draw_aim_point() -> void:
	_aim_height_fraction = 1.0
	if not aim_height_fractions.is_empty():
		_aim_height_fraction = aim_height_fractions[randi() % aim_height_fractions.size()]

	_aim_scatter_offset = Vector3(
			randf_range(-aim_scatter, aim_scatter),
			randf_range(-aim_scatter, aim_scatter),
			randf_range(-aim_scatter, aim_scatter))


## Rotates the whole droid so the drawn port ends up pointing at [param point].
## Works off the shortest rotation from where the port currently points, so it
## converges frame by frame and follows a moving target.
func _turn_port_towards(point : Vector3, delta: float, sharpness: float) -> void:
	var desired := point - global_position
	if desired.length_squared() < 0.000001:
		return
	desired = desired.normalized()

	var current := (global_basis * _port_directions[_current_port]).normalized()
	var rotation_quaternion := global_basis.get_rotation_quaternion()
	var aimed := Quaternion(current, desired) * rotation_quaternion

	# Exponential approach: frame-rate independent, and eases in on its own.
	var weight := 1.0 - exp(-sharpness * delta)
	global_basis = Basis(rotation_quaternion.slerp(aimed, weight)).scaled(global_basis.get_scale())


## Draws a port and parks the muzzle on it. The muzzle is a child of the droid,
## so from here on it turns with the body and Turret.shoot() fires down the
## right hole with no further work.
func _draw_port() -> void:
	var index := randi() % _port_directions.size()
	if _port_directions.size() > 1 and index == _current_port:
		index = (index + 1) % _port_directions.size()

	_current_port = index

	if not muzzle:
		return

	var direction : Vector3 = _port_directions[index]
	muzzle.position = _port_origins[index] + direction * muzzle_offset
	muzzle.basis = _looking_basis(direction)


## Basis whose -Z runs along [param direction], which is the forward the bolt
## reads from its rotation.
func _looking_basis(direction : Vector3) -> Basis:
	var up := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	return Basis.looking_at(direction, up)


# -- Warning light ------------------------------------------------------------


func _start_warning(duration: float) -> void:
	if not _warning_material:
		return

	warning_light.visible = true

	if _warning_tween:
		_warning_tween.kill()

	_warning_tween = create_tween()
	_warning_tween.tween_property(
			_warning_material, "emission_energy_multiplier", warning_energy, duration).from(0.0)


func _stop_warning() -> void:
	if not _warning_material:
		return

	if _warning_tween:
		_warning_tween.kill()

	_warning_tween = create_tween()
	_warning_tween.tween_property(
			_warning_material, "emission_energy_multiplier", 0.0, recover_time * 0.5)
	_warning_tween.tween_callback(func(): warning_light.visible = false)


# -- Setup --------------------------------------------------------------------


## Reads each port's direction and position once, in droid space. The raycasts
## are only there to author those directions, so their queries are switched off.
func _collect_ports() -> void:
	if not ports_root:
		return

	for child in ports_root.get_children():
		var ray := child as RayCast3D
		if not ray:
			continue

		var relative := global_transform.affine_inverse() * ray.global_transform
		var direction := (relative.basis * ray.target_position)
		if direction.length_squared() < 0.000001:
			continue

		ray.enabled = false
		_port_directions.append(direction.normalized())
		_port_origins.append(relative.origin)


## The player's head. Falls back to the active camera, which is the XRCamera3D
## once the headset is running.
func _target_position() -> Vector3:
	if is_instance_valid(target):
		return target.global_position

	if not is_instance_valid(_camera):
		_camera = get_viewport().get_camera_3d()

	return _camera.global_position if is_instance_valid(_camera) else global_position
