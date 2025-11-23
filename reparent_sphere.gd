extends Area3D

@onready var Player : Player_Default = get_node("../../")

var former_guest : Node3D
var frame_count :int= 0

func _physics_process(delta: float) -> void:
	frame_count += 1

	if frame_count % 15 != 0:
		return
	monitoring = true
	await get_tree().physics_frame
	
	monitoring = false
