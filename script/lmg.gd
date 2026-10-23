class_name LmgWeapon
extends Weapon

const MIN_FIRE_INTERVAL: float = 0.066
const MAX_FIRE_INTERVAL: float = 0.19

var _spin_level: float = 0.0
var _is_braced: bool = false
var _brace_blend: float = 0.0
var _is_trigger_held: bool = false


func _setup_weapon_stats() -> void:
	weapon_id = "lmg"
	weapon_title = "Metralhadora Pesada"
	ammo_category = ItemData.AmmoCategory.LARGE
	automatic = true
	fire_rate = MAX_FIRE_INTERVAL
	reload_time = 3.1
	projectiles_per_shot = 1

	base_spread_deg = 0.85
	max_spread_deg = 7.2
	spread_increase_per_shot = 0.42
	spread_recovery_rate = 5.0
	move_spread_penalty_deg = 2.6

	camera_recoil_pitch_deg = 0.68
	camera_recoil_yaw_deg = 0.42
	visual_kick_pos = Vector3(0.015, 0.022, 0.06)
	visual_kick_rot_deg = Vector3(5.2, 2.2, 2.0)
	recoil_recovery_speed = 11.0

	# Arma pesada: inércia maior e lerp mais lento ao virar a câmera
	sway_pos_sensitivity = 0.0024
	sway_max_pos = 0.085
	sway_rot_sensitivity_deg = 0.22
	sway_roll_sensitivity_deg = 0.16
	sway_max_rot_deg = 10.0
	sway_return_speed = 6.5
	sway_smooth_speed = 6.2

	trail_color = Color(1.0, 0.42, 0.32, 0.94)
	trail_thickness = 0.032
	trail_duration = 0.15


func _handle_secondary_action(
	_just_pressed: bool,
	is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	_is_braced = is_pressed and not is_reloading


func _should_trigger_primary_shot(fire_just_pressed: bool, fire_pressed: bool) -> bool:
	_is_trigger_held = fire_pressed and not is_reloading
	return super._should_trigger_primary_shot(fire_just_pressed, fire_pressed)


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	_is_braced = false
	_is_trigger_held = false


func _on_weapon_unequipped(_camera: Camera3D, _player: Player) -> void:
	_is_braced = false
	_brace_blend = 0.0
	_spin_level = 0.0
	_is_trigger_held = false


func _on_shot_fired(_camera: Camera3D, _player: Player) -> void:
	# Acelera a cadência a cada tiro contínuo (Ramp-Up)
	_spin_level = clampf(_spin_level + 0.085, 0.0, 1.0)


func _weapon_process(delta: float, _camera: Camera3D, _player: Player) -> void:
	if is_reloading:
		_is_braced = false
		_is_trigger_held = false
		_spin_level = move_toward(_spin_level, 0.0, delta * 1.5)
	elif not _is_trigger_held and _time_since_last_shot > 0.22:
		_spin_level = move_toward(_spin_level, 0.0, delta * 0.75)

	var target_brace := 1.0 if _is_braced else 0.0
	_brace_blend = lerpf(_brace_blend, target_brace, minf(1.0, delta * 8.0))


func _get_subclass_transform_offset() -> Array[Vector3]:
	var brace_pos := Vector3(0.10, 0.04, 0.05) * _brace_blend
	var brace_rot := Vector3.ZERO
	return [brace_pos, brace_rot]


func get_current_fire_interval() -> float:
	return lerpf(MAX_FIRE_INTERVAL, MIN_FIRE_INTERVAL, _spin_level)


func get_recoil_multiplier() -> float:
	# Quanto mais acelerada e apoiada (botão direito), mais estável fica a supressão
	var spin_Bonus := lerpf(1.0, 0.75, _spin_level)
	var brace_bonus := lerpf(1.0, 0.52, _brace_blend)
	return spin_Bonus * brace_bonus


func get_effective_spread_deg(player: Player) -> float:
	var spread := super.get_effective_spread_deg(player)
	return spread * lerpf(1.0, 0.58, _brace_blend)


func get_peculiarity_hint() -> String:
	var pct := int(round(_spin_level * 100.0))
	if _brace_blend > 0.5:
		return "Apoio Pesado | Cadência: %d%%" % pct
	if pct > 0:
		return "Acelerando Cadência: %d%%" % pct
	return "Ramp-Up Auto | [Botão Dir]: Apoio Pesado"
