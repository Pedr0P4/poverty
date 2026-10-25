class_name Enemy
extends CharacterBody3D

signal died(enemy_id: String)

const HIT_FLASH_DURATION: float = 0.18
const ATTACK_LUNGE_DURATION: float = 0.22

const AMMO_SMALL_RES: ItemData = preload("res://resources/items/ammo_small_item.tres")
const AMMO_MEDIUM_RES: ItemData = preload("res://resources/items/ammo_medium_item.tres")
const AMMO_LARGE_RES: ItemData = preload("res://resources/items/ammo_large_item.tres")

static var is_night_time: bool = false

var alert: bool = false
var detected: bool = false
var checking: bool = false
var is_wandering: bool = false
var target: Vector3
var move_speed: float = 3.0

var enemy_id: String = ""
var home_position: Vector3 = Vector3.ZERO
var gerador_terreno: Node3D = null
var is_culled: bool = false

@export_category("Atributos de Vida e Combate")
@export var max_health: float = 100.0
@export var attack_range: float = 1.8
@export var attack_damage: float = 15.0
@export var attack_cooldown: float = 1.0
@export_range(0.0, 1.0, 0.05) var ammo_drop_chance: float = 0.65

@export_category("Movimentação e Campo de Visão")
@export var wander_speed: float = 3.0
@export var chase_speed: float = 4.5
@export var patrol_radius: float = 22.0
@export var vision_range: float = 18.0
@export var vision_angle_deg: float = 115.0
@export var alert_innacuracy: float = 5.0
@export var deaggro_radius: float = 32.0

@export_category("Detecção Sonora (Stealth)")
@export var gunshot_hearing_range: float = 80.0
@export var run_step_hearing_range: float = 25.0
@export var walk_step_hearing_range: float = 10.0

var health: float = 100.0
var is_dead: bool = false

var _attack_cooldown_timer: float = 0.0
var _attack_lunge_timer: float = 0.0
var _attack_lunge_dir: Vector3 = Vector3.ZERO
var _hit_flash_timer: float = 0.0
var _flinch_offset: Vector3 = Vector3.ZERO
var _investigating_last_seen: bool = false
var _investigating_sound: bool = false
var _sound_is_gunshot: bool = false
var _spotted_grace_timer: float = 0.0

var _current_move_target: Vector3 = Vector3.ZERO
var _has_move_target: bool = false
var _is_scanning_area: bool = false
var _scan_timer: float = 0.0
var _scan_base_yaw: float = 0.0
var _idle_look_target_yaw: float = 0.0
var _idle_look_change_timer: float = 0.0
var _stuck_timer: float = 0.0
var _last_progress_pos: Vector3 = Vector3.ZERO
var _avoidance_angle_offset: float = 0.0
var _avoidance_timer: float = 0.0

var _base_color: Color = Color(0.0, 1.0, 0.0, 1.0)
var _base_shape_pos: Vector3 = Vector3.ZERO
var _enemy_material: StandardMaterial3D = null
var _visor_material: StandardMaterial3D = null

@onready var shape_mesh: MeshInstance3D = $Shape
@onready var collision_shape: CollisionShape3D = $Collision
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var wander_timer: Timer = $wander_timer
@onready var wait_timer: Timer = $wait_timer


static func notify_gunshot(tree: SceneTree, sound_pos: Vector3) -> void:
	if tree == null:
		return
	var night_mult := 1.20 if is_night_time else 1.0
	for node in tree.get_nodes_in_group("enemies"):
		if node is Enemy and is_instance_valid(node):
			var enemy := node as Enemy
			if not enemy.is_dead:
				var dist := enemy.global_position.distance_to(sound_pos)
				if dist <= enemy.gunshot_hearing_range * night_mult:
					enemy.hear_sound(sound_pos, true)


static func notify_player_footstep(tree: SceneTree, sound_pos: Vector3, is_running_step: bool) -> void:
	if tree == null:
		return
	var night_mult := 1.20 if is_night_time else 1.0
	for node in tree.get_nodes_in_group("enemies"):
		if node is Enemy and is_instance_valid(node):
			var enemy := node as Enemy
			if not enemy.is_dead:
				var base_dist := enemy.run_step_hearing_range if is_running_step else enemy.walk_step_hearing_range
				var dist := enemy.global_position.distance_to(sound_pos)
				if dist <= base_dist * night_mult:
					enemy.hear_sound(sound_pos, false)


