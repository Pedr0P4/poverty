extends Camera3D

const MAX_RANGE: float = 2000.0

@onready var camera: Camera3D = $"."

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if Input.is_action_just_pressed("fire"):
			shoot()

func shoot() -> void:
	var space_state := get_world_3d().direct_space_state
	var center_screen := get_viewport().get_visible_rect().size / 2
	
	var origin := camera.project_ray_origin(center_screen)
	var end := origin + (camera.project_ray_normal(center_screen) * MAX_RANGE)
	
	var query := PhysicsRayQueryParameters3D.create(origin, end)
	query.exclude = [self]
	query.collision_mask = 1
	
	var result := space_state.intersect_ray(query)
	if result:
		var target = result.collider
		if target.has_method("hit"):
			target.hit();
		else:
			print("Bati em algo sem hit")
	else:
		print("Nada")
