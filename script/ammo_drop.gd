class_name AmmoDrop
extends Area3D

var ammo_item: ItemData = null
var bullet_count: int = 12
var _collected: bool = false
var _visual_root: Node3D = null
var _bob_time: float = 0.0
var _lifetime: float = 90.0


func _ready() -> void:
	collision_layer = 4
	collision_mask = 0
	monitoring = false
	monitorable = true
	_bob_time = randf() * TAU
	_build_visuals()


func setup(item: ItemData, bullets: int) -> void:
	ammo_item = item
	bullet_count = maxi(1, bullets)
	if is_inside_tree():
		_build_visuals()


func _build_visuals() -> void:
	if _visual_root != null and is_instance_valid(_visual_root):
		_visual_root.queue_free()

	_visual_root = Node3D.new()
	_visual_root.name = "VisualRoot"
	add_child(_visual_root)

	var box_color := Color(0.92, 0.78, 0.22, 1.0)
	if ammo_item != null:
		box_color = ammo_item.icon_modulate

	var mat := StandardMaterial3D.new()
	mat.albedo_color = box_color
	mat.metallic = 0.35
	mat.roughness = 0.45
	mat.emission_enabled = true
	mat.emission = box_color * 0.55
	mat.emission_energy_multiplier = 0.65

	var mesh_inst := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.34, 0.22, 0.24)
	mesh_inst.mesh = box
	mesh_inst.material_override = mat
	mesh_inst.position = Vector3(0.0, 0.22, 0.0)
	_visual_root.add_child(mesh_inst)

	var stripe_mat := StandardMaterial3D.new()
	stripe_mat.albedo_color = Color(0.15, 0.16, 0.18, 1.0)
	stripe_mat.roughness = 0.4

	var stripe := MeshInstance3D.new()
	var stripe_box := BoxMesh.new()
	stripe_box.size = Vector3(0.36, 0.05, 0.26)
	stripe.mesh = stripe_box
	stripe.material_override = stripe_mat
	stripe.position = Vector3(0.0, 0.26, 0.0)
	_visual_root.add_child(stripe)

	if get_node_or_null("CollisionShape3D") == null:
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		var shape := SphereShape3D.new()
		shape.radius = 0.42
		col.shape = shape
		col.position = Vector3(0.0, 0.25, 0.0)
		add_child(col)


func _process(delta: float) -> void:
	if _collected:
		return

	_lifetime -= delta
	if _lifetime <= 0.0:
		queue_free()
		return

	_bob_time += delta * 3.2
	if _visual_root != null:
		_visual_root.position.y = sin(_bob_time) * 0.05
		_visual_root.rotation.y += delta * 1.4

	var player := Player.get_instance()
	if player != null and is_instance_valid(player) and not player.is_dead:
		if global_position.distance_to(player.global_position) <= 1.45:
			interact(player)


func can_interact() -> bool:
	return not _collected


func get_interaction_prompt() -> String:
	if _collected or ammo_item == null:
		return ""
	return "[E] Coletar %s (+%d)" % [ammo_item.item_name, bullet_count]


func interact(player: Player) -> void:
	if _collected or player == null or player.inventory_ui == null or ammo_item == null:
		return

	var added: int = player.inventory_ui.add_loot_item(ammo_item, 1, bullet_count)
	if added > 0:
		bullet_count -= added
		player.inventory_ui.show_loot_toast("+%d %s" % [added, ammo_item.item_name], ammo_item.icon_modulate)
		if bullet_count <= 0:
			_collected = true
			queue_free()
	else:
		player.inventory_ui.show_loot_toast("Inventário sem espaço para %s!" % ammo_item.item_name, Color(1.0, 0.45, 0.4, 1.0))