func _ready() -> void:
	add_to_group("enemies")
	health = max_health
	move_speed = wander_speed
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.35
	if home_position == Vector3.ZERO:
		home_position = global_position
	_last_progress_pos = global_position
	_idle_look_target_yaw = rotation.y
	if nav_agent != null:
		nav_agent.path_desired_distance = 0.9
		nav_agent.target_desired_distance = 1.25
		nav_agent.max_speed = chase_speed * 1.25
	if shape_mesh != null:
		_base_shape_pos = shape_mesh.position
		_enemy_material = StandardMaterial3D.new()
		_enemy_material.albedo_color = _base_color
		_enemy_material.roughness = 0.65
		shape_mesh.material_override = _enemy_material
		var visor := shape_mesh.get_node_or_null("Visor") as MeshInstance3D
		if visor != null:
			_visor_material = StandardMaterial3D.new()
			_visor_material.albedo_color = Color(0.12, 0.14, 0.18, 1.0)
			_visor_material.roughness = 0.25
			visor.material_override = _visor_material


func set_culled_state(culled: bool) -> void:
	if is_dead or is_culled == culled:
		return
	is_culled = culled
	if culled:
		visible = false
		velocity = Vector3.ZERO
		if collision_shape != null:
			collision_shape.disabled = true
		set_physics_process(false)
		set_process(false)
	else:
		visible = true
		if collision_shape != null:
			collision_shape.disabled = false
		_last_progress_pos = global_position
		_stuck_timer = 0.0
		set_physics_process(true)
		set_process(true)


func _process(delta: float) -> void:
	if is_dead or is_culled:
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

	if _visor_material != null:
		if is_night_time:
			_visor_material.emission_enabled = true
			_visor_material.emission = Color(1.0, 0.18, 0.12, 1.0)
			_visor_material.emission_energy_multiplier = 2.2
		elif _visor_material.emission_enabled:
			_visor_material.emission_enabled = false

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
	if is_dead or is_culled:
		return

	if gerador_terreno != null and gerador_terreno.has_method("is_posicao_em_chunk_ativo"):
		if not gerador_terreno.is_posicao_em_chunk_ativo(global_position):
			velocity = Vector3.ZERO
			return

	_attack_cooldown_timer = maxf(0.0, _attack_cooldown_timer - delta)
	_spotted_grace_timer = maxf(0.0, _spotted_grace_timer - delta)
	_avoidance_timer = maxf(0.0, _avoidance_timer - delta)

	handle_grav(delta)

	var night_mult := 1.22 if is_night_time else 1.0
	var player: Player = Player.get_instance()
	if not alert:
		move_speed = wander_speed * night_mult
		if can_see_player(player):
			target = player.global_position
			set_detect()
			detected_phys(delta)
		else:
			wander_phys(delta)
	else:
		if detected:
			move_speed = chase_speed * night_mult
			detected_phys(delta)
		else:
			var ratio := 0.78 if (_investigating_last_seen or _sound_is_gunshot) else 0.52
			move_speed = lerpf(wander_speed, chase_speed, ratio) * night_mult
			if can_see_player(player):
				target = player.global_position
				set_detect()
				detected_phys(delta)
			else:
				alert_phys(delta)

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
	var effective_vision := vision_range * (1.20 if is_night_time else 1.0)
	if dist > effective_vision:
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
	var player_head_pos := player.get_head_global_position() if player.has_method("get_head_global_position") else (player.global_position + Vector3(0.0, 0.4, 0.0))
	var player_torso_pos := player.get_torso_global_position() if player.has_method("get_torso_global_position") else player.global_position

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


func wander_phys(delta: float = 0.016) -> void:
	if not wait_timer.is_stopped():
		velocity.x = move_toward(velocity.x, 0.0, 16.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 16.0 * delta)
		_idle_look_change_timer -= delta
		if _idle_look_change_timer <= 0.0:
			_idle_look_change_timer = randf_range(1.1, 2.2)
			_idle_look_target_yaw = rotation.y + deg_to_rad(randf_range(-65.0, 65.0))
		rotation.y = lerp_angle(rotation.y, _idle_look_target_yaw, 2.8 * delta)
		return

	var reached_target := _has_reached_move_target()
	if reached_target or wander_timer.is_stopped():
		if is_wandering:
			is_wandering = false
			_has_move_target = false
			wander_timer.stop()
			wait_timer.start(randf_range(1.6, 3.2))
			_idle_look_change_timer = 0.35
			_idle_look_target_yaw = rotation.y + deg_to_rad(randf_range(-50.0, 50.0))
			return
		else:
			if wander_nav():
				is_wandering = true
				_last_progress_pos = global_position
				_stuck_timer = 0.0
	nav(delta)


