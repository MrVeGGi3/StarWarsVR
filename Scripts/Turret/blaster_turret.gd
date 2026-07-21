class_name Turret
extends Node3D

@export var blaster_scene : PackedScene
@export var pool_size : int = 10
## Seconds between shots.
@export var fire_interval : float = 3.0

@export var muzzle : Marker3D

var pool : Array[Blaster] = []

var _fire_timer : Timer


func _ready() -> void:
	set_initial_pool()

	# A timer beats polling shoot() every frame: no per-frame work, no log
	# spam, and the cadence no longer depends on the render rate.
	_fire_timer = Timer.new()
	_fire_timer.wait_time = fire_interval
	_fire_timer.autostart = true
	_fire_timer.timeout.connect(shoot)
	add_child(_fire_timer)


func set_initial_pool() -> void:
	for i in range(pool_size):
		var blaster := blaster_scene.instantiate() as Blaster
		add_child(blaster)
		pool.append(blaster)


func get_blaster_from_pool() -> Blaster:
	for blaster in pool:
		if not blaster.is_active():
			return blaster
	return null


func shoot() -> void:
	var current_blaster := get_blaster_from_pool()
	if current_blaster:
		# The muzzle doubles as the return target for deflected bolts.
		current_blaster.activate(muzzle.global_position, muzzle.global_rotation, muzzle)
