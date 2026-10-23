class_name Enemy
extends CharacterBody3D

const HIT_FLASH_DURATION: float = 0.18
const ATTACK_LUNGE_DURATION: float = 0.22

var alert: bool = false
var detected: bool = false
var checking: bool = false
var is_wandering: bool = false
var target: Vector3
var move_speed: float = 3.0

@export_category("Atributos de Vida e Combate")
@export var max_health: float = 100.0
@export var attack_range: float = 1.8
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.0

@export_category("Movimentação e Campo de Visão")
@export var wander_speed: float = 3.0
@export var chase_speed: float = 4.5
@export var vision_range: float = 15.0
@export var vision_angle_deg: float = 110.0
@export var alert_innacuracy: float = 5.0
@export var deaggro_radius: float = 18.0

var health: float = 100.0
var is_dead: bool = false

var _attack_cooldown_timer: float = 0.0
var _attack_lunge_timer: float = 0.0
var _attack_lunge_dir: Vector3 = Vector3.ZERO
var _hit_flash_timer: float = 0.0
var _flinch_offset: Vector3 = Vector3.ZERO
var _investigating_last_seen: bool = false
var _spotted_grace_timer: float = 0.0

var _base_color: Color = Color(0.0, 1.0, 0.0, 1.0)
var _base_shape_pos: Vector3 = Vector3.ZERO
var _enemy_material: StandardMaterial3D = null

@onready var shape_mesh: MeshInstance3D = $Shape
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var wander_timer: Timer = $wander_timer
@onready var wait_timer: Timer = $wait_timer


func _ready() -> void:
	health = max_health
	move_speed = wander_speed
	if shape_mesh != null:
		_base_shape_pos = shape_mesh.position
		_enemy_material = StandardMaterial3D.new()
		_enemy_material.albedo_color = _base_color
		_enemy_material.roughness = 0.65
		shape_mesh.material_override = _enemy_material


func _process(delta: float) -> void:
	if is_dead:
		return

	if _hit_flash_timer > 0.0:
		_hit_flash_timer = maxf(0.0, _hit_flash_timer - delta)
		if _enemy_material != null:
			var t := clampf(_hit_flash_timer / HIT_FLASH_DURATION, 0.0, 1.0)
			_enemy_material.albedo_color = _base_color.lerp(Color(1.0, 0.12, 0.12, 1.0), t)
			_enemy_material.emission_enabled = t > 0.01
			_enemy_material.emission = Color(0.95, 0.1, 0.1, 1.0)
			_enemy_material.emission_energy_multiplier = 1.35 * t
	elif _enemy_material != null and _enemy_material.emission_enabled:
		_enemy_material.albedo_color = _base_color
		_enemy_material.emission_enabled = false

	_flinch_offset = _flinch_offset.lerp(Vector3.ZERO, minf(1.0, delta * 14.0))

	var lunge_offset := Vector3.ZERO
	if _attack_lunge_timer > 0.0:
		_attack_lunge_timer = maxf(0.0, _attack_lunge_timer - delta)
		var p := 1.0 - (_attack_lunge_timer / ATTACK_LUNGE_DURATION)
		var wave := sin(p * PI)
		lunge_offset = _attack_lunge_dir * (0.28 * wave)

	if shape_mesh != null:
		shape_mesh.position = _base_shape_pos + _flinch_offset + lunge_offset


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_spotted_grace_timer = maxf(0.0, _spotted_grace_timer - delta)

	handle_grav(delta)

	var player: Player = Player.get_instance()
	if not alert:
		move_speed = wander_speed
		if can_see_player(player):
			target = player.global_position
			set_detect()
			detected_phys(delta)
		else:
			wander_phys()
	else:
		if detected:
			move_speed = chase_speed
			detected_phys(delta)
		else:
			move_speed = lerpf(wander_speed, chase_speed, 0.6)
			if can_see_player(player):
				target = player.global_position
				set_detect()
				detected_phys(delta)
			else:
				alert_phys()

	move_and_slide()


