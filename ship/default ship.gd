extends RigidBody3D

signal Iamthecaptainnow(Captain: RigidBody3D)
##Speed multiplier per direction indicated. 
##NOTE: Purely relative: a multiplier of 1 means it will take 5 seconds to reach 100m/s
##(Assuming there is no damping applied, which is not intended to be implemented...)
@export var forward_Backward_speed_multiplier := Vector2(1.3,0.8)
@export var top_Bottom_speed_multiplier := Vector2(1,1)
@export var left_Right_speed_multiplier := Vector2(0.7,0.7)
##For convenience holds the biggest values of the three above.
var xyz_multiplier_length_array : Array
##The usual max speed of the ship. I'm mixed between making ships go ludicrously fast or not.
@export var max_regular_speed : float = 600
##The max atmospheric speed.
@export var max_atmospheric_speed : float = 300
##The absolute highest the ship can achieve at any given moment.
@export var max_speed : float = 1200
##At this speed, lift force allows the ship to not use its vertical thrusters in atmospheric environments.
@export var max_lift_speed : float = 150.0
##Defines how strong thrusters are globally. This allows speed to be independent of mass.
const GLOBAL_STRENGTH_MULTIPLIER := 100.0/4.0
const G_FORCE := 9.8
##NOTE: I don't know how inertia works so away it goes for now.
#@export var Per_axis_rotation_inertia := Vector3()

##FLIGHT VARIABLES
var thrust_gravity_offset : Vector3
@export var flight_assist_enabled := false
@export var in_atmosphere := false
var boost := false
##Time, in seconds, that the ship can safely boost for.
@export var boost_time : float = 10
##Time, in seconds, that the ship needs to fully recharge the boost.
@export var boost_cooldown : float = 12
##Speed multiplier for the boost per axis. NOTE: boost mechanic is currently as follows: for as long as the boost button is applied,
##max speed and acceleration, maybe rotation too are amplified.
@export var boost_multiplier : Vector3 = Vector3(2.0, 2.4, 2.0)
@export var atmos_boost_speed_multiplier : float = 1.8
##experimental: boost torque multiplier. 
@export var boost_torque_multiplier := Vector3.ONE * 1.5
##The current speed. based off a calculation of whether boosting, in atmosphere....
var speed_limit := 100.0

var previous_velocity := Vector3.ZERO
var G_forces := Vector3.ZERO


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
	for x : Vector2 in [forward_Backward_speed_multiplier, top_Bottom_speed_multiplier, left_Right_speed_multiplier]:
		xyz_multiplier_length_array.append(x.length())
	
func _physics_process(delta: float) -> void:
	#print(linear_velocity.length())
	
	apply_central_force(thrust_gravity_offset * clamp(linear_velocity.length()/max_lift_speed, 0, 1))
	frametime += 1
	if !piloted:
		linear_damp = 0.2
		return
	linear_damp = 0.0
	#since flight assist checks current velocity, it's a good idea to put the gravity compensation before
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
	
	if linear_velocity.length() >= speed_limit:
		var opposite_dir : Vector3i = round((basis.inverse() * linear_velocity).normalized())
		#print(opposite_dir)
		for x in range(3):
			if direction[x]:
				direction[x] -= opposite_dir[x] * 1.3
				#print(opposite_dir[x] * 1.3)
			else:
				direction[x] -= opposite_dir[x] * 2
				#print(opposite_dir[x] * 2)
	var velocity : Vector3
	if !boost:
		velocity = basis * Vector3(
			clamp(direction.x * 10, -forward_Backward_speed_multiplier.y,forward_Backward_speed_multiplier.x),
			clamp(direction.y * 10, -top_Bottom_speed_multiplier.y, top_Bottom_speed_multiplier.x),
			clamp(direction.z * 10, -left_Right_speed_multiplier.y,left_Right_speed_multiplier.x)
		)
	else:
		velocity = basis * (Vector3(
			clamp(direction.x * 10, -forward_Backward_speed_multiplier.y,forward_Backward_speed_multiplier.x),
			clamp(direction.y * 10, -top_Bottom_speed_multiplier.y, top_Bottom_speed_multiplier.x),
			clamp(direction.z * 10, -left_Right_speed_multiplier.y,left_Right_speed_multiplier.x)
		) * boost_multiplier)

	apply_central_force(velocity * mass * GLOBAL_STRENGTH_MULTIPLIER)
	apply_torque(basis* rotation_torque)
	if frametime % 3 == 0:
		call_deferred("calculate_max_speed")
		call_deferred("calculate_gravity_offset", delta)
		print(G_forces.y)
	#print("lift strength is at: ", clamp(linear_velocity.length()/max_lift_speed, 0, 1) * 100, "%")
	calculate_g_force(delta)
	
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_target:
		
		# Move world based on velocity
		Child_World.global_position -= state.linear_velocity * state.step
		state.transform.origin = prev_pos
	for x : AnimatableBody3D in [Interior, Exterior]:
		x.transform = state.transform
	TEMP_audio()
	
	#TODO: Implement atmospheric flight system.
	
