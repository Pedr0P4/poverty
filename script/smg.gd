class_name SmgWeapon
extends Weapon

var _canted_blend: float = 0.0
var _is_canted: bool = false


func _setup_weapon_stats() -> void:
	weapon_id = "smg"
	weapon_title = "Submetralhadora SMG"
	ammo_category = ItemData.AmmoCategory.SMALL
	automatic = true
	fire_rate = 0.058
	reload_time = 1.15
	projectiles_per_shot = 1

	base_spread_deg = 0.65
	max_spread_deg = 8.2
	spread_increase_per_shot = 0.92
	spread_recovery_rate = 10.5
	# Peculiaridade Run & Gun: quase sem perda de precisão ao se mover
	move_spread_penalty_deg = 0.25

	camera_recoil_pitch_deg = 0.36
	camera_recoil_yaw_deg = 0.48
	visual_kick_pos = Vector3(0.016, 0.015, 0.048)
	visual_kick_rot_deg = Vector3(4.2, 2.8, 3.2)
	recoil_recovery_speed = 18.0

	sway_pos_sensitivity = 0.0016
	sway_max_pos = 0.055
	sway_rot_sensitivity_deg = 0.15
	sway_roll_sensitivity_deg = 0.14
	sway_max_rot_deg = 7.0
	sway_return_speed = 12.0
	sway_smooth_speed = 13.5

	trail_color = Color(0.35, 1.0, 0.78, 0.9)
	trail_thickness = 0.02
	trail_duration = 0.09


func _handle_secondary_action(
	_just_pressed: bool,
	is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	_is_canted = is_pressed and not is_reloading


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	_is_canted = false


func _on_weapon_unequipped(_camera: Camera3D, _player: Player) -> void:
	_is_canted = false
	_canted_blend = 0.0


func _weapon_process(delta: float, _camera: Camera3D, _player: Player) -> void:
	if is_reloading:
		_is_canted = false
	var target := 1.0 if _is_canted else 0.0
	_canted_blend = lerpf(_canted_blend, target, minf(1.0, delta * 14.0))


func _get_subclass_transform_offset() -> Array[Vector3]:
	# Empunhadura inclinada tática (Canted Sight) ao segurar botão direito
	var pos_off := Vector3(0.11, 0.05, 0.03) * _canted_blend
	var rot_off := Vector3(0.0, 0.0, deg_to_rad(-32.0)) * _canted_blend
	return [pos_off, rot_off]


func get_max_spread_deg() -> float:
	return lerpf(max_spread_deg, 4.4, _canted_blend)


func get_spread_increase_per_shot() -> float:
	return spread_increase_per_shot * lerpf(1.0, 0.6, _canted_blend)


func get_recoil_multiplier() -> float:
	return lerpf(1.0, 0.65, _canted_blend)


func get_peculiarity_hint() -> String:
	if _canted_blend > 0.5:
		return "Empunhadura Inclinada (Spray Reduzido)"
	return "1000 RPM | [Botão Dir]: Trava de Pulso"