func handle_grav(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta


## Verifica se o player está dentro do cone de visão (110°), dentro do alcance (15m) e sem paredes opacas no caminho
func can_see_player(player: Player) -> bool:
	if player == null or not is_instance_valid(player) or player.is_dead:
		return false

	var to_player := player.global_position - global_position
	var dist := to_player.length()
	if dist > vision_range:
		return false

	var to_player_flat := Vector3(to_player.x, 0.0, to_player.z)
	if to_player_flat.length_squared() > 0.001:
		var dir_to_player := to_player_flat.normalized()
		var forward := -global_transform.basis.z
		var forward_flat := Vector3(forward.x, 0.0, forward.z).normalized()
		var cos_half_fov := cos(deg_to_rad(vision_angle_deg * 0.5))
		if forward_flat.dot(dir_to_player) < cos_half_fov:
			return false

	return has_line_of_sight_to_player(player)


## Verifica se não há paredes ou estruturas sem transparência bloqueando a linha de visão até o player
func has_line_of_sight_to_player(player: Player) -> bool:
	if player == null or not is_instance_valid(player) or player.is_dead:
		return false

	var eye_pos := global_position + Vector3(0.0, 0.45, 0.0)
	var player_head_pos := player.global_position + Vector3(0.0, 0.4, 0.0)
	var player_torso_pos := player.global_position

	if not _is_ray_blocked_by_opaque_structure(eye_pos, player_head_pos, player):
		return true
	if not _is_ray_blocked_by_opaque_structure(eye_pos, player_torso_pos, player):
		return true
	return false


func _is_ray_blocked_by_opaque_structure(from_pos: Vector3, to_pos: Vector3, player: Player) -> bool:
	var space_state := get_world_3d().direct_space_state
	var exclude_rids: Array[RID] = [get_rid()]
	if player != null and is_instance_valid(player):
		exclude_rids.append(player.get_rid())

	for _step in range(4):
		var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
		query.collision_mask = 1 | 4
		query.exclude = exclude_rids

		var result := space_state.intersect_ray(query)
		if result.is_empty():
			return false

		var hit_rid: RID = result.get("rid", RID())
		var collider: Object = result.get("collider")

		if collider is Enemy:
			if hit_rid.is_valid():
				exclude_rids.append(hit_rid)
				continue
			return false

		if _is_collider_transparent(collider):
			if hit_rid.is_valid():
				exclude_rids.append(hit_rid)
				continue
			return false

		# Bateu em uma estrutura sem transparência (parede, caixa, terreno, etc.)
		return true

	return true


func _is_collider_transparent(collider: Object) -> bool:
	if collider == null or not (collider is Node):
		return false

	var node := collider as Node
	var meshes: Array[MeshInstance3D] = []

	if node is MeshInstance3D:
		meshes.append(node as MeshInstance3D)
	if node.get_parent() is MeshInstance3D:
		meshes.append(node.get_parent() as MeshInstance3D)
	for child in node.get_children():
		if child is MeshInstance3D:
			meshes.append(child as MeshInstance3D)

	if meshes.is_empty():
		return false

	for m in meshes:
		var mat: Material = m.material_override
		if mat == null and m.mesh != null and m.mesh.get_surface_count() > 0:
			mat = m.get_active_material(0)
		if mat is BaseMaterial3D:
			var bmat := mat as BaseMaterial3D
			if bmat.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED and bmat.albedo_color.a < 0.9:
				return true

	return false


func wander_phys() -> void:
	if wait_timer.is_stopped():
		if nav_agent.is_navigation_finished() or wander_timer.is_stopped():
			if is_wandering:
				is_wandering = false
				wander_timer.stop()
				wait_timer.start()
			else:
				if wander_nav():
					is_wandering = true
	nav()


func wander_nav() -> bool:
	var map: RID = nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var target_pos := global_position + (dir * 10.0)
	var nav_pos := NavigationServer3D.map_get_closest_point(map, target_pos)
	nav_agent.target_position = nav_pos
	wander_timer.start(3.0)
	return true


func nav() -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next: Vector3 = nav_agent.get_next_path_position()
		var dir: Vector3 = next - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			var target_angle := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * get_physics_process_delta_time())
		else:
			velocity.x = 0.0
			velocity.z = 0.0


func alert_phys() -> void:
	if not checking:
		if alert_nav():
			checking = true
			wander_timer.start(6.0)
	else:
		if nav_agent.is_navigation_finished() or wander_timer.is_stopped():
			checking = false
			alert = false
			_investigating_last_seen = false
			wander_timer.stop()
			wait_timer.start()
	nav()


func alert_nav() -> bool:
	var map: RID = nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var search_target := target
	if not _investigating_last_seen:
		var innacuracy := Vector3(randf_range(-alert_innacuracy, alert_innacuracy), 0.0, randf_range(-alert_innacuracy, alert_innacuracy))
		search_target += innacuracy
	var nav_pos := NavigationServer3D.map_get_closest_point(map, search_target)
	nav_agent.target_position = nav_pos
	return true


func detected_phys(delta: float = 0.016) -> void:
	var player: Player = Player.get_instance()
	if not is_instance_valid(player) or player.is_dead:
		detected = false
		alert = false
		_investigating_last_seen = false
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var distance: float = global_position.distance_to(player.global_position)
	if distance >= deaggro_radius:
		# Saiu do raio máximo de perseguição: vai investigar a última posição vista
		detected = false
		alert = true
		checking = false
		_investigating_last_seen = true
		return

	var sees_player := can_see_player(player) or (_spotted_grace_timer > 0.0 and has_line_of_sight_to_player(player))
	if not sees_player:
		# Player entrou atrás de uma parede ou saiu do campo de visão: vai até a última posição onde o viu
		detected = false
		alert = true
		checking = false
		_investigating_last_seen = true
		return

	# Está vendo o player: atualiza a última posição conhecida
	target = player.global_position
	nav_agent.target_position = player.global_position

	# Verifica alcance de ataque corpo a corpo (melee)
	if distance <= attack_range:
		var to_p := player.global_position - global_position
		to_p.y = 0.0
		if to_p.length_squared() > 0.001:
			var dir_p := to_p.normalized()
			var target_angle := atan2(-dir_p.x, -dir_p.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 12.0 * delta)

		if _attack_cooldown_timer <= 0.0:
			_perform_attack(player)

	if distance <= 1.25:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		nav()


