class_name Weapon
extends Node3D

signal reload_state_changed(reloading: bool, progress: float, remaining_sec: float)

@export_category("Identificação")
@export var weapon_id: String = "rifle"
@export var weapon_title: String = "Rifle"
@export var ammo_category: ItemData.AmmoCategory = ItemData.AmmoCategory.MEDIUM
@export var begin: Marker3D

@export_category("Disparo e Recarga")
@export var automatic: bool = false
@export var fire_rate: float = 0.12
@export var reload_time: float = 1.5
@export var projectiles_per_shot: int = 1
@export var max_range: float = 2000.0

@export_category("Spray e Recuo")
@export var base_spread_deg: float = 0.35
@export var max_spread_deg: float = 5.5
@export var spread_increase_per_shot: float = 0.75
@export var spread_recovery_rate: float = 7.0
@export var move_spread_penalty_deg: float = 1.5
@export var camera_recoil_pitch_deg: float = 0.55
@export var camera_recoil_yaw_deg: float = 0.28
@export var visual_kick_pos: Vector3 = Vector3(0.012, 0.018, 0.065)
@export var visual_kick_rot_deg: Vector3 = Vector3(5.5, 1.6, 1.8)
@export var recoil_recovery_speed: float = 14.0

@export_category("Sway / Lerp da Câmera")
@export var sway_pos_sensitivity: float = 0.0018
@export var sway_max_pos: float = 0.065
@export var sway_rot_sensitivity_deg: float = 0.16
@export var sway_roll_sensitivity_deg: float = 0.12
@export var sway_max_rot_deg: float = 8.0
@export var sway_return_speed: float = 10.0
@export var sway_smooth_speed: float = 10.0

@export_category("Traçado da Bala")
@export var trail_duration: float = 0.12
@export var max_trail_length: float = 120.0
@export var trail_color: Color = Color(1.0, 0.88, 0.32, 0.92)
@export var trail_thickness: float = 0.025

var is_reloading: bool = false
var _reload_elapsed: float = 0.0
var _reloading_slot: InventorySlotData = null
var _inventory_ui: InventoryUI = null

var _base_position: Vector3
var _base_rotation: Vector3

var _fire_cooldown: float = 0.0
var _current_spread_deg: float = 0.0
var _consecutive_shots: int = 0
var _time_since_last_shot: float = 0.0

var _sway_target_pos: Vector3 = Vector3.ZERO
var _sway_target_rot: Vector3 = Vector3.ZERO
var _sway_current_pos: Vector3 = Vector3.ZERO
var _sway_current_rot: Vector3 = Vector3.ZERO
var _walk_bob_time: float = 0.0
var _walk_bob_pos: Vector3 = Vector3.ZERO

var _recoil_pos_offset: Vector3 = Vector3.ZERO
var _recoil_rot_offset: Vector3 = Vector3.ZERO


func _ready() -> void:
	_base_init()


func _base_init() -> void:
	_base_transform_store()
	_setup_weapon_stats()


func _base_transform_store() -> void:
	_base_position = position
	_base_rotation = rotation


## Sobrescrito pelas subclasses para configurar atributos e peculiaridades da arma
func _setup_weapon_stats() -> void:
	pass


func on_equip(_camera: Camera3D, _player: Player) -> void:
	_fire_cooldown = 0.12
	_current_spread_deg = 0.0
	_consecutive_shots = 0
	# Pequeno efeito de saque suave ao equipar a arma (sobe com lerp até a mão)
	_sway_current_pos = Vector3(0.0, -0.12, 0.06)
	_sway_current_rot = Vector3(deg_to_rad(-16.0), 0.0, 0.0)


func on_unequip(camera: Camera3D, player: Player) -> void:
	if is_reloading:
		cancel_reload()
	_recoil_pos_offset = Vector3.ZERO
	_recoil_rot_offset = Vector3.ZERO
	_sway_target_pos = Vector3.ZERO
	_sway_target_rot = Vector3.ZERO
	_on_weapon_unequipped(camera, player)


func _on_weapon_unequipped(_camera: Camera3D, _player: Player) -> void:
	pass


