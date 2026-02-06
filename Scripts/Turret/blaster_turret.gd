class_name Turret
extends Node3D

@export var blaster_scene : PackedScene
@export var pool_size : int = 10
@export var fire_rate : float = 3.0

@export var muzzle : Marker3D

var pool : Array = []
var can_shoot : bool = true

# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	set_initial_pool()


func set_initial_pool():
	for i in range(pool_size):
		var blaster = blaster_scene.instantiate()
		add_child(blaster)
		pool.append(blaster)

func get_blaster_from_pool():
	for blaster in pool:
		if not blaster._active:
			return blaster


func shoot():
	if not can_shoot:
		print("Não posso Atirar Agora")
		return
		
	print("Estou Atirando")
	
	var current_blaster = get_blaster_from_pool()
	
	if current_blaster:
		current_blaster.activate(muzzle.global_position, muzzle.global_rotation)
		start_cooldown()

func start_cooldown():
	can_shoot = false
	await get_tree().create_timer(fire_rate).timeout
	can_shoot = true
	

func _process(_delta: float) -> void:
	shoot()
	
