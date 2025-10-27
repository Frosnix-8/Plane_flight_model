extends RayCast3D
@export var scan_dist := 4
@onready var G1 := $GcheckRay2
@onready var G2 := $GcheckRay3
# Called when the node enters the scene tree for the first time.
func ground_check(dir: Vector3, target: Node3D) -> bool:
	target_position = (dir * scan_dist)
	G1.target_position = target_position
	G2.target_position = target_position
	if get_collider() == target or G1.get_collider() == target or G2.get_collider() == target:
		#print("Gcheck identified guest: Found ", get_collider(), ", ", G1.get_collider(), ", ", G2.get_collider(), " .")
		return true
	#print("Gcheck did not find guest. Found ", get_collider(), ", ", G1.get_collider(), ", ", G2.get_collider(), " instead.")
	return false
