extends Node3D

signal reparent(guest : Node3D)

@onready var horicasts := [$Horicast3,$Horicast4,$Horicast5,$Horicast6]
@onready var verticasts := [$Verticast,$Verticast2]
@onready var GCast := $Verticast
@onready var GCheck := $GCheck
var last_parent : Node3D = self #To prevent null from bugging if the player starts in a void

func _physics_process(_delta: float) -> void:

	for x in GCast.get_collision_count():
		if GCast.get_collider(x) == last_parent:
			return
	if _shapecast_check(verticasts):
		return
	
	
	_shapecast_check(horicasts)
	
	

func _shapecast_check(rays : Array) -> bool:
	for Ray : ShapeCast3D in rays:
		var Count := Ray.get_collision_count()
		for x in Count:
			if Ray.get_collider(x) == last_parent:
				continue
			reparent.emit(Ray.get_collider(x))
			#print("reparented to ", Ray.get_collider(x))
			last_parent = Ray.get_collider(x)
			return true
	
	return false