##Calculates torque for each axis based off key input. for simplicity relative torque is identical on each axis: each axis rotates at the same speed.
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



func calculate_gravity_offset(_delta: float) -> void:
	##NOTE: removed delta
	thrust_gravity_offset = mass * -get_gravity()

##Calculates max speed based off all possible conditions mentioned earlier.
func calculate_max_speed() -> void:
	
	var _boost_multiplier := int(boost) * atmos_boost_speed_multiplier + int(!boost)
	if in_atmosphere:
		speed_limit= max_atmospheric_speed * _boost_multiplier
	elif !in_atmosphere and !boost:
		speed_limit= max_regular_speed
	else:
		speed_limit = max_speed

func calculate_g_force(delta: float):
	var acceleration :Vector3 = (linear_velocity - previous_velocity) / delta
	G_forces = lerp(G_forces, basis * (acceleration / G_FORCE), 0.1)
	previous_velocity = linear_velocity
	
func rotation_flight_assist():
	pass

func thrust_flight_assist() -> Vector3:
	var corrected_linear_velocity : Vector3= basis.inverse()*linear_velocity
	#print("flight assist axial correction moves by" , Vector3(0,clamp(-corrected_linear_velocity.y, -1,1),clamp(-corrected_linear_velocity.z, -1,1)))
	return Vector3(clamp(-corrected_linear_velocity.x, -1,1),clamp(-corrected_linear_velocity.y, -1,1),clamp(-corrected_linear_velocity.z, -1,1))



func _input(event: InputEvent) -> void:
	if Input.is_action_pressed("ship boost"):
		boost = true
	else:
		boost = false
	if Input.is_action_just_pressed("flight assist toggle"):
		flight_assist_enabled = !flight_assist_enabled
		if flight_assist_enabled:
			print("flight assist on.")
		else:
			print("flight assist off.")
		

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
	
##Called by the player.
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
		
var frequ : float
var phase := 0.0
func TEMP_audio():
	frequ = linear_velocity.length() * 2
	var playback: AudioStreamGeneratorPlayback = proc_audio.get_stream_playback()
	
	# Fill available frames
	var frames_available = playback.get_frames_available()
	
	for i in range(frames_available):
		# Generate sine value between -1 and 1
		var sample : float
		if !boost:
			sample = sin(phase * TAU)
		else:
			sample = sin(phase* TAU) + sin(phase * TAU /2) + sin(phase * TAU /2 + 0.5) / 2
		
		# Push stereo frame (same value for both channels)
		playback.push_frame(Vector2(sample, sample))
		
		# Advance phase
		phase += frequ / 44100.0
		
		# Keep phase in 0-1 range to avoid precision issues
		if phase >= 1.0:
			phase -= 1.0