func wander_nav() -> bool:
	var forward := -global_transform.basis.z
	var forward_flat := Vector3(forward.x, 0.0, forward.z)
	if forward_flat.length_squared() < 0.001:
		forward_flat = Vector3.FORWARD
	else:
		forward_flat = forward_flat.normalized()

	var base_yaw := atan2(-forward_flat.x, -forward_flat.z)
	var to_home := home_position - global_position
	to_home.y = 0.0
	var dist_home := to_home.length()

	var best_pos := Vector3.ZERO
	var found_valid := false
	var best_score := -INF

	for i in range(8):
		var angle_offset := deg_to_rad(randf_range(-115.0, 115.0))
		if i >= 5:
			angle_offset = deg_to_rad(randf_range(-180.0, 180.0))

		var candidate_yaw := base_yaw + angle_offset
		if dist_home > patrol_radius and to_home.length_squared() > 0.1:
			var home_yaw := atan2(-to_home.x, -to_home.z)
			candidate_yaw = lerp_angle(candidate_yaw, home_yaw, 0.68)

		var dir := Vector3(-sin(candidate_yaw), 0.0, -cos(candidate_yaw)).normalized()
		var step_dist := randf_range(6.0, 13.5)
		var cand_pos := global_position + dir * step_dist

		var eval := _evaluate_candidate_point(cand_pos, dir)
		if not eval["valid"]:
			continue

		var score: float = eval["score"]
		if dist_home > patrol_radius * 0.85:
			var new_dist_home := Vector2(cand_pos.x - home_position.x, cand_pos.z - home_position.z).length()
			if new_dist_home < dist_home:
				score += 4.0

		if score > best_score:
			best_score = score
			best_pos = eval["pos"]
			found_valid = true

	if not found_valid:
		return false

	_set_navigation_destination(best_pos)
	wander_timer.start(randf_range(4.0, 6.8))
	return true


func _evaluate_candidate_point(cand_pos: Vector3, dir: Vector3) -> Dictionary:
	var final_pos := cand_pos
	var score: float = 0.0

	if gerador_terreno != null:
		if gerador_terreno.has_method("is_posicao_em_chunk_ativo"):
			if not gerador_terreno.is_posicao_em_chunk_ativo(cand_pos):
				return {"valid": false, "pos": final_pos, "score": -INF}
		if gerador_terreno.has_method("obter_altura"):
			var h_cand: float = gerador_terreno.obter_altura(cand_pos.x, cand_pos.z)
			var h_atual: float = gerador_terreno.obter_altura(global_position.x, global_position.z)
			if h_cand <= 0.12:
				return {"valid": false, "pos": final_pos, "score": -INF}
			var limite_rocha: float = gerador_terreno.get("altura_inicio_rocha") if gerador_terreno.get("altura_inicio_rocha") != null else 3.5
			if h_cand >= limite_rocha - 0.25:
				return {"valid": false, "pos": final_pos, "score": -INF}
			var diff_h := absf(h_cand - h_atual)
			if diff_h > 2.2:
				return {"valid": false, "pos": final_pos, "score": -INF}
			final_pos.y = h_cand
			score -= diff_h * 1.5

	# Evita escolher pontos com parede/obstáculo imediato à frente
	var space_state := get_world_3d().direct_space_state
	var ray_from := global_position + Vector3(0.0, 0.5, 0.0)
	var ray_to := ray_from + dir * 4.2
	var query := PhysicsRayQueryParameters3D.create(ray_from, ray_to)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var hit_res := space_state.intersect_ray(query)
	if not hit_res.is_empty():
		var hit_dist := ray_from.distance_to(hit_res.position)
		if hit_dist < 2.6:
			return {"valid": false, "pos": final_pos, "score": -INF}
		score -= 3.0

	if nav_agent != null:
		var map: RID = nav_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var nav_pos := NavigationServer3D.map_get_closest_point(map, final_pos)
			var flat_diff := Vector2(nav_pos.x - final_pos.x, nav_pos.z - final_pos.z).length()
			if flat_diff < 5.0:
				final_pos = nav_pos

	var flat_dist_self := Vector2(final_pos.x - global_position.x, final_pos.z - global_position.z).length()
	if flat_dist_self < 2.2:
		return {"valid": false, "pos": final_pos, "score": -INF}

	score += flat_dist_self * 0.25
	return {"valid": true, "pos": final_pos, "score": score}


