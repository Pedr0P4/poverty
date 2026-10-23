class_name Player
extends CharacterBody3D

@export_category("Player Settings")
@export var speed: float = 5.0
@export var jump_velocity: float = 4.5
@export var speed_mult: float = 2.5
@export var acceleration: float = 1
@export var friction: float = 2

@export_category("Control Settings")
@export var mouse_sensitivity: float = 0.2

@onready var vhead: Node3D = $Head/VHead
@onready var camera: Camera3D = $Head/VHead/Camera
@onready var rifle: Weapon = $Head/VHead/Rifle
@onready var crosshair: Control = $CanvasLayer/ColorRect
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI

var curr_speed: float
var active_weapon: Weapon = null
var _weapons: Dictionary = {}

static var instance: Player = null
static func get_instance() -> Player:
	return instance


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	instance = self
	_register_weapons()
	if inventory_ui:
		inventory_ui.equipped_item_changed.connect(_on_equipped_item_changed)
		inventory_ui.inventory_toggled.connect(_on_inventory_toggled)
		_on_equipped_item_changed(inventory_ui.get_selected_hotbar_item())


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
	if item != null and item.is_weapon():
		if _weapons.has(item.id):
			next_weapon = _weapons[item.id]
		elif item.is_rifle and _weapons.has("rifle"):
			next_weapon = _weapons["rifle"]

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


func _on_inventory_toggled(open: bool) -> void:
	if crosshair:
		crosshair.visible = not open
	if open and active_weapon and active_weapon.is_reloading:
		active_weapon.cancel_reload()


func _on_weapon_reload_state_changed(reloading: bool, progress: float, remaining_sec: float) -> void:
	if inventory_ui:
		inventory_ui.set_reload_visual_state(reloading, progress, remaining_sec)


func apply_camera_recoil(pitch_rad: float, yaw_rad: float) -> void:
	rotate_y(yaw_rad)
	vhead.rotation.x = clampf(vhead.rotation.x + pitch_rad, deg_to_rad(-88.0), deg_to_rad(88.0))


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_inventory_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		vhead.rotation.x = clampf(
			vhead.rotation.x + deg_to_rad(-event.relative.y * mouse_sensitivity),
			deg_to_rad(-88.0),
			deg_to_rad(88.0)
		)
		if active_weapon != null and active_weapon.visible:
			active_weapon.apply_mouse_sway(event.relative)

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


func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

	curr_speed = speed
	if Input.is_action_pressed("mv_run"):
		curr_speed = speed * speed_mult

	if Input.is_action_just_pressed("ui_accept") and is_on_floor():
		velocity.y = jump_velocity

	var input_dir := Input.get_vector("mv_left", "mv_right", "mv_up", "mv_down")
	var direction := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	if direction:
		velocity.x = move_toward(velocity.x, direction.x * curr_speed, acceleration)
		velocity.z = move_toward(velocity.z, direction.z * curr_speed, acceleration)
	else:
		velocity.x = move_toward(velocity.x, 0, friction)
		velocity.z = move_toward(velocity.z, 0, friction)

	move_and_slide()
