extends RigidBody3D

##Speed multiplier per direction indicated. 
##NOTE: Purely relative: a multiplier of 1 means it will take 5 seconds to reach 100m/s
##(Assuming there is no damping applied, which is not intended to be implemented...)
@export var forward_Backward_speed_multiplier := Vector2(1.3,0.8)
@export var top_Bottom_speed_multiplier := Vector2(1,1)
@export var left_Right_speed_multiplier := Vector2(0.7,0.7)

##max angular speed in degrees through regular torque application; 
@export var max_degree_axial_speed := Vector3(90,200,50)
##max axial speed in radians.
var max_axial_speed : Vector3
##Unlike max axial speed in voids, the actual limit varies on speed. NOTE: Currently implementing drag.
@export var max_degree_atmospheric_axial_speed := Vector3.ZERO
##atmospheric axial speed limit in radians.
var max_atmospheric_axial_speed : Vector3
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
const G_CONSTANT := 6.6743

@export var flight_assist_enabled := false
@export var in_atmosphere := false
##Drag coefficient of ship at 1 atmosphere.
@export var atmospheric_drag := 0.1
#NOTE: I don't know how inertia works so away it goes for now.
#@export var Per_axis_rotation_inertia := Vector3()

#FLIGHT VARIABLES

var thrust_gravity_offset : Vector3

var boost := false
##Time, in seconds, that the ship can safely boost for.
@export var boost_time : float = 10
##Time, in seconds, that the ship needs to fully recharge the boost.
@export var boost_cooldown : float = 12
##Accel multiplier for the boost per axis. NOTE: boost mechanic is currently as follows: for as long as the boost button is applied,
##max speed and acceleration, maybe rotation too are amplified.
@export var boost_multiplier : Vector3 = Vector3(2.0, 2.4, 2.0)
##Speed multiplier for in-atmosphere boost... NOTE: might change.
@export var atmos_boost_speed_multiplier : float = 1.8
##experimental: boost torque multiplier. 
@export var boost_torque_multiplier := Vector3.ONE * 1.5
##The current speed. based off a calculation of whether boosting, in atmosphere....
var speed_limit := 100.0

##Mouse controls

var mouse_relative_position := Vector2.ZERO
##Max distance in pixels from center screen that the flight cursor can be moved to reach max steer.
var current_max_mouse_distance := 0.5 
##Received from the player when piloting, 0 is pitch, 1 is roll, 2 is yaw. Magic numbers because idk how to transfer enums.
var current_prefered_non_mouse_axe : int
var current_mouse_deadzone : float
var current_flight_mouse_sensitivity : float
var current_is_relative_mouse : float
##GFORCE
var previous_velocity := Vector3.ZERO
var G_forces := Vector3.ZERO
var previous_G_forces : PackedVector3Array = [Vector3.ZERO, Vector3.ZERO]

@onready var audiothread := Thread.new()
@onready var audiomut := Mutex.new()

@onready var Exterior : Node3D = get_node("../exterior")
@onready var Interior : Node3D = get_node("../interior")
@onready var Capcap = get_parent()
@onready var proc_audio = $TMP_Audio

var is_target := false
var piloted := false
var Child: CharacterBody3D
var Child_World : Node3D
var prev_pos : Vector3
var queued_direction := Vector3.ZERO
var queued_rotation := Vector3.ZERO
var input_queued := false

var frametime := 0
# Called when the node enters the scene tree for the first time.

func _ready() -> void:
	
	
	audiothread.start(TEMP_audio,Thread.PRIORITY_NORMAL)
	process_priority = 4

	for x : int in range(3):
		max_axial_speed[x] = deg_to_rad(max_degree_axial_speed[x])
		max_atmospheric_axial_speed[x] = deg_to_rad(max_degree_atmospheric_axial_speed[x])
	for x : Vector2 in [forward_Backward_speed_multiplier, top_Bottom_speed_multiplier, left_Right_speed_multiplier]:
		xyz_multiplier_length_array.append(x.length())