## Recebe o movimento do mouse para criar a inércia suave (lerp) em relação à câmera
func apply_mouse_sway(relative: Vector2) -> void:
	if not visible:
		return
	var sway_scale := _get_sway_multiplier()
	_sway_target_pos.x = clampf(
		_sway_target_pos.x + relative.x * sway_pos_sensitivity * sway_scale,
		-sway_max_pos,
		sway_max_pos
	)
	_sway_target_pos.y = clampf(
		_sway_target_pos.y - relative.y * sway_pos_sensitivity * sway_scale,
		-sway_max_pos,
		sway_max_pos
	)

	var max_rot_rad := deg_to_rad(sway_max_rot_deg)
	_sway_target_rot.y = clampf(
		_sway_target_rot.y + deg_to_rad(relative.x * sway_rot_sensitivity_deg * sway_scale),
		-max_rot_rad,
		max_rot_rad
	)
	_sway_target_rot.x = clampf(
		_sway_target_rot.x + deg_to_rad(relative.y * sway_rot_sensitivity_deg * sway_scale),
		-max_rot_rad,
		max_rot_rad
	)
	_sway_target_rot.z = clampf(
		_sway_target_rot.z + deg_to_rad(relative.x * sway_roll_sensitivity_deg * sway_scale),
		-max_rot_rad,
		max_rot_rad
	)


func _get_sway_multiplier() -> float:
	return 1.0


func _process(delta: float) -> void:
	_fire_cooldown = maxf(0.0, _fire_cooldown - delta)
	_time_since_last_shot += delta

	if not visible:
		if is_reloading:
			cancel_reload()
		return

	if _time_since_last_shot > get_current_fire_interval() * 1.35:
		_current_spread_deg = move_toward(_current_spread_deg, 0.0, get_spread_recovery_rate() * delta)
		if _current_spread_deg <= 0.01:
			_consecutive_shots = 0

	var player := Player.get_instance()
	var camera := get_viewport().get_camera_3d()

	_update_reload_state(delta)
	_update_sway_and_recoil(delta, player)
	_weapon_process(delta, camera, player)
	_apply_composed_transform()


func _update_reload_state(delta: float) -> void:
	if not is_reloading:
		return

	if (
		not visible
		or _inventory_ui == null
		or _inventory_ui.is_open
		or _inventory_ui.get_selected_weapon_slot() != _reloading_slot
		or not _inventory_ui.can_reload_active_weapon()
	):
		cancel_reload()
		return

	_reload_elapsed += delta
	var progress := clampf(_reload_elapsed / reload_time, 0.0, 1.0)
	var remaining := maxf(0.0, reload_time - _reload_elapsed)

	reload_state_changed.emit(true, progress, remaining)

	if _reload_elapsed >= reload_time:
		is_reloading = false
		_reload_elapsed = 0.0
		_reloading_slot = null
		_inventory_ui.reload_active_weapon()
		reload_state_changed.emit(false, 1.0, 0.0)


func _update_sway_and_recoil(delta: float, player: Player) -> void:
	# Lerp para a arma não seguir 100% rígida a câmera
	_sway_target_pos = _sway_target_pos.lerp(Vector3.ZERO, minf(1.0, delta * sway_return_speed))
	_sway_target_rot = _sway_target_rot.lerp(Vector3.ZERO, minf(1.0, delta * sway_return_speed))

	_sway_current_pos = _sway_current_pos.lerp(_sway_target_pos, minf(1.0, delta * sway_smooth_speed))
	_sway_current_rot = _sway_current_rot.lerp(_sway_target_rot, minf(1.0, delta * sway_smooth_speed))

	# Leve balanço orgânico ao caminhar/correr
	if player != null and player.is_on_floor():
		var horiz_speed := Vector2(player.velocity.x, player.velocity.z).length()
		if horiz_speed > 0.25:
			_walk_bob_time += delta * (4.5 + horiz_speed * 0.65)
			var bob_scale := clampf(horiz_speed / 8.0, 0.2, 1.3) * _get_sway_multiplier()
			var target_bob := Vector3(
				cos(_walk_bob_time) * 0.01 * bob_scale,
				absf(sin(_walk_bob_time)) * -0.012 * bob_scale,
				0.0
			)
			_walk_bob_pos = _walk_bob_pos.lerp(target_bob, minf(1.0, delta * 10.0))
		else:
			_walk_bob_pos = _walk_bob_pos.lerp(Vector3.ZERO, minf(1.0, delta * 8.0))
	else:
		_walk_bob_pos = _walk_bob_pos.lerp(Vector3.ZERO, minf(1.0, delta * 6.0))

	# Recuperação suave do coice visual na arma 3D
	_recoil_pos_offset = _recoil_pos_offset.lerp(Vector3.ZERO, minf(1.0, delta * recoil_recovery_speed))
	_recoil_rot_offset = _recoil_rot_offset.lerp(Vector3.ZERO, minf(1.0, delta * recoil_recovery_speed))


