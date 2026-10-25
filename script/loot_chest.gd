class_name LootChest
extends StaticBody3D

signal chest_opened(chest_id: String)

var chest_id: String = ""
var is_opened: bool = false
var loot_items: Array[Dictionary] = []

var _lid_pivot: Node3D = null
var _lock_mat: StandardMaterial3D = null
var _glow_light: OmniLight3D = null
var _built: bool = false


func _ready() -> void:
	collision_layer = 1
	collision_mask = 1
	_build_chest_visuals()
	if is_opened:
		_apply_open_visuals_immediate()


func setup(p_id: String, p_loot: Array[Dictionary], p_opened: bool = false) -> void:
	chest_id = p_id
	loot_items = p_loot.duplicate(true)
	if p_opened:
		set_opened_immediate()



func _build_chest_visuals() -> void:
	if _built:
		return
	_built = true

	var wood_mat := StandardMaterial3D.new()
	wood_mat.albedo_color = Color(0.42, 0.25, 0.12, 1.0)
	wood_mat.roughness = 0.85

	var iron_mat := StandardMaterial3D.new()
	iron_mat.albedo_color = Color(0.18, 0.19, 0.22, 1.0)
	iron_mat.metallic = 0.65
	iron_mat.roughness = 0.45

	_lock_mat = StandardMaterial3D.new()
	_lock_mat.albedo_color = Color(0.95, 0.78, 0.22, 1.0)
	_lock_mat.metallic = 0.75
	_lock_mat.roughness = 0.3
	_lock_mat.emission_enabled = true
	_lock_mat.emission = Color(0.95, 0.72, 0.18, 1.0)
	_lock_mat.emission_energy_multiplier = 0.85

	# Base do baú
	var base_mesh := MeshInstance3D.new()
	base_mesh.name = "BaseBox"
	var box := BoxMesh.new()
	box.size = Vector3(1.1, 0.52, 0.7)
	base_mesh.mesh = box
	base_mesh.material_override = wood_mat
	base_mesh.position = Vector3(0.0, 0.26, 0.0)
	add_child(base_mesh)

	# Faixas metálicas laterais na base
	for x_off in [-0.42, 0.42]:
		var strap := MeshInstance3D.new()
		var strap_box := BoxMesh.new()
		strap_box.size = Vector3(0.08, 0.54, 0.73)
		strap.mesh = strap_box
		strap.material_override = iron_mat
		strap.position = Vector3(x_off, 0.26, 0.0)
		add_child(strap)

	# Pivô da tampa na borda traseira
	_lid_pivot = Node3D.new()
	_lid_pivot.name = "LidPivot"
	_lid_pivot.position = Vector3(0.0, 0.52, -0.35)
	add_child(_lid_pivot)

	var lid_mesh := MeshInstance3D.new()
	lid_mesh.name = "LidBox"
	var lid_box := BoxMesh.new()
	lid_box.size = Vector3(1.12, 0.24, 0.72)
	lid_mesh.mesh = lid_box
	lid_mesh.material_override = wood_mat
	lid_mesh.position = Vector3(0.0, 0.12, 0.35)
	_lid_pivot.add_child(lid_mesh)

	for x_off in [-0.42, 0.42]:
		var lid_strap := MeshInstance3D.new()
		var lid_strap_box := BoxMesh.new()
		lid_strap_box.size = Vector3(0.085, 0.26, 0.74)
		lid_strap.mesh = lid_strap_box
		lid_strap.material_override = iron_mat
		lid_strap.position = Vector3(x_off, 0.12, 0.35)
		_lid_pivot.add_child(lid_strap)

	# Fecho dourado frontal
	var lock_mesh := MeshInstance3D.new()
	lock_mesh.name = "LockClasp"
	var lock_box := BoxMesh.new()
	lock_box.size = Vector3(0.16, 0.20, 0.06)
	lock_mesh.mesh = lock_box
	lock_mesh.material_override = _lock_mat
	lock_mesh.position = Vector3(0.0, 0.04, 0.72)
	_lid_pivot.add_child(lock_mesh)

	# Luz suave para destacar o baú fechado
	_glow_light = OmniLight3D.new()
	_glow_light.name = "ChestGlow"
	_glow_light.light_color = Color(1.0, 0.82, 0.35, 1.0)
	_glow_light.light_energy = 0.75
	_glow_light.omni_range = 3.8
	_glow_light.position = Vector3(0.0, 0.85, 0.25)
	add_child(_glow_light)

	# Colisor físico
	var col := CollisionShape3D.new()
	col.name = "CollisionShape3D"
	var shape := BoxShape3D.new()
	shape.size = Vector3(1.14, 0.76, 0.74)
	col.shape = shape
	col.position = Vector3(0.0, 0.38, 0.0)
	add_child(col)


func set_opened_immediate() -> void:
	is_opened = true
	loot_items.clear()
	if _built:
		_apply_open_visuals_immediate()


func _apply_open_visuals_immediate() -> void:
	if _lid_pivot != null:
		_lid_pivot.rotation.x = deg_to_rad(-75.0)
	if _lock_mat != null:
		_lock_mat.emission_enabled = false
	if _glow_light != null:
		_glow_light.visible = false


func can_interact() -> bool:
	return not is_opened


func get_interaction_prompt() -> String:
	if is_opened:
		return ""
	return "[E] Abrir Baú de Sobrevivência"


func interact(player: Player) -> void:
	if is_opened or player == null or player.inventory_ui == null:
		return

	var collected_names: Array[String] = []
	var remaining_items: Array[Dictionary] = []

	for entry in loot_items:
		var item: ItemData = entry.get("item") as ItemData
		var qty: int = int(entry.get("quantity", 1))
		var ammo_amt: int = int(entry.get("ammo", 0))
		if item == null:
			continue

		var added: int = player.inventory_ui.add_loot_item(item, qty, ammo_amt)
		if added > 0:
			if item.is_ammo:
				collected_names.append("+%d %s" % [added, item.item_name])
			elif item.equip_type == ItemData.EquipType.WEAPON:
				collected_names.append("+ %s (%d balas)" % [item.item_name, ammo_amt])
			elif qty > 1:
				collected_names.append("+%d %s" % [added, item.item_name])
			else:
				collected_names.append("+ %s" % item.item_name)

			if item.is_ammo and added < ammo_amt:
				entry["ammo"] = ammo_amt - added
				remaining_items.append(entry)
			elif not item.is_ammo and added < qty:
				entry["quantity"] = qty - added
				remaining_items.append(entry)
		else:
			remaining_items.append(entry)

	loot_items = remaining_items

	if not collected_names.is_empty():
		var msg := "Baú: " + ", ".join(collected_names)
		if not loot_items.is_empty():
			msg += " (Inventário cheio para o restante!)"
		player.inventory_ui.show_loot_toast(msg, Color(0.98, 0.88, 0.35, 1.0))
	else:
		player.inventory_ui.show_loot_toast("Inventário cheio!", Color(1.0, 0.45, 0.4, 1.0))
		return

	if loot_items.is_empty():
		is_opened = true
		if _lock_mat != null:
			_lock_mat.emission_enabled = false
		if _glow_light != null:
			_glow_light.visible = false
		if _lid_pivot != null:
			var tween := create_tween()
			tween.tween_property(_lid_pivot, "rotation:x", deg_to_rad(-75.0), 0.36).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		chest_opened.emit(chest_id)
