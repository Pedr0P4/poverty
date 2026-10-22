class_name Weapon
extends Node3D

signal reload_state_changed(reloading: bool, progress: float, remaining_sec: float)

@export var begin: Marker3D
@export var reload_time: float = 1.5
@export var trail_duration: float = 0.12
@export var max_trail_length: float = 120.0

var is_reloading: bool = false
var _reload_elapsed: float = 0.0
var _reloading_slot: InventorySlotData = null
var _inventory_ui: InventoryUI = null
var _base_position: Vector3
var _base_rotation: Vector3


func _ready() -> void:
	_base_position = position
	_base_rotation = rotation


func _process(delta: float) -> void:
	if not is_reloading:
		return

	if (
		not visible
		or _inventory_ui == null
		or _inventory_ui.is_open
		or _inventory_ui.get_selected_weapon_slot() != _reloading_slot
		or not _inventory_ui.can_reload_active_weapon()
	):
		cancel_reload()
		return

	_reload_elapsed += delta
	var progress := clampf(_reload_elapsed / reload_time, 0.0, 1.0)
	var remaining := maxf(0.0, reload_time - _reload_elapsed)

	# Animação procedural de recarga na arma 3D
	var anim_wave := sin(progress * PI)
	position = _base_position + Vector3(0.0, -0.14 * anim_wave, 0.05 * anim_wave)
	rotation = _base_rotation + Vector3(deg_to_rad(-28.0) * anim_wave, 0.0, deg_to_rad(18.0) * anim_wave)

	reload_state_changed.emit(true, progress, remaining)

	if _reload_elapsed >= reload_time:
		is_reloading = false
		_reload_elapsed = 0.0
		_reloading_slot = null
		position = _base_position
		rotation = _base_rotation
		_inventory_ui.reload_active_weapon()
		reload_state_changed.emit(false, 1.0, 0.0)


func start_reload(inventory_ui: InventoryUI) -> void:
	if not visible or is_reloading or inventory_ui == null or inventory_ui.is_open:
		return
	if not inventory_ui.can_reload_active_weapon():
		return

	_inventory_ui = inventory_ui
	_reloading_slot = inventory_ui.get_selected_weapon_slot()
	is_reloading = true
	_reload_elapsed = 0.0
	reload_state_changed.emit(true, 0.0, reload_time)


func cancel_reload() -> void:
	if not is_reloading:
		return
	is_reloading = false
	_reload_elapsed = 0.0
	_reloading_slot = null
	position = _base_position
	rotation = _base_rotation
	reload_state_changed.emit(false, 0.0, 0.0)


func spawn_bullet_trail(from_pos: Vector3, to_pos: Vector3) -> void:
	var diff := to_pos - from_pos
	var dist := diff.length()
	if dist < 0.05:
		return

	var dir := diff / dist
	if dist > max_trail_length:
		dist = max_trail_length
		to_pos = from_pos + dir * dist

	var trail_instance := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.025, 0.025, dist)
	trail_instance.mesh = box_mesh
	trail_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_color = Color(1.0, 0.88, 0.32, 0.92)
	trail_instance.material_override = mat

	var scene_root := get_tree().current_scene
	if scene_root == null:
		return
	scene_root.add_child(trail_instance)

	var up_dir := Vector3.UP
	if absf(dir.y) > 0.99:
		up_dir = Vector3.RIGHT

	trail_instance.global_position = (from_pos + to_pos) * 0.5
	trail_instance.look_at(to_pos, up_dir)

	var tween := trail_instance.create_tween()
	tween.tween_property(mat, "albedo_color:a", 0.0, trail_duration)
	tween.tween_callback(trail_instance.queue_free)
