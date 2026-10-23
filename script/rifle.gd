class_name RifleWeapon
extends Weapon

var _ads_blend: float = 0.0
var _is_aiming: bool = false
var _default_fov: float = 75.0


func _setup_weapon_stats() -> void:
	weapon_id = "rifle"
	weapon_title = "Rifle de Assalto"
	ammo_category = ItemData.AmmoCategory.MEDIUM
	automatic = true
	fire_rate = 0.105
	reload_time = 1.65
	projectiles_per_shot = 1
	damage_multiplier = 1.0

	base_spread_deg = 0.35
	max_spread_deg = 5.4
	spread_increase_per_shot = 0.72
	spread_recovery_rate = 7.5
	move_spread_penalty_deg = 1.6

	camera_recoil_pitch_deg = 0.58
	camera_recoil_yaw_deg = 0.32
	visual_kick_pos = Vector3(0.012, 0.018, 0.068)
	visual_kick_rot_deg = Vector3(5.8, 1.8, 1.6)
	recoil_recovery_speed = 14.0

	sway_pos_sensitivity = 0.0018
	sway_max_pos = 0.06
	sway_rot_sensitivity_deg = 0.15
	sway_roll_sensitivity_deg = 0.12
	sway_max_rot_deg = 7.5
	sway_smooth_speed = 10.5

	trail_color = Color(1.0, 0.86, 0.32, 0.92)
	trail_thickness = 0.025
	trail_duration = 0.12


func _handle_secondary_action(
	_just_pressed: bool,
	is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	_is_aiming = is_pressed and not is_reloading


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	_is_aiming = false


func _on_weapon_unequipped(camera: Camera3D, _player: Player) -> void:
	_is_aiming = false
	_ads_blend = 0.0
	if camera != null:
		camera.fov = _default_fov


func _weapon_process(delta: float, camera: Camera3D, _player: Player) -> void:
	if is_reloading:
		_is_aiming = false
	var target_ads := 1.0 if _is_aiming else 0.0
	_ads_blend = lerpf(_ads_blend, target_ads, minf(1.0, delta * 12.0))
	if camera != null and visible:
		var target_fov := lerpf(_default_fov, 58.0, _ads_blend)
		camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 12.0))


func _get_subclass_transform_offset() -> Array[Vector3]:
	var ads_pos := Vector3(0.16, 0.085, 0.06) * _ads_blend
	var ads_rot := Vector3.ZERO
	return [ads_pos, ads_rot]


func get_spread_increase_per_shot() -> float:
	# Peculiaridade do Rifle: os primeiros 3 disparos da rajada são bem controlados
	var base_inc := spread_increase_per_shot
	if _consecutive_shots <= 3:
		base_inc *= 0.45
	return base_inc * lerpf(1.0, 0.58, _ads_blend)


func get_effective_spread_deg(player: Player) -> float:
	var spread := super.get_effective_spread_deg(player)
	return spread * lerpf(1.0, 0.55, _ads_blend)


func get_recoil_multiplier() -> float:
	return lerpf(1.0, 0.65, _ads_blend)


func _get_sway_multiplier() -> float:
	return lerpf(1.0, 0.45, _ads_blend)


func get_peculiarity_hint() -> String:
	if _ads_blend > 0.5:
		return "Modo: Visada Firme (ADS)"
	return "Auto | [Botão Dir]: Visada Firme"
