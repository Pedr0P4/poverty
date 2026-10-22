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

@onready var vhead = $Head/VHead;
@onready var rifle: Weapon = $Head/VHead/Rifle
@onready var crosshair: Control = $CanvasLayer/ColorRect
@onready var inventory_ui: InventoryUI = $CanvasLayer/InventoryUI

var curr_speed: float;

static var instance: Player = null
static func get_instance() -> Player:
	return instance


func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	instance = self
	if rifle:
		rifle.reload_state_changed.connect(_on_weapon_reload_state_changed)
	if inventory_ui:
		inventory_ui.equipped_item_changed.connect(_on_equipped_item_changed)
		inventory_ui.inventory_toggled.connect(_on_inventory_toggled)
		_on_equipped_item_changed(inventory_ui.get_selected_hotbar_item())

func is_inventory_open() -> bool:
	return inventory_ui != null and inventory_ui.is_open

func _on_equipped_item_changed(item: ItemData) -> void:
	if rifle:
		var show_rifle := (item != null and item.is_rifle)
		if not show_rifle and rifle.is_reloading:
			rifle.cancel_reload()
		rifle.visible = show_rifle

func _on_inventory_toggled(open: bool) -> void:
	if crosshair:
		crosshair.visible = not open
	if open and rifle and rifle.is_reloading:
		rifle.cancel_reload()

func _on_weapon_reload_state_changed(reloading: bool, progress: float, remaining_sec: float) -> void:
	if inventory_ui:
		inventory_ui.set_reload_visual_state(reloading, progress, remaining_sec)

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and not is_inventory_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		rotate_y(deg_to_rad(-event.relative.x * mouse_sensitivity))
		vhead.rotate_x(deg_to_rad(-event.relative.y * mouse_sensitivity))
	
	if event is InputEventKey:
		if Input.is_action_just_pressed("ui_cancel"):
			if is_inventory_open():
				inventory_ui.toggle_inventory()
			else:
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif event.pressed and not event.echo and event.is_action_pressed("reload"):
			if not is_inventory_open() and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
				if rifle and rifle.visible:
					rifle.start_reload(inventory_ui)

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
