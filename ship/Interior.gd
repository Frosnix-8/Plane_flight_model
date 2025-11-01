extends AnimatableBody3D

##Distance at which point all children of node are disabled.

@export var LODistance :=  50.0
var is_disabled := false
var fcount := 0
#Parent info.
@onready var The_Captain: RigidBody3D = get_node("../ship")
##Whether the ship is being piloted.
var piloted := false
@onready var Pilot_Seat := $Seating
@onready var Pilot_cam := $Seating/Pilotcam
var Current_Pilot : CharacterBody3D
var Pilot_parent : Node3D
var pilot_tween : Tween


#reparenting
var is_target := false
var Child : Node3D
var previous_pos : Vector3
var previous_rot : Basis

##Ambience retrieved by player when they reparent to this region.
var ambience := load("res://ship/Audio/space ambience 3.ogg")
##Ambience volume retrieved by player when reparenting to this node.
var ambience_vol := 10

func _ready() -> void:
	previous_pos = The_Captain.global_position
	previous_rot = The_Captain.global_basis
	process_physics_priority = 1
func captain_announcement(Captain: RigidBody3D) -> void:
	The_Captain = Captain
	piloted = The_Captain.piloted
func _physics_process(delta: float) -> void:
	fcount += 1
	##minimizes lag when aligning with parent WHEN NOT FRAME OF REFERENCE.
	if !is_target or true:
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
		previous_rot = The_Captain.global_basis
		global_transform = The_Captain.global_transform
	###This is when the player is onboard.
	#else:
		#global_transform = The_Captain.global_transform
	#Your code here
	$deb.position = (The_Captain.linear_velocity * 0.01 + Vector3(4,0,0))
	
	if fcount % 15 == 0:
		section_activation()
	

func child_announcement(_Child: CharacterBody3D, _is_target = true):
	if !is_target:
		Child = null
	Child = _Child
	is_target = _is_target
	
##Disables all player related collisions and meshes for performance reasons only mesh and collision are currently supported.
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


func pilot_toggle(Pilot: CharacterBody3D, is_current_Pilot : bool = false) -> void:
	
	if piloted or is_current_Pilot:
		if pilot_tween:
			pilot_tween.kill()
		Current_Pilot.pilot_activation(true)
		The_Captain.pilot_activation(true)
		Current_Pilot.reparent(Pilot_parent, true)
		piloted = false
		The_Captain.piloted = false
		Current_Pilot.cam.make_current()
		Current_Pilot = null
	else:
		Current_Pilot = Pilot 
		piloted = true
		The_Captain.piloted = true
		Pilot.pilot_activation(false)
		The_Captain.pilot_activation(false)
		
		if pilot_tween:
			pilot_tween.kill()
		pilot_tween = create_tween()
		pilot_tween.tween_property(Pilot, "global_position", Pilot_Seat.global_position, 0.5)
		pilot_tween.parallel()
		pilot_tween.tween_property(Pilot, "global_rotation", global_rotation, 0.3)
		pilot_tween.parallel()
		pilot_tween.tween_property(Pilot.omnipivot, "rotation", Vector3.ZERO, 0.3)
		pilot_tween.parallel()
		pilot_tween.tween_property(Pilot.pivot, "rotation", Vector3.ZERO, 0.3)
		pilot_tween.tween_callback(func(): 
			#Pilot_cam.global_position = Pilot.cam.global_position
			Pilot_parent = Pilot.get_parent()
			Pilot.reparent(self, true) 
			Pilot_cam.make_current()
			Pilot_cam.rotation = Vector3(0,deg_to_rad(-90),0)
		)
		
