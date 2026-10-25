extends Node

var decal_scene1: PackedScene = preload("res://scene/decal.tscn")

var decals_pool: Array[Decal] = []
var max_decals: int = 50
var curr_index: int = 0

func _ready() -> void:
	for i in range(max_decals):
		var decal: Decal = decal_scene1.instantiate()
		decal.visible = false
		add_child(decal)
		decals_pool.append(decal)

func apply_decal(point: Vector3, normal: Vector3, target: Node3D) -> void:
	if target == null or not is_instance_valid(target):
		return
	var decal: Decal = decals_pool[curr_index]
	if not is_instance_valid(decal):
		decal = decal_scene1.instantiate()
		add_child(decal)
		decals_pool[curr_index] = decal
	decal.reparent(target)
	
	var up_dir = Vector3.UP
	if abs(normal.y) > 0.999:
		up_dir = Vector3.RIGHT
	
	decal.global_position = point
	decal.look_at(point + normal, up_dir)
	decal.rotate_object_local(Vector3.RIGHT, deg_to_rad(90.0))
	decal.visible = true
	decal.scale = Vector3.ONE / 4
	
	curr_index = (curr_index + 1) % max_decals