func _perform_attack(player: Player) -> void:
	_attack_cooldown_timer = attack_cooldown
	_attack_lunge_timer = ATTACK_LUNGE_DURATION
	var local_forward := Vector3(0.0, 0.0, -1.0)
	_attack_lunge_dir = local_forward
	if player != null and is_instance_valid(player):
		player.take_damage(attack_damage)


func set_alert(pos: Vector3) -> void:
	alert = true
	is_wandering = false
	wander_timer.stop()
	wait_timer.stop()
	if global_position.distance_squared_to(pos) < 4.0:
		set_detect()
		return
	else:
		target = pos
		checking = false
		_investigating_last_seen = false


func set_detect() -> void:
	alert = true
	detected = true
	checking = false
	is_wandering = false
	_investigating_last_seen = true
	_spotted_grace_timer = 1.2
	wander_timer.stop()
	wait_timer.stop()


func hit(damage: float = 25.0, hit_point: Vector3 = Vector3.ZERO, _hit_normal: Vector3 = Vector3.UP, hit_dir: Vector3 = Vector3.ZERO) -> void:
	if is_dead:
		return

	health = maxf(0.0, health - damage)
	_hit_flash_timer = HIT_FLASH_DURATION

	# Pequeno recuo visual (flinch) na malha ao levar tiro
	if hit_dir.length_squared() > 0.001:
		var local_hit_dir := global_transform.basis.inverse() * hit_dir.normalized()
		_flinch_offset = Vector3(local_hit_dir.x, 0.0, local_hit_dir.z) * 0.12

	if health <= 0.0:
		_die(hit_point, hit_dir)
		return

	var player: Player = Player.get_instance()
	if is_instance_valid(player):
		target = player.global_position
		if has_line_of_sight_to_player(player):
			set_detect()
			# Gira em direção ao player ao receber tiro
			var to_p := player.global_position - global_position
			to_p.y = 0.0
			if to_p.length_squared() > 0.001:
				rotation.y = atan2(-to_p.x, -to_p.z)
		else:
			set_alert(player.global_position)
			_investigating_last_seen = true
	else:
		set_detect()


func _die(_hit_point: Vector3, hit_dir: Vector3) -> void:
	if is_dead:
		return
	is_dead = true

	var parent_node := get_parent()
	if parent_node != null:
		var ragdoll := RigidBody3D.new()
		ragdoll.name = "EnemyRagdoll"
		ragdoll.collision_layer = 0
		ragdoll.collision_mask = 1
		ragdoll.mass = 35.0
		ragdoll.linear_damp = 0.6
		ragdoll.angular_damp = 1.0
		parent_node.add_child(ragdoll)
		ragdoll.global_transform = global_transform
		ragdoll.linear_velocity = velocity

		var col := CollisionShape3D.new()
		var cap_shape := CapsuleShape3D.new()
		col.shape = cap_shape
		ragdoll.add_child(col)

		var mesh_inst := MeshInstance3D.new()
		var cap_mesh := CapsuleMesh.new()
		mesh_inst.mesh = cap_mesh
		var rag_mat := StandardMaterial3D.new()
		rag_mat.albedo_color = Color(0.75, 0.15, 0.15, 1.0)
		rag_mat.roughness = 0.7
		rag_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh_inst.material_override = rag_mat
		ragdoll.add_child(mesh_inst)

		# Copia também o visor frontal no ragdoll se existir
		var visor := shape_mesh.get_node_or_null("Visor") as MeshInstance3D if shape_mesh != null else null
		if visor != null:
			var visor_copy := visor.duplicate() as MeshInstance3D
			mesh_inst.add_child(visor_copy)

		var push_dir := hit_dir
		if push_dir.length_squared() < 0.001:
			var player := Player.get_instance()
			if is_instance_valid(player):
				push_dir = (global_position - player.global_position).normalized()
			else:
				push_dir = global_transform.basis.z
		push_dir.y = 0.25
		push_dir = push_dir.normalized()

		# Impulso na parte superior da cápsula para tombar como ragdoll no chão
		ragdoll.apply_impulse(push_dir * 135.0, Vector3(0.0, 0.45, 0.0))
		var right_axis := push_dir.cross(Vector3.UP).normalized()
		if right_axis.length_squared() < 0.01:
			right_axis = Vector3.RIGHT
		ragdoll.angular_velocity = -right_axis * 5.5 + Vector3(
			randf_range(-1.5, 1.5),
			randf_range(-2.0, 2.0),
			randf_range(-1.5, 1.5)
		)

		var tween := ragdoll.create_tween()
		tween.tween_interval(2.5)
		tween.tween_property(rag_mat, "albedo_color:a", 0.0, 0.8)
		tween.tween_callback(ragdoll.queue_free)

	queue_free()
