extends Camera3D

const MAX_RANGE: float = 2000.0

@onready var weapon: Weapon = $"../../../Rifle";

@export var bullet_decal: PackedScene = preload("res://scene/decal.tscn")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("fire"):
			shoot()

func shoot() -> void:
	var space_state := get_world_3d().direct_space_state
	var center_screen := get_viewport().get_visible_rect().size / 2
	
	var origin := project_ray_origin(center_screen)
	var end := origin + (project_ray_normal(center_screen) * MAX_RANGE)
	
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.collision_mask = 1
	
	var result := space_state.intersect_ray(query)
	var weapon_target := end
	if result:
		weapon_target = result.position
	if weapon:
		var weapon_begin = weapon.begin.global_position
		
		var weapon_query := PhysicsRayQueryParameters3D.create(weapon_begin, weapon_target)
		weapon_query.collision_mask = 1
		
		var weapon_result := space_state.intersect_ray(weapon_query)
		if weapon_result:
			var weapon_collider = weapon_result.collider
			var weapon_point = weapon_result.position
			var weapon_normal = weapon_result.normal
			
			DecalGlobal.apply_decal(weapon_point, weapon_normal, weapon_collider)