func _physics_process(delta: float) -> void:
	
	#print("Piloting: ", self.name, " | Interior.Current_Pilot = ", Interior.Current_Pilot)a
	
	apply_central_force(thrust_gravity_offset * clamp((basis.inverse() * linear_velocity).x/max_lift_speed, 0, 1) * int(in_atmosphere))
	
	frametime += 1
	#print(Interior.Current_Pilot, " ",self)
	if piloted:
		linear_damp = 0.0
		
		#print(direction)
		var rotation_torque : Vector3 = calculate_ship_rotation()
		rotation_flight_assist()
		
		calculate_g_force(delta)
		apply_torque(basis* rotation_torque)
		

		calculate_linear_velocity()
		if frametime % 3 == 0:
			call_deferred("calculate_max_speed")
			call_deferred("calculate_gravity_offset", delta)
			
		#print("lift strength is at: ", clamp(linear_velocity.length()/max_lift_speed, 0, 1) * 100, "%")
	else:
		linear_damp = 0.2
		return
	
	previous_velocity = linear_velocity
	flight_mouse_depreciation(delta)
		
func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if is_target:
		
		# Move world based on velocity
		Child_World.global_position -= state.linear_velocity * state.step
		state.transform.origin = prev_pos
	#for x : AnimatableBody3D in [Interior, Exterior]:
		#x.transform = state.transform
	
	
	#TODO: Implement atmospheric flight system.
	

	
#TODO: add mouse based rotation


##Calculates how much force is required to fully negate gravity.
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

##Calculates "drag", as in how fast the ship will shed velocity. NOTE: this is not direction dependent.
func calculate_drag() -> float:
	
	return 0.0

##Computes g_forces based off the ship's current velocity (TODO and gravity? I forgot.)
func calculate_g_force(delta: float):
	
	var acceleration :Vector3 = (linear_velocity - previous_velocity) / delta
	for x in previous_G_forces.size() - 1:
		previous_G_forces[x] = previous_G_forces[x+1]
	previous_G_forces[previous_G_forces.size() -1] = G_forces
	G_forces = basis * (acceleration / G_FORCE)
	if frametime % 5 == 0:
		var av : float = 0
		for x in previous_G_forces:
			av += x.length()
		av += G_forces.length()
		#print(av / (previous_G_forces.size() + 1))
	
	
##Calculate linear acceleration based off of input and other factors.
func calculate_linear_velocity():
	var direction := Vector3(Input.get_axis("fly back","fly forward"),
		Input.get_axis("fly down","fly up"),
		Input.get_axis("fly left", "fly right"))

		#TODO: add angular flight assist
	
	if linear_velocity.length() >= speed_limit:
		var opposite_dir : Vector3i = round((basis.inverse() * linear_velocity).normalized())
		for x in range(3):
			if direction[x]:
				direction[x] -= opposite_dir[x] * 1.01
				#print(opposite_dir[x] * 1.3)
			else:
				direction[x] -= opposite_dir[x] * 2
				#print(opposite_dir[x] * 2)
	var velocity : Vector3
	if !boost:
		velocity = Vector3(
			clamp(direction.x * 10, -forward_Backward_speed_multiplier.y,forward_Backward_speed_multiplier.x),
			clamp(direction.y * 10, -top_Bottom_speed_multiplier.y, top_Bottom_speed_multiplier.x),
			clamp(direction.z * 10, -left_Right_speed_multiplier.y,left_Right_speed_multiplier.x)
		)
	else:
		velocity =(Vector3(
			clamp(direction.x * 10, -forward_Backward_speed_multiplier.y,forward_Backward_speed_multiplier.x),
			clamp(direction.y * 10, -top_Bottom_speed_multiplier.y, top_Bottom_speed_multiplier.x),
			clamp(direction.z * 10, -left_Right_speed_multiplier.y,left_Right_speed_multiplier.x)
		) * boost_multiplier)
	var final_velocity : Vector3 = velocity * mass* GLOBAL_STRENGTH_MULTIPLIER
	if flight_assist_enabled:
		var flight_assist := thrust_flight_assist()
		
		for x in range(3):
			if !direction[x]:
				final_velocity[x] = flight_assist[x] * (boost_multiplier[x] * int(boost) + int(!boost))
		if in_atmosphere :
			# Convert gravity to local space
			var local_gravity := basis.inverse() * get_gravity()
			var gravity_compensation := Vector3.ZERO
			for x in range(3):
				if local_gravity[x] != 0 and !(direction[x] * local_gravity[x]) < 0:
					# Force needed to cancel gravity on this axis
					var anti_grav = -local_gravity[x] * mass
					
					# Clamp by thruster limits for this axis
					var max_thruster_force : float
					match x:
						0: max_thruster_force = mass * GLOBAL_STRENGTH_MULTIPLIER * max(forward_Backward_speed_multiplier.x, forward_Backward_speed_multiplier.y)
						1: max_thruster_force = mass * GLOBAL_STRENGTH_MULTIPLIER * max(top_Bottom_speed_multiplier.x, top_Bottom_speed_multiplier.y)
						2: max_thruster_force = mass * GLOBAL_STRENGTH_MULTIPLIER * max(left_Right_speed_multiplier.x, left_Right_speed_multiplier.y)
			
					gravity_compensation[x] = clamp(anti_grav, -max_thruster_force, max_thruster_force)
		# Add to final velocity (convert back to global)
			final_velocity += gravity_compensation * clamp(1 - (basis.inverse() * linear_velocity).x/max_lift_speed, 0, 1)
	#print(final_velocity)
	apply_central_force(basis * final_velocity)
	#print(basis.inverse() * linear_velocity)

