class_name SniperWeapon
extends Weapon

var _is_scoped: bool = false
var _scope_blend: float = 0.0
var _default_fov: float = 75.0
var _bolt_anim_time: float = 0.0
const BOLT_DURATION: float = 0.65


func _setup_weapon_stats() -> void:
	weapon_id = "sniper"
	weapon_title = "Sniper de Precisão"
	ammo_category = ItemData.AmmoCategory.LARGE
	automatic = false
	fire_rate = 1.15
	reload_time = 2.4
	projectiles_per_shot = 1
	max_range = 3500.0

	# Sem mirar (hip-fire) tem muita imprecisão; mirando com botão direito fica cirúrgica!
	base_spread_deg = 5.5
	max_spread_deg = 10.0
	spread_increase_per_shot = 3.5
	spread_recovery_rate = 3.5
	move_spread_penalty_deg = 4.2

	camera_recoil_pitch_deg = 3.2
	camera_recoil_yaw_deg = 0.6
	visual_kick_pos = Vector3(0.015, 0.045, 0.16)
	visual_kick_rot_deg = Vector3(14.5, 2.0, 2.5)
	recoil_recovery_speed = 8.0

	sway_pos_sensitivity = 0.0022
	sway_max_pos = 0.075
	sway_rot_sensitivity_deg = 0.20
	sway_roll_sensitivity_deg = 0.15
	sway_max_rot_deg = 9.0
	sway_return_speed = 7.5
	sway_smooth_speed = 7.5

	trail_color = Color(0.82, 0.55, 1.0, 0.96)
	trail_thickness = 0.042
	trail_duration = 0.35


func _handle_secondary_action(
	_just_pressed: bool,
	is_pressed: bool,
	_just_released: bool,
	_camera: Camera3D,
	_player: Player
) -> void:
	_is_scoped = is_pressed and not is_reloading


func _on_combat_inactive(_delta: float, _camera: Camera3D, _player: Player) -> void:
	_is_scoped = false


func _on_weapon_unequipped(camera: Camera3D, _player: Player) -> void:
	_is_scoped = false
	_scope_blend = 0.0
	_bolt_anim_time = 0.0
	if camera != null:
		camera.fov = _default_fov


func _on_shot_fired(_camera: Camera3D, _player: Player) -> void:
	_bolt_anim_time = BOLT_DURATION


func _weapon_process(delta: float, camera: Camera3D, _player: Player) -> void:
	if is_reloading:
		_is_scoped = false
		_bolt_anim_time = 0.0

	if _bolt_anim_time > 0.0:
		_bolt_anim_time = maxf(0.0, _bolt_anim_time - delta)

	var target_scope := 1.0 if _is_scoped else 0.0
	_scope_blend = lerpf(_scope_blend, target_scope, minf(1.0, delta * 10.0))

	if camera != null and visible:
		var target_fov := lerpf(_default_fov, 22.0, _scope_blend)
		camera.fov = lerpf(camera.fov, target_fov, minf(1.0, delta * 12.0))


func _get_subclass_transform_offset() -> Array[Vector3]:
	var scope_pos := Vector3(0.28, 0.14, 0.12) * _scope_blend
	var scope_rot := Vector3.ZERO

	if _bolt_anim_time > 0.0:
		var t := 1.0 - (_bolt_anim_time / BOLT_DURATION)
		var wave := sin(t * PI)
		scope_pos += Vector3(0.0, -0.025 * wave, 0.04 * wave)
		scope_rot += Vector3(deg_to_rad(5.0) * wave, 0.0, deg_to_rad(14.0) * wave)

	return [scope_pos, scope_rot]


func get_effective_spread_deg(player: Player) -> float:
	var spread := super.get_effective_spread_deg(player)
	# Quando está com a luneta ativa, reduz drasticamente o spread (quase zero se parado)
	if _scope_blend > 0.75:
		var move_pen := 0.0
		if player != null:
			var horiz_speed := Vector2(player.velocity.x, player.velocity.z).length()
			if horiz_speed > 0.4:
				move_pen = 1.2 * clampf(horiz_speed / player.speed, 0.2, 1.5)
		return 0.02 + move_pen
	return lerpf(spread, 0.15, _scope_blend)


func _get_sway_multiplier() -> float:
	return lerpf(1.0, 0.22, _scope_blend)


func get_peculiarity_hint() -> String:
	if _scope_blend > 0.5:
		return "Luneta 3.5x Ativa (Alta Precisão)"
	return "Hip-Fire Impreciso | [Botão Dir]: Luneta 3.5x"
