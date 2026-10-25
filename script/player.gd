class_name Player
extends CharacterBody3D

@export_category("Player Settings")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var speed_mult: float = 2.5
@export var crouch_speed_mult: float = 0.45
@export var acceleration: float = 1
@export var friction: float = 2
@export var max_health: float = 100.0

@export_category("Stamina Settings")
@export var max_stamina: float = 100.0
@export var stamina_drain_rate: float = 22.0
@export var stamina_regen_rate: float = 18.0
@export var stamina_regen_delay: float = 0.45
@export var stamina_exhausted_recovery_ratio: float = 0.20

@export_category("Stealth & Crouch Settings")
@export var crouch_camera_offset: float = -0.55
@export var crouch_transition_speed: float = 10.0

@export_category("Control Settings")
@export var mouse_sensitivity: float = 0.2

@onready var shape_mesh: MeshInstance3D = $Shape
@onready var collision_shape: CollisionShape3D = $Collision
@onready var head: Node3D = $Head
@onready var vhead: Node3D = $Head/VHead
@onready var camera: Camera3D = $Head/VHead/Camera
@onready var rifle: Weapon = $Head/VHead/Rifle
@onready var medkit_hand: MedkitHand = $Head/VHead/Medkit
@onready var damage_overlay: ColorRect = $CanvasLayer/DamageOverlay
@onready var crosshair: Control = $CanvasLayer/ColorRect
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI

var curr_speed: float
var health: float = 100.0
var stamina: float = 100.0
var is_dead: bool = false
var is_running: bool = false
var is_crouching: bool = false
var is_stamina_exhausted: bool = false
var active_weapon: Weapon = null
var _weapons: Dictionary = {}

var _damage_flash_alpha: float = 0.0
var _low_health_pulse_time: float = 0.0

var _stamina_regen_timer: float = 0.0
var _stamina_bar_alpha: float = 0.0
var _stamina_fade_hold_timer: float = 0.0

var _crouch_blend: float = 0.0
var _base_head_y: float = 0.47143447
var _standing_capsule_height: float = 2.0
var _crouch_capsule_height: float = 1.35
var _capsule_shape: CapsuleShape3D = null
var _footstep_sound_timer: float = 0.0

static var instance: Player = null
static func get_instance() -> Player:
	return instance


func _ready() -> void:
	_ensure_crouch_input_action()
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	instance = self
	health = max_health
	stamina = max_stamina
	is_dead = false
	is_running = false
	is_crouching = false
	is_stamina_exhausted = false
	if head != null:
		_base_head_y = head.position.y
	if collision_shape != null and collision_shape.shape is CapsuleShape3D:
		_capsule_shape = (collision_shape.shape as CapsuleShape3D).duplicate() as CapsuleShape3D
		collision_shape.shape = _capsule_shape
		_standing_capsule_height = _capsule_shape.height
	_register_weapons()
	if medkit_hand != null:
		medkit_hand.visible = false
		if not medkit_hand.medkit_use_state_changed.is_connected(_on_medkit_use_state_changed):
			medkit_hand.medkit_use_state_changed.connect(_on_medkit_use_state_changed)
	if inventory_ui:
		inventory_ui.equipped_item_changed.connect(_on_equipped_item_changed)
		inventory_ui.inventory_toggled.connect(_on_inventory_toggled)
		_on_equipped_item_changed(inventory_ui.get_selected_hotbar_item())
		inventory_ui.update_stamina_hud(1.0, 0.0, false)
	_update_damage_overlay(0.0)


func _ensure_crouch_input_action() -> void:
	if not InputMap.has_action("mv_crouch"):
		InputMap.add_action("mv_crouch")
		var ev_ctrl := InputEventKey.new()
		ev_ctrl.physical_keycode = KEY_CTRL
		InputMap.action_add_event("mv_crouch", ev_ctrl)
		var ev_c := InputEventKey.new()
		ev_c.physical_keycode = KEY_C
		InputMap.action_add_event("mv_crouch", ev_c)


func _process(delta: float) -> void:
	if is_dead:
		return
	_update_damage_overlay(delta)
	_update_stamina_ui(delta)
	_update_interaction_raycast()


