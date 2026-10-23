class_name MedkitHand
extends Node3D

signal medkit_use_state_changed(using: bool, progress: float, remaining_sec: float)

@export var sway_pos_sensitivity: float = 0.0016
@export var sway_max_pos: float = 0.055
@export var sway_rot_sensitivity_deg: float = 0.14
@export var sway_roll_sensitivity_deg: float = 0.10
@export var sway_max_rot_deg: float = 6.5
@export var sway_return_speed: float = 11.0
@export var sway_smooth_speed: float = 12.0

var is_using: bool = false
var _use_elapsed: float = 0.0
var _use_anim_blend: float = 0.0

var _base_position: Vector3
var _base_rotation: Vector3

var _sway_target_pos: Vector3 = Vector3.ZERO
var _sway_target_rot: Vector3 = Vector3.ZERO
var _sway_current_pos: Vector3 = Vector3.ZERO
var _sway_current_rot: Vector3 = Vector3.ZERO
var _walk_bob_time: float = 0.0
var _walk_bob_pos: Vector3 = Vector3.ZERO

var _require_release_after_complete: bool = false


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation


func on_equip() -> void:
	cancel_use()
	_require_release_after_complete = Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	# Efeito suave de saque ao equipar o medkit na mão
	_sway_current_pos = Vector3(0.0, -0.14, 0.06)
	_sway_current_rot = Vector3(deg_to_rad(-18.0), 0.0, 0.0)


func on_unequip() -> void:
	cancel_use()
	_use_anim_blend = 0.0
	_sway_target_pos = Vector3.ZERO
	_sway_target_rot = Vector3.ZERO


func apply_mouse_sway(relative: Vector2) -> void:
	if not visible:
		return
	_sway_target_pos.x = clampf(
		_sway_target_pos.x + relative.x * sway_pos_sensitivity,
		-sway_max_pos,
		sway_max_pos
	)
	_sway_target_pos.y = clampf(
		_sway_target_pos.y - relative.y * sway_pos_sensitivity,
		-sway_max_pos,
		sway_max_pos
	)

	var max_rot_rad := deg_to_rad(sway_max_rot_deg)
	_sway_target_rot.y = clampf(
		_sway_target_rot.y + deg_to_rad(relative.x * sway_rot_sensitivity_deg),
		-max_rot_rad,
		max_rot_rad
	)
	_sway_target_rot.x = clampf(
		_sway_target_rot.x + deg_to_rad(relative.y * sway_rot_sensitivity_deg),
		-max_rot_rad,
		max_rot_rad
	)
	_sway_target_rot.z = clampf(
		_sway_target_rot.z + deg_to_rad(relative.x * sway_roll_sensitivity_deg),
		-max_rot_rad,
		max_rot_rad
	)


func _process(delta: float) -> void:
	if not visible:
		if is_using:
			cancel_use()
		return

	var player := Player.get_instance()
	_update_use_state(delta, player)
	_update_sway_and_bob(delta, player)
	_apply_composed_transform(delta)


func _update_use_state(delta: float, player: Player) -> void:
	if player == null or player.is_dead or player.is_inventory_open() or Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
		if is_using:
			cancel_use()
		return

	var fire_pressed := Input.is_action_pressed("fire") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if not fire_pressed:
		_require_release_after_complete = false
		if is_using:
			cancel_use()
		return

	if _require_release_after_complete:
		return

	if not player.can_use_medkit():
		if is_using:
			cancel_use()
		return

	if not is_using:
		is_using = true
		_use_elapsed = 0.0

	var use_duration := maxf(0.1, player.get_medkit_use_duration())
	_use_elapsed += delta
	var progress := clampf(_use_elapsed / use_duration, 0.0, 1.0)
	var remaining := maxf(0.0, use_duration - _use_elapsed)

	medkit_use_state_changed.emit(true, progress, remaining)

	if _use_elapsed >= use_duration:
		is_using = false
		_use_elapsed = 0.0
		_require_release_after_complete = true
		medkit_use_state_changed.emit(false, 1.0, 0.0)
		player.complete_medkit_use()


func cancel_use() -> void:
	if not is_using and _use_elapsed == 0.0:
		return
	is_using = false
	_use_elapsed = 0.0
	medkit_use_state_changed.emit(false, 0.0, 0.0)


func _update_sway_and_bob(delta: float, player: Player) -> void:
	_sway_target_pos = _sway_target_pos.lerp(Vector3.ZERO, minf(1.0, delta * sway_return_speed))
	_sway_target_rot = _sway_target_rot.lerp(Vector3.ZERO, minf(1.0, delta * sway_return_speed))

	_sway_current_pos = _sway_current_pos.lerp(_sway_target_pos, minf(1.0, delta * sway_smooth_speed))
	_sway_current_rot = _sway_current_rot.lerp(_sway_target_rot, minf(1.0, delta * sway_smooth_speed))

	if player != null and player.is_on_floor():
		var horiz_speed := Vector2(player.velocity.x, player.velocity.z).length()
		if horiz_speed > 0.25:
			_walk_bob_time += delta * (4.5 + horiz_speed * 0.65)
			var bob_scale := clampf(horiz_speed / 8.0, 0.2, 1.2)
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


func _apply_composed_transform(delta: float) -> void:
	var target_blend := 1.0 if is_using else 0.0
	_use_anim_blend = lerpf(_use_anim_blend, target_blend, minf(1.0, delta * 10.0))

	var final_pos := _base_position + _sway_current_pos + _walk_bob_pos
	var final_rot := _base_rotation + _sway_current_rot

	if _use_anim_blend > 0.001:
		# Efeito de movimentação contínua do medkit na mão indicando a aplicação dos primeiros socorros
		var wave_fast := sin(_use_elapsed * 11.5)
		var wave_Side := cos(_use_elapsed * 5.75)
		var use_pos := Vector3(
			0.12 + wave_Side * 0.035,
			0.055 + absf(wave_fast) * 0.045,
			-0.03 + sin(_use_elapsed * 5.75) * 0.03
		)
		var use_rot := Vector3(
			deg_to_rad(14.0) + deg_to_rad(13.0) * wave_fast,
			deg_to_rad(20.0) + deg_to_rad(10.0) * wave_Side,
			deg_to_rad(-15.0) + deg_to_rad(14.0) * wave_fast
		)
		final_pos += use_pos * _use_anim_blend
		final_rot += use_rot * _use_anim_blend

	position = final_pos
	rotation = final_rot