func _apply_composed_transform() -> void:
	var final_pos := _base_position + _sway_current_pos + _walk_bob_pos + _recoil_pos_offset
	var final_rot := _base_rotation + _sway_current_rot + _recoil_rot_offset

	if is_reloading:
		var progress := clampf(_reload_elapsed / maxf(0.01, reload_time), 0.0, 1.0)
		var anim_wave := sin(progress * PI)
		final_pos += Vector3(0.0, -0.14 * anim_wave, 0.05 * anim_wave)
		final_rot += Vector3(deg_to_rad(-28.0) * anim_wave, 0.0, deg_to_rad(18.0) * anim_wave)

	var extra := _get_subclass_transform_offset()
	final_pos += extra[0]
	final_rot += extra[1]

	position = final_pos
	rotation = final_rot


## Retorna [pos_offset, rot_offset] específicos da subclasse (ex: ADS, pump da shotgun, bolt da sniper)
func _get_subclass_transform_offset() -> Array[Vector3]:
	return [Vector3.ZERO, Vector3.ZERO]


## Atualização por frame específica da subclasse
func _weapon_process(_delta: float, _camera: Camera3D, _player: Player) -> void:
	pass


## Processa inputs de combate (botão esquerdo de tiro e botão direito de ação peculiar)
func process_combat_input(
	delta: float,
	camera: Camera3D,
	player: Player,
	fire_just_pressed: bool,
	fire_pressed: bool,
	alt_just_pressed: bool,
	alt_pressed: bool,
	alt_just_released: bool
) -> void:
	if not visible or player == null or player.is_inventory_open() or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		_on_combat_inactive(delta, camera, player)
		return

	_handle_secondary_action(alt_just_pressed, alt_pressed, alt_just_released, camera, player)

	if is_reloading:
		return

	if _should_trigger_primary_shot(fire_just_pressed, fire_pressed):
		try_fire_shot(camera, player)


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	pass


