class_name ShotgunWeapon
extends Weapon

var _choke_blend: float = 0.0
var _is_choke_tight: bool = false
var _pump_anim_time: float = 0.0
const PUMP_DURATION: float = 0.48


func _setup_weapon_stats() -> void:
	weapon_id = "shotgun"
	weapon_title = "Escopeta Pump"
	ammo_category = ItemData.AmmoCategory.MEDIUM
	automatic = false
	fire_rate = 0.78
	reload_time = 2.0
	# Peculiaridade: 8 balins disparados simultaneamente em cone!
	projectiles_per_shot = 8

	base_spread_deg = 5.4
	max_spread_deg = 9.0
	spread_increase_per_shot = 1.8
	spread_recovery_rate = 4.5
	move_spread_penalty_deg = 1.2

	camera_recoil_pitch_deg = 2.4
	camera_recoil_yaw_deg = 0.75
	visual_kick_pos = Vector3(0.022, 0.055, 0.14)
	visual_kick_rot_deg = Vector3(16.0, 3.2, 3.5)
	recoil_recovery_speed = 9.5

	sway_pos_sensitivity = 0.0020
	sway_max_pos = 0.07
	sway_rot_sensitivity_deg = 0.18
	sway_roll_sensitivity_deg = 0.14
	sway_max_rot_deg = 8.5
	sway_return_speed = 8.5
	sway_smooth_speed = 8.5

	trail_color = Color(1.0, 0.65, 0.25, 0.9)
	trail_thickness = 0.018
	trail_duration = 0.14


func _handle_secondary_action(
	_just_pressed: bool,
	is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	_is_choke_tight = is_pressed and not is_reloading


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	_is_choke_tight = false


func _on_weapon_unequipped(_camera: Camera3D, _player: Player) -> void:
	_is_choke_tight = false
	_choke_blend = 0.0
	_pump_anim_time = 0.0


func _on_shot_fired(_camera: Camera3D, _player: Player) -> void:
	_pump_anim_time = PUMP_DURATION


func _weapon_process(delta: float, _camera: Camera3D, _player: Player) -> void:
	if is_reloading:
		_is_choke_tight = false
		_pump_anim_time = 0.0

	if _pump_anim_time > 0.0:
		_pump_anim_time = maxf(0.0, _pump_anim_time - delta)

	var target_choke := 1.0 if _is_choke_tight else 0.0
	_choke_blend = lerpf(_choke_blend, target_choke, minf(1.0, delta * 11.0))

	# Anima o guarda-mão (PumpHandle) na malha 3D se existir
	var pump_node := get_node_or_null("PumpHandle") as Node3D
	if pump_node != null:
		if _pump_anim_time > 0.0:
			var t := 1.0 - (_pump_anim_time / PUMP_DURATION)
			var pump_wave := sin(t * PI)
			pump_node.position.z = -0.36 + (0.12 * pump_wave)
		else:
			pump_node.position.z = lerpf(pump_node.position.z, -0.36, minf(1.0, delta * 12.0))


func _get_subclass_transform_offset() -> Array[Vector3]:
	var pos_off := Vector3(0.12, 0.04, 0.03) * _choke_blend
	var rot_off := Vector3.ZERO

	if _pump_anim_time > 0.0:
		var t := 1.0 - (_pump_anim_time / PUMP_DURATION)
		var wave := sin(t * PI)
		pos_off += Vector3(0.0, -0.04 * wave, 0.06 * wave)
		rot_off += Vector3(deg_to_rad(8.0) * wave, 0.0, deg_to_rad(-10.0) * wave)

	return [pos_off, rot_off]


func get_effective_spread_deg(player: Player) -> float:
	var spread := super.get_effective_spread_deg(player)
	# Choke fechado concentra os 8 balins na metade do cone!
	return spread * lerpf(1.0, 0.42, _choke_blend)


func get_peculiarity_hint() -> String:
	if _choke_blend > 0.5:
		return "8 Balins | Choke Fechado (Focado)"
	return "8 Balins/Tiro | [Botão Dir]: Fechar Choke"
