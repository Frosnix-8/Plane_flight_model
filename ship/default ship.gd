extends RigidBody3D

signal Iamthecaptainnow(Captain: RigidBody3D)
##Speed multiplier per direction indicated. 
##NOTE: Purely relative: a multiplier of 1 means it will take 5 seconds to reach 100m/s
##(Assuming there is no damping applied, which is not intended to be implemented...)
@export var forward_Backward_speed_multiplier := Vector2(1,0.5)
@export var top_Bottom_speed_multiplier := Vector2(1,1)
@export var left_Right_speed_multiplier := Vector2(1,1)
##The usual max speed of the ship. I'm mixed between making ships go ludicrously fast or not.
@export var max_regular_speed : float = 600
##The max atmospheric speed.
@export var max_atmospheric_speed : float = 400
##The absolute highest the ship can achieve at any given moment.
@export var max_speed : float = 1200
##At this speed, lift force allows the ship to not use its vertical thrusters in atmospheric environments.
@export var max_lift_speed : float = 150.0
##Defines how strong thrusters are globally. This allows speed to be independent of mass.
const GLOBAL_STRENGTH_MULTIPLIER := 100.0/5.0

##NOTE: I don't know how inertia works so away it goes for now.
#@export var Per_axis_rotation_inertia := Vector3()

##FLIGHT VARIABLES
var thrust_gravity_offset : Vector3
@export var flight_assist_enabled := false
@export var in_atmosphere := false

var Exterior : Node3D
var Interior : Node3D
@onready var Capcap = get_parent()
@onready var proc_audio = $TMP_Audio

var is_target := false
var piloted := false
var Child: CharacterBody3D
var Child_World : Node3D
var prev_pos : Vector3

var frametime := 0
# Called when the node enters the scene tree for the first time.
func _ready() -> void:
	process_priority = 0
	Iamthecaptainnow.emit(self)

	
func _physics_process(delta: float) -> void:
	#print(linear_velocity.length())

	frametime += 1
	if !piloted:
		return
	#since flight assist checks current velocity, it's a good idea to put the gravity compensation before
	apply_central_force(thrust_gravity_offset * clamp(linear_velocity.length()/max_lift_speed, 0, 1))
	var direction := Vector3(Input.get_axis("fly back","fly forward"),
		Input.get_axis("fly down","fly up"),
		Input.get_axis("fly left", "fly right"))
		
	var rotation_torque : Vector3 = keyed_rotation()
	

	if flight_assist_enabled:
		var flight_assist := thrust_flight_assist()
		for x in range(3):
			if !direction[x]:
				direction[x] += flight_assist[x]
		#TODO: add angular flight assist
	
	var velocity := basis * Vector3(
		clamp(direction.x * 10, -forward_Backward_speed_multiplier.y,forward_Backward_speed_multiplier.x),
		clamp(direction.y * 10, -top_Bottom_speed_multiplier.y, top_Bottom_speed_multiplier.x * 
		clamp(abs((basis * linear_velocity).x/max_lift_speed * int(in_atmosphere) + 1.0),0,3)),
		clamp(direction.z * 10, -left_Right_speed_multiplier.y,left_Right_speed_multiplier.x)
	)
	apply_central_force(velocity * mass * GLOBAL_STRENGTH_MULTIPLIER)
	apply_torque(basis* rotation_torque)
	if frametime % 60 == 0:
		call_deferred("calculate_gravity_offset", delta)
	#print("lift strength is at: ", clamp(linear_velocity.length()/max_lift_speed, 0, 1) * 100, "%")
	
	
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_target:
		
		# Move world based on velocity
		Child_World.global_position -= state.linear_velocity * state.step

		state.transform.origin = prev_pos
	
	clamp(state.linear_velocity, -Vector3.ONE * max_speed, Vector3.ONE * max_speed)
	
	for x : AnimatableBody3D in [Interior, Exterior]:
		x.transform = state.transform
	TEMP_audio()
	
	#TODO: Implement atmospheric flight system.
	
func keyed_rotation() -> Vector3:
	var target_rotation := Input.get_vector("pitch up", "pitch down", "yaw left", "yaw right")
	var rolltation := Input.get_axis("roll left","roll right")
	if !target_rotation and !rolltation:
	
		return Vector3.ZERO
	inertia = PhysicsServer3D.body_get_direct_state(get_rid()).inverse_inertia.inverse()
	# Apply torque directly (rotational force)
	var torque = Vector3(
		rolltation * inertia.x,
		-target_rotation.y * inertia.y,
		target_rotation.x * inertia.z
	)
	return torque
	
#TODO: add mouse based rotation

func child_call(_Child: CharacterBody3D, _is_target: bool, World: Node3D) -> void:
	if _is_target:
		prev_pos = global_position
		is_target = true
		Child = _Child
		Child_World = World
		
		top_level = true
		Interior.top_level = true
		Exterior.top_level = true

	else:
		is_target = false
		top_level = false
		Interior.top_level = false
		Exterior.top_level = false
		
func calculate_gravity_offset(_delta: float) -> void:
	##NOTE: removed delta
	thrust_gravity_offset = mass * -get_gravity()

func rotation_flight_assist():
	pass

func thrust_flight_assist() -> Vector3:
	var corrected_linear_velocity : Vector3= basis.inverse()*linear_velocity
	#print("flight assist axial correction moves by" , Vector3(0,clamp(-corrected_linear_velocity.y, -1,1),clamp(-corrected_linear_velocity.z, -1,1)))
	return Vector3(clamp(-corrected_linear_velocity.x, -1,1),clamp(-corrected_linear_velocity.y, -1,1),clamp(-corrected_linear_velocity.z, -1,1))
	
func _on_interior_pilot_activation(is_disabling: bool) -> void:
	if !is_disabling:
		set_physics_process(true)
		set_process_unhandled_input(true)
		set_process_input(true)
		print("activated rigidbody flight mode")
		#gravity_scale = 0
	if is_disabling:
		#gravity_scale = 1
		set_process_unhandled_input(false)
		set_process_input(false)
		print("deactivated rigidbody flight mode")

func _on_interior_declaration(declared: AnimatableBody3D) -> void:
	Interior = declared
	#print("assigned interior")

func _on_exterior_declaration(declared: AnimatableBody3D) -> void:
	
	Exterior = declared
	#print("assigned exterior")
	
var frequ : float
var phase := 0.0
func TEMP_audio():
	frequ = linear_velocity.length() * 2
	var playback: AudioStreamGeneratorPlayback = proc_audio.get_stream_playback()
	
	# Fill available frames
	var frames_available = playback.get_frames_available()
	
	for i in range(frames_available):
		# Generate sine value between -1 and 1
		var sample = sin(phase * TAU)
		
		# Push stereo frame (same value for both channels)
		playback.push_frame(Vector2(sample, sample))
		
		# Advance phase
		phase += frequ / 44100.0
		
		# Keep phase in 0-1 range to avoid precision issues
		if phase >= 1.0:
			phase -= 1.0