func _handle_secondary_action(
	_just_pressed: bool,
	_is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	pass


func _should_trigger_primary_shot(fire_just_pressed: bool, fire_pressed: bool) -> bool:
	if _fire_cooldown > 0.0:
		return false
	if automatic:
		return fire_pressed
	return fire_just_pressed


func try_fire_shot(camera: Camera3D, player: Player) -> bool:
	if camera == null or player == null or player.inventory_ui == null:
		return false
	if is_reloading or not visible:
		return false
	if not player.inventory_ui.consume_active_weapon_ammo(1):
		return false

	_fire_cooldown = get_current_fire_interval()
	_time_since_last_shot = 0.0
	_consecutive_shots += 1

	var effective_spread := get_effective_spread_deg(player)
	var num_projectiles := maxi(1, projectiles_per_shot)
	for i in range(num_projectiles):
		_fire_raycast_projectile(camera, player, effective_spread)

	_apply_shot_recoil(camera, player)
	_current_spread_deg = minf(
		_current_spread_deg + get_spread_increase_per_shot(),
		get_max_spread_deg()
	)
	_on_shot_fired(camera, player)
	return true


func get_current_fire_interval() -> float:
	return fire_rate


func get_spread_increase_per_shot() -> float:
	return spread_increase_per_shot


func get_max_spread_deg() -> float:
	return max_spread_deg


func get_spread_recovery_rate() -> float:
	return spread_recovery_rate


func get_effective_spread_deg(player: Player) -> float:
	var spread := base_spread_deg + _current_spread_deg
	if player != null:
		var horiz_speed := Vector2(player.velocity.x, player.velocity.z).length()
		if horiz_speed > 0.35:
			spread += move_spread_penalty_deg * clampf(horiz_speed / player.speed, 0.25, 1.8)
		if not player.is_on_floor():
			spread += move_spread_penalty_deg * 1.4
	return maxf(0.0, spread)


func get_recoil_multiplier() -> float:
	return 1.0


func _apply_shot_recoil(_camera: Camera3D, player: Player) -> void:
	var mult := get_recoil_multiplier()

	# Coice na câmera (subida vertical + desvio lateral de spray)
	var pitch_deg := randf_range(camera_recoil_pitch_deg * 0.8, camera_recoil_pitch_deg * 1.2) * mult
	var yaw_deg := randf_range(-camera_recoil_yaw_deg, camera_recoil_yaw_deg) * mult
	if player != null:
		player.apply_camera_recoil(deg_to_rad(pitch_deg), deg_to_rad(yaw_deg))

	# Coice visual na arma 3D
	var kick_x := randf_range(-visual_kick_pos.x, visual_kick_pos.x) * mult
	var kick_y := visual_kick_pos.y * randf_range(0.85, 1.15) * mult
	var kick_z := visual_kick_pos.z * randf_range(0.9, 1.15) * mult
	_recoil_pos_offset += Vector3(kick_x, kick_y, kick_z)
	_recoil_pos_offset = _recoil_pos_offset.clamp(
		Vector3(-0.08, -0.04, 0.0),
		Vector3(0.08, 0.10, 0.22)
	)

	var rot_x := deg_to_rad(visual_kick_rot_deg.x * randf_range(0.85, 1.2) * mult)
	var rot_y := deg_to_rad(randf_range(-visual_kick_rot_deg.y, visual_kick_rot_deg.y) * mult)
	var rot_z := deg_to_rad(randf_range(-visual_kick_rot_deg.z, visual_kick_rot_deg.z) * mult)
	_recoil_rot_offset += Vector3(rot_x, rot_y, rot_z)
	_recoil_rot_offset = _recoil_rot_offset.clamp(
		Vector3(deg_to_rad(-5.0), deg_to_rad(-12.0), deg_to_rad(-14.0)),
		Vector3(deg_to_rad(24.0), deg_to_rad(12.0), deg_to_rad(14.0))
	)


func _on_shot_fired(_camera: Camera3D, _player: Player) -> void:
	pass


func _fire_raycast_projectile(camera: Camera3D, player: Player, spread_deg: float) -> void:
	var space_state := get_world_3d().direct_space_state
	var center_screen := get_viewport().get_visible_rect().size * 0.5

	var origin := camera.project_ray_origin(center_screen)
	var forward := camera.project_ray_normal(center_screen).normalized()

	var ray_dir := forward
	if spread_deg > 0.001:
		var max_radius := tan(deg_to_rad(spread_deg))
		var r := sqrt(randf()) * max_radius
		var theta := randf() * TAU
		var right := camera.global_transform.basis.x.normalized()
		var up := camera.global_transform.basis.y.normalized()
		ray_dir = (forward + right * (cos(theta) * r) + up * (sin(theta) * r)).normalized()

	var end := origin + (ray_dir * max_range)
	var exclude_rids: Array[RID] = []
	if player != null:
		exclude_rids.append(player.get_rid())

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 | 4
	query.exclude = exclude_rids

	var result := space_state.intersect_ray(query)
	var weapon_target := end
	if result:
		weapon_target = result.position

	var weapon_begin := begin.global_position if begin != null else global_position
	var to_target_dir := (weapon_target - weapon_begin).normalized()
	var extended_target := weapon_target + to_target_dir * 0.25

	var weapon_query := PhysicsRayQueryParameters3D.create(weapon_begin, extended_target)
	weapon_query.collision_mask = 1 | 4
	weapon_query.exclude = exclude_rids

	var weapon_result := space_state.intersect_ray(weapon_query)
	var trail_end := weapon_target
	if weapon_result:
		var weapon_collider: Node3D = weapon_result.collider as Node3D
		var weapon_point: Vector3 = weapon_result.position
		var weapon_normal: Vector3 = weapon_result.normal
		trail_end = weapon_point

		if weapon_collider != null:
			DecalGlobal.apply_decal(weapon_point, weapon_normal, weapon_collider)
			if weapon_collider.has_method("hit"):
				weapon_collider.hit()

	spawn_bullet_trail(weapon_begin, trail_end)


func start_reload(inventory_ui: InventoryUI) -> void:
	if not visible or is_reloading or inventory_ui == null or inventory_ui.is_open:
		return
	if not inventory_ui.can_reload_active_weapon():
		return

	_inventory_ui = inventory_ui
	_reloading_slot = inventory_ui.get_selected_weapon_slot()
	is_reloading = true
	_reload_elapsed = 0.0
	_on_reload_started()
	reload_state_changed.emit(true, 0.0, reload_time)


func _on_reload_started() -> void:
	pass


func cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	_reload_elapsed = 0.0
	_reloading_slot = null
	reload_state_changed.emit(false, 0.0, 0.0)


func get_peculiarity_hint() -> String:
	return ""


func spawn_bullet_trail(from_pos: Vector3, to_pos: Vector3) -> void:
	var diff := to_pos - from_pos
	var dist := diff.length()
	if dist < 0.05:
		return

	var dir := diff / dist
	if dist > max_trail_length:
		dist = max_trail_length
		to_pos = from_pos + dir * dist

	var trail_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(trail_thickness, trail_thickness, dist)
	trail_instance.mesh = box_mesh
	trail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = trail_color
	trail_instance.material_override = mat

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(trail_instance)

	var up_dir := Vector3.UP
	if absf(dir.y) > 0.99:
		up_dir = Vector3.RIGHT

	trail_instance.global_position = (from_pos + to_pos) * 0.5
	trail_instance.look_at(to_pos, up_dir)

	var tween := trail_instance.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, trail_duration)
	tween.tween_callback(trail_instance.queue_free)