##Calculates torque for each axis based off key input. for simplicity relative torque is identical on each axis: each axis rotates at the same speed.
func calculate_ship_rotation() -> Vector3:
	inertia = PhysicsServer3D.body_get_direct_state(get_rid()).inverse_inertia.inverse()
	var corrected_angular := basis.inverse() * angular_velocity
	#separated roll because I forgot and i'm too lazy.
	var target_rotation := Vector2.ZERO
	var rolltation := 0.0
	var torque :=  Vector3.ZERO
	var normalized_mouse_position : Vector2 = mouse_relative_position / current_max_mouse_distance
	#print(normalized_mouse_position.length())
	
	if (normalized_mouse_position.length() > current_mouse_deadzone):
		match current_prefered_non_mouse_axe:
			#0 exists just in case.
			0:
				target_rotation.y = normalized_mouse_position.x
				rolltation = normalized_mouse_position.y
			1:
				target_rotation.x = -normalized_mouse_position.y
				target_rotation.y = normalized_mouse_position.x
			2: 
				target_rotation.x = -normalized_mouse_position.y
				rolltation = normalized_mouse_position.x
	
	target_rotation = clamp(target_rotation + Input.get_vector("pitch up", "pitch down", "yaw left", "yaw right"), -Vector2.ONE, Vector2.ONE)
	rolltation = clamp(rolltation + Input.get_axis("roll left","roll right"), -1.0, 1.0)
	
	
	if !target_rotation and !rolltation:
			pass
	elif !flight_assist_enabled:
		
		
		# Apply torque directly (rotational force)
		torque = Vector3(
			rolltation * inertia.x * int(abs(corrected_angular.x) < max_axial_speed.x or sign(corrected_angular.x) != sign(rolltation)),
			-target_rotation.y * inertia.y * int(abs(corrected_angular.y) < max_axial_speed.y or sign(corrected_angular.y) != sign(-target_rotation.y)),
			target_rotation.x * inertia.z * int(abs(corrected_angular.z) < max_axial_speed.z or sign(corrected_angular.z) != sign(target_rotation.x))
			)
	
	else:
		var rot_input : Array = [rolltation, -target_rotation.y, target_rotation.x]
		for x:int in range(3):
			#1: if going in opposite direction of current rotation, put all force to change direction. otherwise limit based off input distance.

			if sign(corrected_angular[x]) != sign(rot_input[x]):
				torque[x] = -sign(corrected_angular[x]) * inertia[x]
			elif abs(corrected_angular[x]) < max_axial_speed[x] * abs(rot_input[x]):
				torque[x] = rot_input[x] * inertia[x]
			else:
				torque[x] = 0
		
		
		
		
		var axial_flight_assist := rotation_flight_assist()
		for x in range(3):
			if torque[x] == 0:
				torque[x] = axial_flight_assist[x] * inertia[x]

	
	return torque
	
##Calculates axial flight assist required to stop all transient rotations.
func rotation_flight_assist() -> Vector3:
	var angular_normalized: Vector3 = basis.inverse() * (angular_velocity) * inertia * 0.0001
	var possible_correction : Vector3
	for x in range(3):
		possible_correction[x] = clamp(-angular_normalized[x], -1 , 1)
	return possible_correction
	