func _update_damage_overlay(delta: float) -> void:
	if damage_overlay == null:
		return

	_damage_flash_alpha = move_toward(_damage_flash_alpha, 0.0, delta * 1.15)

	var health_ratio := clampf(health / maxf(1.0, max_health), 0.0, 1.0)
	var missing_ratio := 1.0 - health_ratio

	# Avermelhamento progressivo conforme a vida desce (0 em 100% de vida, até ~0.48 perto de 0%)
	var base_red_alpha := pow(missing_ratio, 1.15) * 0.48
	if missing_ratio > 0.6:
		_low_health_pulse_time += delta * 5.0
		var pulse := (sin(_low_health_pulse_time) * 0.5 + 0.5) * 0.06 * ((missing_ratio - 0.6) / 0.4)
		base_red_alpha += pulse

	var final_alpha := clampf(base_red_alpha + _damage_flash_alpha, 0.0, 0.72)
	damage_overlay.color = Color(0.82, 0.04, 0.04, final_alpha)


func take_damage(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return

	health = maxf(0.0, health - amount)
	# Pisca levemente em vermelho ao receber dano
	_damage_flash_alpha = clampf(_damage_flash_alpha + 0.28, 0.0, 0.42)
	apply_camera_recoil(deg_to_rad(randf_range(-1.2, 1.2)), deg_to_rad(randf_range(-1.2, 1.2)))

	if inventory_ui != null:
		inventory_ui._update_ammo_hud()

	if health <= 0.0:
		is_dead = true
		if medkit_hand != null and medkit_hand.is_using:
			medkit_hand.cancel_use()
		call_deferred("_on_player_died")


func heal(amount: float) -> void:
	if is_dead or amount <= 0.0:
		return
	health = minf(max_health, health + amount)
	if inventory_ui != null:
		inventory_ui._update_ammo_hud()


func can_use_medkit() -> bool:
	if is_dead or health >= max_health:
		return false
	return inventory_ui != null and inventory_ui.has_selected_medkit()


func get_medkit_use_duration() -> float:
	if inventory_ui != null:
		var item := inventory_ui.get_selected_medkit_item()
		if item != null and item.use_time > 0.0:
			return item.use_time
	return 2.5


func complete_medkit_use() -> void:
	if inventory_ui == null or is_dead:
		return
	var item := inventory_ui.get_selected_medkit_item()
	var heal_amount := item.heal_amount if item != null and item.heal_amount > 0.0 else 50.0
	if inventory_ui.consume_selected_medkit(1):
		heal(heal_amount)


func _on_player_died() -> void:
	velocity = Vector3.ZERO
	set_physics_process(false)
	if active_weapon != null:
		active_weapon.visible = false
	if medkit_hand != null:
		medkit_hand.visible = false

	var survival_time: float = 0.0
	var kills: int = 0
	var terreno := GeradorTerreno.get_instance()
	if terreno != null:
		survival_time = terreno.get_tempo_sobrevivencia()
		kills = terreno.get_inimigos_eliminados()

	if inventory_ui != null:
		inventory_ui.show_game_over(survival_time, kills)
	else:
		if is_inside_tree() and get_tree() != null:
			get_tree().reload_current_scene()



func _register_weapons() -> void:
	_weapons.clear()
	for child in vhead.get_children():
		if child is Weapon:
			var w: Weapon = child as Weapon
			w.visible = false
			if not w.reload_state_changed.is_connected(_on_weapon_reload_state_changed):
				w.reload_state_changed.connect(_on_weapon_reload_state_changed)
			_weapons[w.weapon_id] = w


func is_inventory_open() -> bool:
	return inventory_ui != null and inventory_ui.is_open


func get_active_weapon() -> Weapon:
	return active_weapon


func get_active_weapon_hint() -> String:
	if active_weapon != null and active_weapon.visible:
		return active_weapon.get_peculiarity_hint()
	return ""


func _on_equipped_item_changed(item: ItemData) -> void:
	var next_weapon: Weapon = null
	var show_medkit: bool = false

	if item != null and item.is_weapon():
		if _weapons.has(item.id):
			next_weapon = _weapons[item.id]
		elif item.is_rifle and _weapons.has("rifle"):
			next_weapon = _weapons["rifle"]
	elif item != null and item.id == "medkit":
		show_medkit = true

	if active_weapon != next_weapon:
		if active_weapon != null:
			active_weapon.on_unequip(camera, self)
			active_weapon.visible = false
		active_weapon = next_weapon
		if active_weapon != null:
			active_weapon.visible = true
			active_weapon.on_equip(camera, self)
		elif camera != null:
			camera.fov = 75.0

	if medkit_hand != null:
		if show_medkit:
			if not medkit_hand.visible:
				medkit_hand.visible = true
				medkit_hand.on_equip()
		else:
			if medkit_hand.visible:
				medkit_hand.on_unequip()
				medkit_hand.visible = false


func _on_inventory_toggled(open: bool) -> void:
	if crosshair:
		crosshair.visible = not open
	if open and active_weapon and active_weapon.is_reloading:
		active_weapon.cancel_reload()
	if open and medkit_hand and medkit_hand.is_using:
		medkit_hand.cancel_use()


func _on_weapon_reload_state_changed(reloading: bool, progress: float, remaining_sec: float) -> void:
	if inventory_ui:
		inventory_ui.set_reload_visual_state(reloading, progress, remaining_sec)


func _on_medkit_use_state_changed(using: bool, progress: float, remaining_sec: float) -> void:
	if inventory_ui:
		inventory_ui.set_medkit_visual_state(using, progress, remaining_sec)


func apply_camera_recoil(pitch_rad: float, yaw_rad: float) -> void:
	rotate_y(yaw_rad)
	vhead.rotation.x = clampf(vhead.rotation.x + pitch_rad, deg_to_rad(-88.0), deg_to_rad(88.0))


func _input(event: InputEvent) -> void:
	if is_dead:
		return

	if event is InputEventMouseMotion and not is_inventory_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		vhead.rotation.x = clampf(
			vhead.rotation.x + deg_to_rad(-event.relative.y * mouse_sensitivity),
			deg_to_rad(-88.0),
			deg_to_rad(88.0)
		)
		if active_weapon != null and active_weapon.visible:
			active_weapon.apply_mouse_sway(event.relative)
		elif medkit_hand != null and medkit_hand.visible:
			medkit_hand.apply_mouse_sway(event.relative)

	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if not is_inventory_open() and Input.get_mouse_mode() != Input.MOUSE_MODE_CAPTURED:
			Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_cancel"):
			if is_inventory_open():
				inventory_ui.toggle_inventory()
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.pressed and not event.echo and event.is_action_pressed("reload"):
			if not is_inventory_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				if active_weapon != null and active_weapon.visible:
					active_weapon.start_reload(inventory_ui)


func _update_stamina_ui(delta: float) -> void:
	if inventory_ui == null:
		return

	var ratio := clampf(stamina / maxf(1.0, max_stamina), 0.0, 1.0)
	if is_running or stamina < max_stamina - 0.01:
		_stamina_bar_alpha = move_toward(_stamina_bar_alpha, 1.0, delta * 8.5)
		if stamina < max_stamina - 0.01:
			_stamina_fade_hold_timer = 0.22
	else:
		if _stamina_fade_hold_timer > 0.0:
			_stamina_fade_hold_timer = maxf(0.0, _stamina_fade_hold_timer - delta)
		else:
			_stamina_bar_alpha = move_toward(_stamina_bar_alpha, 0.0, delta * 2.2)

	inventory_ui.update_stamina_hud(ratio, _stamina_bar_alpha, is_stamina_exhausted)


func _update_interaction_raycast() -> void:
	if inventory_ui == null:
		return
	if is_dead or is_inventory_open():
		inventory_ui.set_interaction_prompt("")
		return

	var target_obj := _get_looked_at_interactable()
	if target_obj != null and target_obj.has_method("get_interaction_prompt"):
		inventory_ui.set_interaction_prompt(target_obj.get_interaction_prompt())
	else:
		inventory_ui.set_interaction_prompt("")


func _get_looked_at_interactable() -> Node:
	if camera == null or not is_instance_valid(camera):
		return null

	var space_state := get_world_3d().direct_space_state
	var origin := camera.global_position
	var forward := -camera.global_transform.basis.z.normalized()
	var end := origin + forward * 3.4

	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1 | 4
	query.collide_with_bodies = true
	query.collide_with_areas = true
	query.exclude = [get_rid()]

	var result := space_state.intersect_ray(query)
	if not result.is_empty():
		var col: Object = result.get("collider")
		if col is Node:
			var n := col as Node
			if n.has_method("can_interact") and n.can_interact():
				return n
			if n.get_parent() != null and n.get_parent().has_method("can_interact") and n.get_parent().can_interact():
				return n.get_parent()

	return null


func try_interact() -> bool:
	if is_dead or is_inventory_open():
		return false
	var target_obj := _get_looked_at_interactable()
	if target_obj != null and target_obj.has_method("interact"):
		target_obj.interact(self)
		_update_interaction_raycast()
		return true
	return false


func get_head_global_position() -> Vector3:
	if camera != null and is_instance_valid(camera):
		return camera.global_position
	if head != null and is_instance_valid(head):
		return head.global_position
	return global_position + Vector3(0.0, 0.4 + crouch_camera_offset * _crouch_blend, 0.0)


func get_torso_global_position() -> Vector3:
	return global_position + Vector3(0.0, -0.3 * _crouch_blend, 0.0)


func _can_stand_up() -> bool:
	var space_state := get_world_3d().direct_space_state
	var from_pos := global_position + Vector3(0.0, 0.2, 0.0)
	var to_pos := global_position + Vector3(0.0, 1.08, 0.0)
	var query := PhysicsRayQueryParameters3D.create(from_pos, to_pos)
	query.collision_mask = 1
	query.exclude = [get_rid()]
	var result := space_state.intersect_ray(query)
	return result.is_empty()


func _update_crouch_state(delta: float, wants_to_crouch: bool, wants_to_run: bool) -> void:
	var can_sprint := not is_stamina_exhausted and stamina > 0.0
	if wants_to_run and can_sprint:
		if is_crouching:
			if _can_stand_up():
				is_crouching = false
		if not is_crouching:
			is_running = true
		else:
			is_running = false
	else:
		is_running = false
		if wants_to_crouch:
			is_crouching = true
		elif is_crouching and _can_stand_up():
			is_crouching = false

	var target_blend := 1.0 if is_crouching else 0.0
	_crouch_blend = move_toward(_crouch_blend, target_blend, delta * crouch_transition_speed)

	if head != null:
		head.position.y = _base_head_y + (crouch_camera_offset * _crouch_blend)

	if _capsule_shape != null and collision_shape != null:
		var cur_h := lerpf(_standing_capsule_height, _crouch_capsule_height, _crouch_blend)
		_capsule_shape.height = cur_h
		collision_shape.position.y = (cur_h - _standing_capsule_height) * 0.5

	if shape_mesh != null:
		var scale_y := lerpf(1.0, _crouch_capsule_height / _standing_capsule_height, _crouch_blend)
		shape_mesh.scale.y = scale_y
		shape_mesh.position.y = (scale_y - 1.0) * (_standing_capsule_height * 0.5)


func _update_stamina(delta: float, is_moving_horizontally: bool) -> void:
	if is_running and is_moving_horizontally:
		stamina = maxf(0.0, stamina - stamina_drain_rate * delta)
		_stamina_regen_timer = stamina_regen_delay
		if stamina <= 0.0:
			stamina = 0.0
			is_stamina_exhausted = true
			is_running = false
	else:
		if _stamina_regen_timer > 0.0:
			_stamina_regen_timer = maxf(0.0, _stamina_regen_timer - delta)
		elif stamina < max_stamina:
			stamina = minf(max_stamina, stamina + stamina_regen_rate * delta)
			if is_stamina_exhausted and stamina >= max_stamina * stamina_exhausted_recovery_ratio:
				is_stamina_exhausted = false


func _physics_process(delta: float) -> void:
	if is_dead:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	var controls_active := not is_inventory_open()
	var input_dir := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down") if controls_active else Vector2.ZERO
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var has_move_input := direction.length_squared() > 0.001

	var wants_to_run := controls_active and Input.is_action_pressed("mv_run") and has_move_input
	var wants_to_crouch := controls_active and Input.is_action_pressed("mv_crouch")

	_update_crouch_state(delta, wants_to_crouch, wants_to_run)
	_update_stamina(delta, has_move_input)

	curr_speed = speed
	if is_crouching:
		curr_speed = speed * crouch_speed_mult
	elif is_running:
		curr_speed = speed * speed_mult

	if controls_active and Input.is_action_just_pressed("ui_accept") and is_on_floor():
		if not is_crouching or _can_stand_up():
			is_crouching = false
			velocity.y = jump_velocity

	if direction:
		velocity.x = move_toward(velocity.x, direction.x * curr_speed, acceleration)
		velocity.z = move_toward(velocity.z, direction.z * curr_speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, friction)
		velocity.z = move_toward(velocity.z, 0, friction)

	move_and_slide()

	# Emissão sonora de passos (agachado é silencioso / stealth)
	var horiz_speed := Vector2(velocity.x, velocity.z).length()
	if is_on_floor() and not is_crouching and horiz_speed > 0.55:
		_footstep_sound_timer -= delta
		if _footstep_sound_timer <= 0.0:
			_footstep_sound_timer = 0.22 if is_running else 0.36
			Enemy.notify_player_footstep(get_tree(), global_position, is_running)
	else:
		_footstep_sound_timer = 0.08
