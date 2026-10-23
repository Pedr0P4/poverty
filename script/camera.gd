extends Camera3D

var _was_alt_pressed: bool = false


func _process(delta: float) -> void:
	var player := Player.get_instance()
	if player == null:
		return

	var weapon := player.get_active_weapon()
	if weapon == null:
		_was_alt_pressed = false
		return

	var fire_just_pressed := Input.is_action_just_pressed("fire")
	var fire_pressed := Input.is_action_pressed("fire")

	var alt_pressed := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT)
	var alt_just_pressed := alt_pressed and not _was_alt_pressed
	var alt_just_released := (not alt_pressed) and _was_alt_pressed
	_was_alt_pressed = alt_pressed

	weapon.process_combat_input(
		delta,
		self,
		player,
		fire_just_pressed,
		fire_pressed,
		alt_just_pressed,
		alt_pressed,
		alt_just_released
	)
