extends Area3D

signal reparent(Guest : Node3D)

@onready var Player : Player_Default = get_node("../../")
@onready var GRay : RayCast3D = get_node("../GCheck")
@onready var Scope_timer : Timer = $Scopekeep
var former_guest : Node3D
var frame_count :int= 0

func _physics_process(_delta: float) -> void:
	frame_count += 1

	if frame_count % 15 != 0:
		return
	monitoring = true
	await get_tree().physics_frame
	var bodies := get_overlapping_bodies()
	if !bodies:
		return
	if GRay.get_collider() == former_guest:
		Scope_timer.start()
		return
	for x : Node3D in bodies: #System reparents to the first node it sees that isn't already reparented to.
		if x == former_guest:
			Scope_timer.start()
			continue
		
		if !has_line_of_sight(x):
			print("cannot reach recalibrate location, aborting...")
			return
		reparent.emit(x)
		former_guest = x
		break
	monitoring = false

func has_line_of_sight(target: Node3D) -> bool:
	var aabb := AABB()
	
	if target is VisualInstance3D:
		aabb = target.get_aabb()
	elif target is CollisionObject3D:
		for child in target.get_children():
			if child is CollisionShape3D:
				aabb = child.shape.get_debug_mesh().get_aabb()
				break
	
	if aabb.size == Vector3.ZERO:
		aabb = AABB(target.global_position - Vector3.ONE * 0.5, Vector3.ONE)
	
	var global_aabb := AABB(target.global_position + aabb.position, aabb.size)
	
	# Only 8 corners (no center)
	var corners := [
		global_aabb.position,
		global_aabb.position + Vector3(global_aabb.size.x, 0, 0),
		global_aabb.position + Vector3(0, global_aabb.size.y, 0),
		global_aabb.position + Vector3(0, 0, global_aabb.size.z),
		global_aabb.position + Vector3(global_aabb.size.x, global_aabb.size.y, 0),
		global_aabb.position + Vector3(global_aabb.size.x, 0, global_aabb.size.z),
		global_aabb.position + Vector3(0, global_aabb.size.y, global_aabb.size.z),
		global_aabb.end
	]
	
	# Find THE closest corner
	var closest_corner : Vector3
	var closest_dist := INF
	
	for corner in corners:
		var dist := global_position.distance_squared_to(corner)
		if dist < closest_dist:
			closest_dist = dist
			closest_corner = corner
	
	# Test only this one corner
	var space_state := get_world_3d().direct_space_state
	var query := PhysicsRayQueryParameters3D.create(global_position, closest_corner)
	query.collision_mask = 1
	query.exclude = [Player]
	
	var result := space_state.intersect_ray(query)
	return result.is_empty() or result.collider == target
