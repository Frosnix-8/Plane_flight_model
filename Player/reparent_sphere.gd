extends Area3D

signal reparent(Guest : Node3D)

@onready var Player : Player_Default = get_node("../../")
@onready var GRay : ShapeCast3D = get_node("../GCheck")

var eligible : Node3D
@onready var Scope_timer : Timer = $Scopekeep
var current_guest : Node3D = self
var frame_count :int= 0

func _physics_process(_delta: float) -> void:
	frame_count += 1


	if frame_count % 5 != 0:
		return
	monitoring = true
	await get_tree().physics_frame
	GRay.force_shapecast_update()
	if current_guest and _is_grounded():
		Scope_timer.start()
		monitoring = false
		return
	
	var guest : Node3D = _find_best_guest()
	if guest:
		reparent.emit(guest)
		current_guest = guest
		
	monitoring = false
	
	
	
func _is_grounded() -> bool:
	for x in GRay.get_collision_count():
		if GRay.get_collider(x) == current_guest:
			return true
	return false
	
func _find_best_guest() -> Node3D:
	for body : Node3D in get_overlapping_bodies():
		if body == current_guest:# or !_is_reachable(body):
			continue
		return body
	return null
func _is_reachable(body : Node3D) -> bool:
	var ray := get_world_3d().direct_space_state
	var ray_hits := 0
	
	for offset in [Vector3.ZERO, Vector3.RIGHT * 0.3, Vector3.LEFT * 0.3]:
		var query := PhysicsRayQueryParameters3D.create(global_position, body.global_position + offset, 2,[Player.get_rid()])
		var result := ray.intersect_ray(query)
		if result.is_empty() or result.collider == current_guest:
			ray_hits += 1
		
	return ray_hits >= 2
