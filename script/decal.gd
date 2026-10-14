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
	var decal = decals_pool[curr_index]	
	decal.reparent(target)
	
	var up_dir = Vector3.UP
	if abs(normal.y) > 0.999:
		up_dir = Vector3.RIGHT
	
	decal.global_position = point
	decal.look_at(point + normal, up_dir)
	decal.rotate_object_local(Vector3.RIGHT, rad_to_deg(90))
	decal.visible = true
	
	curr_index = (curr_index + 1) % max_decals
