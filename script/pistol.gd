class_name PistolWeapon
extends Weapon

const BURST_COUNT: int = 3
const BURST_INTERVAL: float = 0.055
const POST_BURST_COOLDOWN: float = 0.26

var _burst_shots_remaining: int = 0
var _burst_timer: float = 0.0


func _setup_weapon_stats() -> void:
	weapon_id = "pistol"
	weapon_title = "Pistola Tática"
	ammo_category = ItemData.AmmoCategory.SMALL
	automatic = false
	fire_rate = 0.135
	reload_time = 0.95
	projectiles_per_shot = 1
	damage_multiplier = 1.0

	base_spread_deg = 0.22
	max_spread_deg = 3.2
	spread_increase_per_shot = 0.52
	spread_recovery_rate = 11.5
	move_spread_penalty_deg = 0.65

	camera_recoil_pitch_deg = 0.42
	camera_recoil_yaw_deg = 0.18
	visual_kick_pos = Vector3(0.008, 0.025, 0.055)
	visual_kick_rot_deg = Vector3(8.5, 1.2, 1.0)
	recoil_recovery_speed = 18.0

	# Pistola é leve: responde mais rápido ao movimento da câmera
	sway_pos_sensitivity = 0.0014
	sway_max_pos = 0.045
	sway_rot_sensitivity_deg = 0.13
	sway_roll_sensitivity_deg = 0.10
	sway_max_rot_deg = 5.5
	sway_return_speed = 13.0
	sway_smooth_speed = 15.0

	trail_color = Color(0.55, 0.92, 1.0, 0.92)
	trail_thickness = 0.02
	trail_duration = 0.10


func _on_reload_started() -> void:
	_burst_shots_remaining = 0
	_burst_timer = 0.0


func _on_weapon_unequipped(_camera: Camera3D, _player: Player) -> void:
	_burst_shots_remaining = 0
	_burst_timer = 0.0


func _handle_secondary_action(
	just_pressed: bool,
	_is_pressed: bool,
	_just_released: bool,
	camera: Camera3D,
	player: Player
) -> void:
	# Peculiaridade da Pistola: Botão direito dispara uma rajada rápida de 3 tiros!
	if just_pressed and not is_reloading and _burst_shots_remaining == 0 and _fire_cooldown <= 0.0:
		if try_fire_shot(camera, player):
			_burst_shots_remaining = BURST_COUNT - 1
			_burst_timer = BURST_INTERVAL
			_fire_cooldown = POST_BURST_COOLDOWN


func _weapon_process(delta: float, camera: Camera3D, player: Player) -> void:
	if _burst_shots_remaining <= 0:
		return
	if is_reloading or not visible or player == null or player.is_inventory_open():
		_burst_shots_remaining = 0
		return

	_burst_timer -= delta
	if _burst_timer <= 0.0:
		_fire_cooldown = 0.0
		if try_fire_shot(camera, player):
			_burst_shots_remaining -= 1
			if _burst_shots_remaining > 0:
				_burst_timer = BURST_INTERVAL
			else:
				_fire_cooldown = POST_BURST_COOLDOWN
		else:
			_burst_shots_remaining = 0


func get_peculiarity_hint() -> String:
	if _burst_shots_remaining > 0:
		return "Disparando Rajada 3x!"
	return "Semi | [Botão Dir]: Rajada 3x"