func _set_navigation_destination(dest: Vector3) -> void:
	_current_move_target = dest
	_has_move_target = true
	if nav_agent != null:
		var map: RID = nav_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) > 0:
			var nav_pos := NavigationServer3D.map_get_closest_point(map, dest)
			if Vector2(nav_pos.x - dest.x, nav_pos.z - dest.z).length() < 8.0:
				nav_agent.target_position = nav_pos
				_current_move_target = nav_pos
				return
		nav_agent.target_position = dest


func _has_reached_move_target() -> bool:
	if not _has_move_target:
		return true
	var flat_dist := Vector2(global_position.x - _current_move_target.x, global_position.z - _current_move_target.z).length()
	if flat_dist <= 1.35:
		return true
	if nav_agent != null and nav_agent.is_navigation_finished() and flat_dist <= 2.5:
		return true
	return false


func nav(delta: float = 0.016) -> void:
	if _has_reached_move_target():
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		return

	var next := _current_move_target
	if nav_agent != null:
		var map: RID = nav_agent.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(map) > 0 and not nav_agent.is_navigation_finished():
			var path_next := nav_agent.get_next_path_position()
			var path_flat_dist := Vector2(path_next.x - global_position.x, path_next.z - global_position.z).length()
			if path_flat_dist > 0.05 and path_flat_dist < 45.0:
				next = path_next

	var dir := next - global_position
	dir.y = 0.0
	if dir.length_squared() <= 0.001:
		velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
		velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
		return

	dir = dir.normalized()

	# Verifica progresso para desviar de quinas/paredes caso fique preso
	var moved_dist := Vector2(global_position.x - _last_progress_pos.x, global_position.z - _last_progress_pos.z).length()
	if moved_dist > 0.22:
		_last_progress_pos = global_position
		_stuck_timer = 0.0
	else:
		_stuck_timer += delta
		if _stuck_timer > 0.55 or is_on_wall():
			_stuck_timer = 0.0
			_last_progress_pos = global_position
			if _avoidance_timer <= 0.0:
				_avoidance_angle_offset = deg_to_rad(68.0 if randf() > 0.5 else -68.0)
				_avoidance_timer = 0.55
			else:
				# Se continuar preso mesmo tentando desviar, recalcula rota
				_has_move_target = false
				return

	if _avoidance_timer > 0.0:
		dir = dir.rotated(Vector3.UP, _avoidance_angle_offset).normalized()

	# Evita caminhar para fora de chunks carregados enquanto apenas vaga
	if not detected and not alert and gerador_terreno != null and gerador_terreno.has_method("is_posicao_em_chunk_ativo"):
		var probe_pos := global_position + dir * 2.0
		if not gerador_terreno.is_posicao_em_chunk_ativo(probe_pos):
			_has_move_target = false
			velocity.x = 0.0
			velocity.z = 0.0
			return

	var target_vx := dir.x * move_speed
	var target_vz := dir.z * move_speed
	velocity.x = move_toward(velocity.x, target_vx, 18.0 * delta)
	velocity.z = move_toward(velocity.z, target_vz, 18.0 * delta)

	var target_angle := atan2(-dir.x, -dir.z)
	rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * delta)


func alert_phys(delta: float = 0.016) -> void:
	if not checking:
		if alert_nav():
			checking = true
			_is_scanning_area = false
			_last_progress_pos = global_position
			_stuck_timer = 0.0
			wander_timer.start(8.0)
	else:
		if _is_scanning_area:
			velocity.x = move_toward(velocity.x, 0.0, 18.0 * delta)
			velocity.z = move_toward(velocity.z, 0.0, 18.0 * delta)
			_scan_timer -= delta
			var look_wave := sin((2.6 - _scan_timer) * 2.8) * deg_to_rad(65.0)
			rotation.y = lerp_angle(rotation.y, _scan_base_yaw + look_wave, 5.5 * delta)
			if _scan_timer <= 0.0:
				_is_scanning_area = false
				checking = false
				alert = false
				_investigating_last_seen = false
				_investigating_sound = false
				_sound_is_gunshot = false
				_has_move_target = false
				wander_timer.stop()
				wait_timer.start(1.2)
			return

		if _has_reached_move_target() or wander_timer.is_stopped():
			_is_scanning_area = true
			_scan_timer = 2.6
			_scan_base_yaw = rotation.y
			wander_timer.stop()
			return
	nav(delta)


