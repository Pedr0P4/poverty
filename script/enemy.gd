extends CharacterBody3D

var alert: bool = false
var detected: bool = false
var checking: bool = false
var target: Vector3
var move_speed: float = 3
@export var alert_innacuracy: float = 5
@export var deaggro_radius: float = 10
@onready var nav_agent: NavigationAgent3D = $NavigationAgent3D
@onready var wander_timer: Timer = $wander_timer
@onready var wait_timer: Timer = $wait_timer


func _physics_process(delta: float) -> void:
	handle_grav(delta)
	if (!alert):
		wander_nav()
	else:
		if (detected):
			detected_phys()
		else:
			alert_phys()

func handle_grav(delta: float) -> void:
	if (!is_on_floor()):
		velocity += get_gravity()*delta
		
		
func wander_phys() -> void:
	if (wait_timer.is_stopped() && (nav_agent.is_navigation_finished() || wander_timer.is_stopped())):
		wander_nav()
	nav()

func wander_nav() -> void:
	var map: RID = nav_agent.get_navigation_map()
	if (NavigationServer3D.map_get_iteration_id(map)) == 0: return;
	wander_timer.start()
	var dir: Vector3 = Vector3(randf_range(-1,1),0,randf_range(-1,1)).normalized()
	var target_pos: Vector3 = global_position + (dir*10)
	var nav_pos: Vector3 = NavigationServer3D.map_get_closest_point(map, target_pos)
	nav_agent.target_position = nav_pos
	wander_timer.start()

func nav() -> void:
	if (nav_agent.is_navigation_finished()):
		velocity *= Vector3.UP #zerando x e z de uma vez só
	else:
		var next: Vector3 = nav_agent.get_next_path_position()
		var dir: Vector3 = next - global_position
		if (dir.length_squared() > 0.001):
			dir = dir.normalized()
			velocity = dir*move_speed
		else:
			velocity *= Vector3.UP

func alert_phys() -> void:
	if (!checking):
		checking = true
		alert_nav()
	else:
		if (nav_agent.is_navigation_finished()):
			checking = false
			alert = false
			wait_timer.start()
	nav()

func alert_nav() -> void:
	var map: RID = nav_agent.get_navigation_map()
	if (NavigationServer3D.map_get_iteration_id(map)) == 0: return;
	var innacuracy: Vector3 = Vector3(randf_range(-alert_innacuracy,alert_innacuracy),0,randf_range(-alert_innacuracy,alert_innacuracy))
	var innacurate_target: Vector3 = target + innacuracy
	var nav_pos: Vector3 = NavigationServer3D.map_get_closest_point(map, innacurate_target)
	nav_agent.target_position = nav_pos
	
func detected_phys() -> void:
	var player: Player = Player.get_instance()
	var distance: float = global_position.distance_to(player.global_position)
	if (distance >= deaggro_radius):
		detected = false
		alert = false
		wait_timer.start()
	else:
		nav_agent.target_position = player.global_position
	nav()

func set_alert(pos: Vector3) -> void:
	alert = true
	if global_position.distance_squared_to(pos) < 4:
		detected = true
		return
	else:
		target = pos

func set_detect() -> void:
	detected = true
