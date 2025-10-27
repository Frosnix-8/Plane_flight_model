extends AnimatableBody3D

signal declaration(declared: AnimatableBody3D)
##Distance at which point all children of node are disabled.
@export var LODistance :=  50.0

var The_Captain: RigidBody3D
var is_disabled := false
var ambience := load("res://ship/Audio/space ambience 3.ogg")
var ambience_vol := -10.5
var previous_pos : Vector3
var previous_rot : Basis
func _ready() -> void:
	process_physics_priority = 1
	declaration.emit(self)
	previous_pos = The_Captain.global_position
	previous_rot = The_Captain.global_basis
func Captain_announcement(Captain: RigidBody3D) -> void:
	The_Captain = Captain
func _physics_process(delta: float) -> void:
	
	#global_transform = The_Captain.global_transform
	var velocity := (The_Captain.global_position - previous_pos)/delta
	var intertia_rot := previous_rot.get_rotation_quaternion().inverse() * The_Captain.global_basis.get_rotation_quaternion()
	var target_rotation := intertia_rot.get_axis() * intertia_rot.get_angle() / delta
	
	global_position = The_Captain.global_position + velocity * delta
	previous_pos = The_Captain.global_position
	

	var forward_angle := target_rotation.length() * delta
	if forward_angle >= 0.001:
		global_basis = Basis(target_rotation.normalized(), forward_angle) * The_Captain.global_basis
	else:
		global_basis = The_Captain.global_basis
	global_transform = The_Captain.global_transform
	previous_rot = The_Captain.global_basis
	
	#global_position = The_Captain.global_position + (The_Captain.linear_velocity * delta)

##Disables all player related collisions and meshes for performance reasons. Currently only possible for mesh and collision.
func section_activation(force: bool = false, force_disable:= false):
	if (global_position.length() >= LODistance and !is_disabled) or (force and force_disable):
		for x in get_children():
			if x is MeshInstance3D:
				x.visible = false
			elif x is CollisionShape3D:
				x.disabled = true
		is_disabled = true
		print("disabled for performance")
	elif (global_position.length() < LODistance and is_disabled) or (force and !force_disable):
		for x in get_children():
			if x is MeshInstance3D:
				x.visible = true
			elif x is CollisionShape3D:
				x.disabled = false
		is_disabled = false
		print("reenabled for performance")

func child_announcement(_Child: CharacterBody3D, _is_target = true):
	pass
	#print("child is ", _Child.name)