func alert_nav() -> bool:
	var search_target := target
	if not _investigating_last_seen:
		var spread := alert_innacuracy
		if _investigating_sound:
			spread = 1.6 if _sound_is_gunshot else 1.0
		var innacuracy := Vector3(randf_range(-spread, spread), 0.0, randf_range(-spread, spread))
		search_target += innacuracy

	if gerador_terreno != null and gerador_terreno.has_method("obter_altura"):
		search_target.y = gerador_terreno.obter_altura(search_target.x, search_target.z)

	_set_navigation_destination(search_target)
	return true


func detected_phys(delta: float = 0.016) -> void:
	var player: Player = Player.get_instance()
	if not is_instance_valid(player) or player.is_dead:
		detected = false
		alert = false
		_investigating_last_seen = false
		_investigating_sound = false
		_has_move_target = false
		velocity.x = 0.0
		velocity.z = 0.0
		return

	var distance: float = global_position.distance_to(player.global_position)
	if distance >= deaggro_radius:
		# Saiu do raio máximo de perseguição: vai investigar a última posição vista
		detected = false
		alert = true
		checking = false
		_is_scanning_area = false
		_investigating_last_seen = true
		return

	var sees_player := can_see_player(player) or (_spotted_grace_timer > 0.0 and has_line_of_sight_to_player(player))
	if not sees_player:
		# Player entrou atrás de uma parede ou saiu do campo de visão: vai até a última posição onde o viu
		detected = false
		alert = true
		checking = false
		_is_scanning_area = false
		_investigating_last_seen = true
		return

	# Está vendo o player: atualiza a última posição conhecida
	target = player.global_position
	_set_navigation_destination(player.global_position)

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
		nav(delta)


func _perform_attack(player: Player) -> void:
	_attack_cooldown_timer = attack_cooldown
	_attack_lunge_timer = ATTACK_LUNGE_DURATION
	var local_forward := Vector3(0.0, 0.0, -1.0)
	_attack_lunge_dir = local_forward
	if player != null and is_instance_valid(player):
		player.take_damage(attack_damage)


func hear_sound(sound_pos: Vector3, is_gunshot: bool) -> void:
	if is_dead:
		return
	if detected:
		target = sound_pos
		return

	# Se já está investigando um tiro recente, um som de passo distante não sobrescreve a prioridade
	if alert and _investigating_sound and _sound_is_gunshot and not is_gunshot:
		if global_position.distance_to(sound_pos) > walk_step_hearing_range:
			return

	alert = true
	is_wandering = false
	checking = false
	_is_scanning_area = false
	_investigating_sound = true
	_sound_is_gunshot = is_gunshot
	_investigating_last_seen = false
	target = sound_pos
	wander_timer.stop()
	wait_timer.stop()


func set_alert(pos: Vector3) -> void:
	alert = true
	is_wandering = false
	_is_scanning_area = false
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
	_is_scanning_area = false
	_investigating_last_seen = true
	_investigating_sound = false
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
	died.emit(enemy_id)
	_try_spawn_ammo_drop()

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


func _try_spawn_ammo_drop() -> void:
	if randf() > ammo_drop_chance:
		return
	var parent_node := get_parent()
	if parent_node == null:
		return

	var roll := randf()
	var chosen_ammo: ItemData
	var amount: int
	if roll < 0.55:
		chosen_ammo = AMMO_SMALL_RES
		amount = randi_range(8, 16)
	elif roll < 0.82:
		chosen_ammo = AMMO_MEDIUM_RES
		amount = randi_range(8, 18)
	else:
		chosen_ammo = AMMO_LARGE_RES
		amount = randi_range(4, 10)

	var drop := AmmoDrop.new()
	drop.name = "AmmoDrop_%d" % Time.get_ticks_msec()
	parent_node.add_child(drop)
	var floor_y := global_position.y - 0.95
	if gerador_terreno != null and gerador_terreno.has_method("obter_altura_terreno"):
		floor_y = gerador_terreno.obter_altura_terreno(global_position.x, global_position.z)
	drop.global_position = Vector3(global_position.x, floor_y, global_position.z)
	drop.setup(chosen_ammo, amount)
