class_name Enemy
extends CharacterBody3D

var alert: bool = false
var detected: bool = false
var checking: bool = false
var is_wandering: bool = false
var target: Vector3
var move_speed: float = 3.0

@export var alert_innacuracy: float = 5.0
@export var deaggro_radius: float = 10.0

@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var wander_timer: Timer = $wander_timer
@onready var wait_timer: Timer = $wait_timer


func _physics_process(delta: float) -> void:
	handle_grav(delta)
	if not alert:
		wander_phys()
	else:
		if detected:
			detected_phys()
		else:
			alert_phys()
	move_and_slide()

func handle_grav(delta: float) -> void:
	if not is_on_floor():
		velocity += get_gravity() * delta

func wander_phys() -> void:
	if wait_timer.is_stopped():
		if nav_agent.is_navigation_finished() or wander_timer.is_stopped():
			if is_wandering:
				is_wandering = false
				wander_timer.stop()
				wait_timer.start()
			else:
				if wander_nav():
					is_wandering = true
	nav()

func wander_nav() -> bool:
	var map: RID = nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)).normalized()
	var target_pos := global_position + (dir * 10.0)
	var nav_pos := NavigationServer3D.map_get_closest_point(map, target_pos)
	nav_agent.target_position = nav_pos
	wander_timer.start()
	return true

func nav() -> void:
	if nav_agent.is_navigation_finished():
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		var next: Vector3 = nav_agent.get_next_path_position()
		var dir: Vector3 = next - global_position
		dir.y = 0.0
		if dir.length_squared() > 0.001:
			dir = dir.normalized()
			velocity.x = dir.x * move_speed
			velocity.z = dir.z * move_speed
			var target_angle := atan2(-dir.x, -dir.z)
			rotation.y = lerp_angle(rotation.y, target_angle, 10.0 * get_physics_process_delta_time())
		else:
			velocity.x = 0.0
			velocity.z = 0.0

func alert_phys() -> void:
	if not checking:
		if alert_nav():
			checking = true
	else:
		if nav_agent.is_navigation_finished():
			checking = false
			alert = false
			wait_timer.start()
	nav()

func alert_nav() -> bool:
	var map: RID = nav_agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		return false
	var innacuracy := Vector3(randf_range(-alert_innacuracy, alert_innacuracy), 0.0, randf_range(-alert_innacuracy, alert_innacuracy))
	var innacurate_target := target + innacuracy
	var nav_pos := NavigationServer3D.map_get_closest_point(map, innacurate_target)
	nav_agent.target_position = nav_pos
	return true

func detected_phys() -> void:
	var player: Player = Player.get_instance()
	if not is_instance_valid(player):
		detected = false
		alert = false
		return
	
	var distance: float = global_position.distance_to(player.global_position)
	if distance >= deaggro_radius:
		detected = false
		alert = false
		velocity.x = 0.0
		velocity.z = 0.0
		wait_timer.start()
	else:
		nav_agent.target_position = player.global_position
	nav()

func set_alert(pos: Vector3) -> void:
	alert = true
	is_wandering = false
	wander_timer.stop()
	wait_timer.stop()
	if global_position.distance_squared_to(pos) < 4.0:
		detected = true
		return
	else:
		target = pos
		checking = false

func set_detect() -> void:
	alert = true
	detected = true
	is_wandering = false
	wander_timer.stop()
	wait_timer.stop()

func hit() -> void:
	set_detect()