##Calculates linear flight assist variables to return to target movement speed while removing lateral velocity. NOTE: target speed not implemented.
##flight assist will for now, only set the player back to standstill.
func thrust_flight_assist() -> Vector3:
	var corrected_linear_velocity : Vector3= basis.inverse() * (linear_velocity) * mass

	var possible_correction : Vector3
	possible_correction.x = clamp(corrected_linear_velocity.x, -mass*GLOBAL_STRENGTH_MULTIPLIER*forward_Backward_speed_multiplier.y,
	mass*GLOBAL_STRENGTH_MULTIPLIER*forward_Backward_speed_multiplier.x)
	possible_correction.y = clamp(corrected_linear_velocity.y, -mass*GLOBAL_STRENGTH_MULTIPLIER*top_Bottom_speed_multiplier.y,
	mass*GLOBAL_STRENGTH_MULTIPLIER*top_Bottom_speed_multiplier.x)
	possible_correction.z = clamp(corrected_linear_velocity.z, -mass*GLOBAL_STRENGTH_MULTIPLIER*left_Right_speed_multiplier.y,
	mass*GLOBAL_STRENGTH_MULTIPLIER*left_Right_speed_multiplier.x)
	
	#print(-possible_correction)
	return -possible_correction

func _input(_event: InputEvent) -> void:
	if !piloted:
		return
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
		
func _unhandled_input(event: InputEvent) -> void:
	if !piloted:
		return
	elif Interior.Current_Pilot.is_in_context_menu:
		return
	if event is InputEventMouseMotion:
		#since the mouse isn't always in the center when playing, I opted for a virtual mouse instead.
		mouse_relative_position += event.relative / 500
		if mouse_relative_position.length() > current_max_mouse_distance:
			mouse_relative_position = mouse_relative_position.normalized() * current_max_mouse_distance
		#print(mouse_relative_position)

##sheds mouse position to slowly push the cursor towards the center at speeds set by the pilot.
func flight_mouse_depreciation(delta: float):
	if current_is_relative_mouse == 0.0:
		return
	var reduction := current_max_mouse_distance * current_is_relative_mouse * delta
	
	if mouse_relative_position.length() < reduction:
		mouse_relative_position = Vector2.ZERO
	else:
		mouse_relative_position -= mouse_relative_position.normalized() * reduction
		


##Activates pilot and (re)assigns player specific settings.
func pilot_activation(is_disabling: bool) -> void:
	reset_mouse()
	#or just if is activating.
	if !is_disabling:
		set_process_unhandled_input(true)
		set_process_input(true)
		current_prefered_non_mouse_axe = Interior.Current_Pilot.prefered_non_mouse_axe
		current_mouse_deadzone = Interior.Current_Pilot.mouse_deadzone
		current_max_mouse_distance = Interior.Current_Pilot.max_mouse_distance
		current_flight_mouse_sensitivity = Interior.Current_Pilot.flight_mouse_sensitivity
		current_is_relative_mouse = Interior.Current_Pilot.relative_flight_mouse
		#print(prefered_non_mouse_axe)
		print("activated rigidbody flight mode")

	if is_disabling:

		set_process_unhandled_input(false)
		set_process_input(false)
		print("deactivated rigidbody flight mode")

##Called by the player when reparenting.
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
var audio_stop := false
##until more advanced sound systems are added, creates procedural sound to represent the ships' velocity.
func TEMP_audio():
	while true:
		audiomut.lock()
		if audio_stop:
			return
		audiomut.unlock()
		frequ = linear_velocity.length() * 2
		var playback: AudioStreamGeneratorPlayback = proc_audio.get_stream_playback()
		
		# Fill available frames
		var frames_available = playback.get_frames_available()
		
		for i in range(frames_available):
			# Generate sine value between -1 and 1
			var sample : float
			sample = sin(phase * TAU)

			
			# Push stereo frame (same value for both channels)
			playback.push_frame(Vector2(sample, sample))
			
			# Advance phase
			phase += frequ / 44100.0
			
			# Keep phase in 0-1 range to avoid precision issues
			if phase >= 1.0:
				phase -= 1.0

func _exit_tree() -> void:
	
	if piloted:
		pilot_activation(true)
	audiomut.lock()
	audio_stop = true
	audiomut.unlock()
	audiothread.wait_to_finish()
##What do you think this does
func reset_mouse():
	mouse_relative_position = Vector2.ZERO
