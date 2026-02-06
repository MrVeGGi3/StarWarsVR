class_name Blaster
extends Area3D

@export var start_speed : float = 20.0 
@export var max_lifetime : float = 2.0

var speed : float
var _active : bool = false
var _time : float = 0.0
var direction : Vector3 = Vector3.FORWARD

@export_group("Reflect Settings")
@export_range(0.0, 2.0) var swing_power : float = 0.5 # O quanto o braço "empurra" o tiro
@export_range(1.0, 3.0) var speed_multiplier : float = 1.5 # Aceleração ao rebater
@export_range(0.0, 1.0) var auto_aim_assist : float = 0.2 # "Imã" para ajudar a mirar (0 = nada, 1 = teleguiado)

func _ready() -> void:
	speed = start_speed
	deactivate()

func _physics_process(delta: float) -> void:
	if not _active:
		return
	
	# 1. Movimento previsto
	var step_distance = speed * delta
	
	# 2. Raycast
	var space_state = get_world_3d().direct_space_state
	var origin = global_position
	var end = global_position + (direction * step_distance)
	
	var query = PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 4
	query.collide_with_areas = true 
	query.collide_with_bodies = true
	
	var result = space_state.intersect_ray(query)
	
	if result:
		# BATEU! Vamos procurar quem é o dono desse colisor
		var collider = result.collider
		
		# --- A CORREÇÃO MÁGICA ---
		# Procura o nó que tem o script, subindo a hierarquia
		var saber_script = encontrar_script_sabre(collider)
			
		if saber_script:
			# É UM SABRE! REFLETIR!
			print("Refletido pelo nó: ", saber_script.name)
			global_position = result.position
			reflect(result.collider, saber_script)
		else:
			# É PAREDE/CHÃO
			deactivate()
	else:
		# CAMINHO LIVRE
		global_position += direction * step_distance
	
	_time += delta
	if _time >= max_lifetime:
		deactivate()

# --- NOVA FUNÇÃO AUXILIAR ---
# Essa função sobe a hierarquia (Filho -> Pai -> Avô) até achar o método
func encontrar_script_sabre(node_inicial: Node) -> Node:
	return node_inicial.get_parent()

func deactivate():
	_active = false
	visible = false
	set_deferred("monitoring", false)
	set_deferred("monitorable", false)

func activate(start_position : Vector3, start_rotation : Vector3):
	speed = start_speed
	visible = true
	global_position = start_position
	global_rotation = start_rotation
	
	# Direção baseada na rotação recebida
	direction = global_transform.basis.z.normalized() 
	
	_time = 0.0
	_active = true
	set_deferred("monitorable", true)
	set_deferred("monitoring", true)
	top_level = true

func reflect(saber_area : Area3D, saber_script_node : Node):

	var saber_axis_up = saber_area.global_transform.basis.y.normalized()
	
	var hand_to_hit = global_position - saber_area.global_position
	
	var vertical_component = hand_to_hit.dot(saber_axis_up) * saber_axis_up
	
	var normal_cilindrica = (hand_to_hit - vertical_component).normalized()
	
	var reflection_direction = direction.bounce(normal_cilindrica)
	
	var saber_vel = saber_script_node.get_saber_velocity()
	var swing_influence = saber_vel * swing_power 
	
	var raw_direction = reflection_direction + swing_influence
	
	var final_direction = apply_auto_aim(raw_direction, auto_aim_assist)
	
	direction = final_direction.normalized()
	speed *= speed_multiplier
	
	if saber_script_node.get("audios_manager"):
		saber_script_node.audios_manager.play_blaster_block_sound()
	
	saber_script_node.vibrate_controller()
	
	look_at(global_position + direction)
	
func apply_auto_aim(current_dir: Vector3, strength: float) -> Vector3:
	if strength <= 0.0: return current_dir
	
	var targets = get_tree().get_nodes_in_group("enemies")
	var best_target = null
	var best_angle = deg_to_rad(45.0) # Só ajuda se estiver num cone de 45 graus
	
	for target in targets:
		var dir_to_enemy = (target.global_position - global_position).normalized()
		var angle = current_dir.angle_to(dir_to_enemy)
		if angle < best_angle:
			best_angle = angle
			best_target = dir_to_enemy
	
	if best_target:
		return current_dir.lerp(best_target, strength)
	
	return current_dir
