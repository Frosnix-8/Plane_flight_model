extends RigidBody3D

#a couple notes about my coding style. 
#1: when something will be reused, turn it into a function
#2: when a calculation will be reused, such as var.length(), especially complex math, turn it into a variable first so you only call memory.
#3: functions are grouped into "themes", that is in the sense that they have similar jobs or work together.


@onready var Exterior : Node3D = get_node("../exterior")
@onready var Interior : Node3D = get_node("../interior")
@onready var Capcap = get_parent()

##Speed multiplier per direction indicated. 
##NOTE: Purely relative: a multiplier of 1 means it will take 5 seconds to reach 100m/s
##(Assuming there is no damping applied, which is not intended to be implemented...)
@export_group("linear and angular acceleration")
@export var forward_Backward_speed_multiplier := Vector2(1.3,0.8)
@export var top_Bottom_speed_multiplier := Vector2(1,1)
@export var left_Right_speed_multiplier := Vector2(0.7,0.7)
##Holds the biggest value of each of the three values above.. NOTE: unused for the moment.
var xyz_multiplier_length_array : Array
@export var axial_strength := Vector3(4.0,1.2, 1.7)
@export var atmospheric_axial_strength := Vector3(6, 1.2, 2)
##max angular speed in degrees through regular torque application; 
@export var max_degree_axial_speed := Vector3(90,100,50)
##max axial speed in radians.
@onready var max_axial_speed : Vector3
##Unlike max axial speed in voids, the actual limit varies on speed. NOTE: Currently implementing drag.
@export var max_degree_atmospheric_axial_speed := Vector3.ZERO
##atmospheric axial speed limit in radians.
var max_atmospheric_axial_speed :Vector3


@export_group("speed limits")
##The usual max speed of the ship. I'm mixed between making ships go ludicrously fast or not.
@export var max_regular_speed : float = 600
##The max usual atmospheric speed.
@export var max_atmospheric_regular_speed : float = 300
##The max boosted atmospheric speed.
@export var max_atmospheric_speed : float = 450
##The absolute highest the ship can achieve at any given moment.
@export var max_speed : float = 1200
##At this speed, lift force allows the ship to not use its vertical thrusters in an environment of 1 atmosphere. Varies linearly.
@export var max_lift_speed : float = 150.0

##Defines how strong thrusters are globally. This allows speed to be independent of mass.
const GLOBAL_STRENGTH_MULTIPLIER := 100.0/4.0
const G_FORCE := 9.8
const G_CONSTANT := 6.6743
##GFORCE
var previous_velocity := Vector3.ZERO
var G_forces := Vector3.ZERO
@export_group("G_forces")
##Max G's the ship is allowed to turn at 1 atmosphere. scales logarithmicaly
@export var max_atmospheric_G_tolerance : float = 10.0
##Max G's the ship can tolerate briefly. This may as well be the below variable but why not.
@export var max_atmospheric_G_tolerance_instant : float = 15.0
##Max G's the ship can tolerate at 1 atmosphere.
@export var max_atmospheric_G_absolute : float = 20.0
##Max G's the ship can endure before any critical error entails.
@export var max_G_absolute : float = 30.0
var crash_G : float = 50.0
@export_group("misc.")
##ALERT: depracated, remove when possible.
@export var in_atmosphere := false
##Drag coefficient of ship at 1 atmosphere.
@export_group("aerodynamic parameters")
@export var atmospheric_drag := 0.1
##density in atmospheres of the atmosphere.
@export var atmospheric_density := 1.0
##Lift surface of strength of the ship relative to mass.
@export var atmospheric_lift : float = 50.0



#FLIGHT VARIABLES

	#FLIGHT ASSIST
var flight_assist_enabled := true
var thrust_gravity_offset : Vector3
##Forward speed in meters the ship tries to reach.
var flight_assist_throttle := 0.0
	#BOOST
@export_group("boost_parameters")
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




#Player imported parameters



var mouse_relative_position : Vector2
##Max distance in pixels from center screen that the flight cursor can be moved to reach max steer.
var current_max_mouse_distance : float
##Received from the player when piloting, 0 is pitch, 1 is roll, 2 is yaw. Magic numbers because idk how to transfer enums.
var current_prefered_non_mouse_axe : int
var current_mouse_deadzone : float
var current_flight_mouse_sensitivity : float
var current_is_relative_mouse : float
var current_assist_throttle_increment : float

#player related variants.
var is_target := false
var piloted := false
##ALERT: switch to array when adding multiplayer?
var Child: CharacterBody3D
##ALERT: how will multiple players handle this?
var Child_World : Node3D

var prev_pos : Vector3
var queued_direction := Vector3.ZERO
var queued_rotation := Vector3.ZERO
var input_queued := false

@onready var audiothread := Thread.new()
@onready var audiomut := Mutex.new()
@onready var proc_audio = $TMP_Audio


#FLAGS



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
	#print("velocity ", linear_velocity.length())
	#print(angular_velocity)
	#print("Piloting: ", self.name, " | Interior.Current_Pilot = ", Interior.Current_Pilot)a
	if atmospheric_density:
		#apply_central_force(thrust_gravity_offset * clamp((basis.inverse() * linear_velocity).x * atmospheric_density/max_lift_speed, 0, 1))
		calculate_atmospheric_lift()
	frametime += 1
	#print(Interior.Current_Pilot, " ",self)
	if piloted:
		linear_damp = 0.0
		
		#print(direction)
		var rotation_torque : Vector3 = calculate_ship_rotation() 
		
		calculate_g_force(delta)
		apply_torque(basis* rotation_torque)
		#print(rotation_torque)
		
		calculate_ship_linear_velocity()
		if frametime % 3 == 0:
			call_deferred("calculate_max_speed")
			call_deferred("calculate_gravity_offset", delta)
			call_deferred("calculate_atmospheric_density")
		flight_mouse_depreciation(delta)
		#print("lift strength is at: ", clamp(linear_velocity.length()/max_lift_speed, 0, 1) * 100, "%")
	else:
		linear_damp = 0.2
		return
	
	previous_velocity = linear_velocity
	
		
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
	var _max_regular_speed : float = lerp(max_regular_speed,max_atmospheric_regular_speed, atmospheric_density)
	var _max_speed : float = lerp(max_speed, max_atmospheric_speed, atmospheric_density) 
	if boost:
		speed_limit = _max_speed
		return
	speed_limit = _max_regular_speed
	
##Calculates "drag", as in how fast the ship will shed velocity. NOTE: this is not direction dependent.
func calculate_drag() -> void:
	
	return 
##Calculates atmospheric density in atmospheres at any given moment.
func calculate_atmospheric_density() -> void:
	##TODO: complete this.
	atmospheric_density = 1.0
##For atmospheric flight, calculates centripetal force.



##For atmospheric flight, calculates centripetal force.
func calculate_atmospheric_lift() -> void:
	var velocity_dir: Vector3 = linear_velocity.normalized()
	var forward: Vector3 = global_basis.x
	var right: Vector3 = global_basis.z
	var speed: float = linear_velocity.length()
	# Angle of attack in radians
	var aoa_rad: float = forward.angle_to(velocity_dir)	
	var lift_demand : float
	if aoa_rad < deg_to_rad(0.001):
		lift_demand = 1.0
		return
	lift_demand = G_forces.length()
	# Convert to degrees for lift coefficient calculation
	var aoa_deg: float = rad_to_deg(aoa_rad)
	var aoa_yaw_deg : float = rad_to_deg(right.angle_to(velocity_dir))
	var slip_angle : float = abs(aoa_yaw_deg - 90.0)
	
	# Dynamic pressure (realistic: ½ρv²)
	var dynamic_pressure: float = 0.5 * atmospheric_density * speed * speed
	var turn_axis: Vector3 = velocity_dir.cross(forward).normalized()
	var lift_direction: Vector3 = turn_axis.cross(velocity_dir).normalized()
	var yaw_penalty : float = clamp(1-((slip_angle)/ 45), 0, 1)

	var CL: float = calculate_atmospheric_lift_coefficient(aoa_deg, slip_angle, lift_demand)
	calculate_yaw_stabilization(slip_angle, speed)

	#print("CL: ", CL)
	var lift_force: Vector3 =lift_direction * atmospheric_lift * CL * dynamic_pressure * yaw_penalty

	apply_central_force(lift_force)
#TODO: vary slip angles depending on velocity



##Returns lift coefficient based on angle of attack. Includes stall behavior.
func calculate_atmospheric_lift_coefficient(aoa_degrees: float, slip_angle : float, lift_multiplier : float) -> float:
	var aoa: float = abs(aoa_degrees)
	var FLAG_stall := false
	var critical_CL := 1.5
	var necessary_CL : float = 0.1 * aoa * lift_multiplier
	##TODO: review
	var stall : float = critical_CL * 0.85
	#NOTE: uncomment for previous system.
	## Speed factor: tighter tolerances at high speed
	var mach_number: float = linear_velocity.length() / 343.0  # 343 m/s = Mach 1 at sea level
	var speed_factor: float = clamp(mach_number / 0.5, 0.3, 1.0)  # 0.3x tolerance at low speed, 1.0x at Mach 0.5+
	#
	# Pitch stall component (AoA tolerance decreases with speed)
	#var max_safe_aoa: float = 18.0 * (1.0 - speed_factor * 0.75)  # 18° at low speed, 7.2° at high speed
	#var stall_aoa: float = max_safe_aoa * 1.2
	
	var pitch_CL: float
	if necessary_CL < stall:
		pitch_CL = necessary_CL
	elif necessary_CL < critical_CL:
		pitch_CL = lerp(stall, critical_CL, 
		(necessary_CL - stall)/(critical_CL - stall))
		print("semi stall")
	else:
		print("STALL at ", lift_multiplier, "G ; aoa is ", aoa)
		FLAG_stall = true
		pitch_CL = critical_CL * 0.35
	
	
	
	# Yaw slip penalty (margins tighten dramatically with speed)
	var max_safe_slip: float = 10.0 * (1.0 - speed_factor * 0.9)  # 15° at low speed, 3.5° at high speed
	var critical_slip: float = max_safe_slip * 2.0
	
	var slip_penalty: float
	if slip_angle < max_safe_slip:
		slip_penalty = 1.0
	elif slip_angle < critical_slip:
		# Rapid degradation
		var slip_ratio: float = (slip_angle - max_safe_slip) / max_safe_slip
		slip_penalty = 1.0 - slip_ratio * 0.7  # Drop to 0.3
	else:
		print("SLIP")
		FLAG_stall = true
		# Catastrophic
		slip_penalty = max(0.05, 0.3 - ((slip_angle - critical_slip) / 20.0))
	if FLAG_stall:
		calculate_flow_separation_drag(linear_velocity.length(), pitch_CL * slip_penalty)
	return pitch_CL * slip_penalty
		

func calculate_flow_separation_drag(speed: float, CL: float) -> void:
	if speed <= 1.0:
		return
	
	# Drag scales with speed and how badly you're stalled
	var stall_severity: float = 1.0 - (CL / 1.5)  # 0 = no stall, 1 = full stall
	var drag_coefficient: float = 0.5 + (stall_severity * 2.0)  # 0.5 to 2.5
	
	var drag_force: float = 0.5 * atmospheric_density * speed * speed * drag_coefficient * atmospheric_lift * 0.1
	
	apply_central_force(-linear_velocity.normalized() * drag_force)

##TODO: clean this up.
func calculate_yaw_stabilization(slip_angle: float, speed: float) -> void:
	if slip_angle <= 1.0:
		return
	# Determine which direction we're slipping
	# Cross product tells us if slipping left or right
	var slip_direction: float = sign( rad_to_deg(global_basis.z.angle_to(linear_velocity.normalized())) - 90)
	#print( rad_to_deg(global_basis.z.angle_to(linear_velocity.normalized())) - 90)
	# Torque magnitude scales with slip angle and speed
	var stabilization_strength: float = slip_angle * speed * speed * atmospheric_density * atmospheric_axial_strength.y * 3
	
	# Apply yaw torque to rotate back into the wind
	var yaw_correction: Vector3 = global_basis.y * slip_direction * stabilization_strength
	#print("pulled yaw of ", yaw_correction)
	apply_torque(yaw_correction)
	

##Computes g_forces based off the ship's current velocity (TODO and gravity? I forgot.)
func calculate_g_force(delta: float):
	var acceleration :Vector3 = (linear_velocity - previous_velocity) / delta
	G_forces = basis * (acceleration / G_FORCE)
	var gvar := G_forces.length()
	#print("G forces: ",G_forces.length())
	var s_atm := sqrt(atmospheric_density)
	#as atmospheres get denser, tolerances drop logarithmicaly.
	var G_limit_critical : float = lerp(max_G_absolute, max_atmospheric_G_absolute, s_atm)
	var G_limit_instant : float = lerp(max_G_absolute, max_atmospheric_G_tolerance_instant, s_atm)
	var G_limit : float = lerp(max_G_absolute, max_atmospheric_G_tolerance, s_atm)
	
	if gvar <= G_limit:
		return
	elif gvar <= G_limit_instant:
		print("approaching safe mechanical limit")
		return
	elif gvar <= G_limit_critical:
		print("approaching dangerous mechanical limit")
		return
	elif gvar >= crash_G:
		print("crash detected.")
		return
	else:
		print("mechanical limit reached. failure imminent.")
	
##Calculate linear acceleration based off of input and other factors.
func calculate_ship_linear_velocity():
	
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
		var x_velocity := (basis.inverse() * linear_velocity).x 
		var target_speed := (flight_assist_throttle/100) * speed_limit 
		var flight_assist := linear_flight_assist()
		for x in range(3):
			if !direction[x]:
				if x == 0:
					#print("adjusting linear speed. Target is ", target_speed)
					#is our velocity higher than target?
					if abs(x_velocity - target_speed) > 1.0:
						#speed for either direction. slow down if going faster.
						if x_velocity > target_speed:
							final_velocity[x] = -forward_Backward_speed_multiplier.y * mass * GLOBAL_STRENGTH_MULTIPLIER
						else:
							final_velocity[x] = forward_Backward_speed_multiplier.x * mass * GLOBAL_STRENGTH_MULTIPLIER
				else:
					final_velocity[x] = flight_assist[x] * (boost_multiplier[x] * int(boost) + int(!boost))
		#TODO: for when gravity while vary, change this.
		if get_gravity():
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
			#print(gravity_compensation)
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
	var axp : Vector3 = lerp(axial_strength, atmospheric_axial_strength, clamp(atmospheric_density * (linear_velocity.length()/100.0 + 0.1),0,1))
	#print(normalized_mouse_position.length())
	#keyboard and mouse are not separate because they complement each other. the non-mouse axis requires keyboard input.
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

	if !flight_assist_enabled:
		
		# Apply torque directly (rotational force)
		torque = Vector3(
			rolltation * inertia.x * axp.x * int(abs(corrected_angular.x) < max_axial_speed.x or sign(corrected_angular.x) != sign(rolltation)),
			-target_rotation.y * inertia.y * axp.y * int(abs(corrected_angular.y) < max_axial_speed.y or sign(corrected_angular.y) != sign(-target_rotation.y)),
			target_rotation.x * inertia.z * axp.z *int(abs(corrected_angular.z) < max_axial_speed.z or sign(corrected_angular.z) != sign(target_rotation.x))
			)
	else:
		var rot_input : Array = [rolltation, -target_rotation.y, target_rotation.x]
		for x:int in range(3):
			#1: if going in opposite direction of current rotation, put all force to change direction. otherwise limit based off input distance.

			#opposite direction compensation.
			if rot_input[x] != 0 and sign(corrected_angular[x]) != sign(rot_input[x]):
				torque[x] = -sign(corrected_angular[x]) * inertia[x]
			#same direction at specific speed.
			if abs(corrected_angular[x]) < max_axial_speed[x] * abs(rot_input[x]):
				torque[x] = rot_input[x] * inertia[x] * axp[x]
			#nothing.
			else:
				torque[x] = 0.0
		
		
		
		#now this is the issue. NOTE: Solved for now.
		var axial_assist := axial_flight_assist(axp)

		for x in range(3):
			if torque[x] == 0:
				torque[x] = axial_assist[x]
	return torque
	
##Calculates axial flight assist required to stop all transient rotations.
func axial_flight_assist(axp: Vector3) -> Vector3:
	if angular_velocity.length() == 0:
		return Vector3.ZERO
	var corrected_angular := basis.inverse() * angular_velocity
	var correction := Vector3.ZERO
	
	var high_speed_threshold := 0.005  # Above 50% max speed
		#TODO: add axial speed limits.
	for x in range(3):
		if corrected_angular[x] != 0:
			var speed_ratio :float= abs(corrected_angular[x]) / max_axial_speed[x]
			#print(speed_ratio)
			if speed_ratio > high_speed_threshold:
				# High speed: full braking
				correction[x] = -sign(corrected_angular[x]) * inertia[x] * axp[x]
			else:
				# Low speed: proportional reduction
				correction[x] = -(corrected_angular[x]) * inertia[x] * axp[x]

	return correction

	
##Calculates linear flight assist variables to return to target movement speed while removing lateral velocity. NOTE: target speed not implemented.
##flight assist will for now, only set the player back to standstill.
func linear_flight_assist() -> Vector3:
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
	
func _unhandled_input(event: InputEvent) -> void:
	#TODO: multiplayer may require asking for controller id.
	if !piloted:
		return
	#TODO: add toggle feature?
	boost = bool(event.is_action_pressed("ship boost",true))
	
	if event.is_action_released("flight assist toggle"):
		flight_assist_enabled = !flight_assist_enabled
		if flight_assist_enabled:
			print("flight assist on.")
		else:
			print("flight assist off.")
	#mouse input only if not in context menu.
	if Interior.Current_Pilot.is_in_context_menu:
		return
	if event is InputEventMouseMotion:
		#since the mouse isn't always in the center when playing, I opted for a virtual mouse instead.
		mouse_relative_position += event.relative / 500
		if mouse_relative_position.length() > current_max_mouse_distance:
			mouse_relative_position = mouse_relative_position.normalized() * current_max_mouse_distance
		#print(mouse_relative_position)

	if event is InputEventKey:
		
		if event.is_action_pressed("flight assist increase speed", true):
			flight_assist_throttle += current_assist_throttle_increment
		elif event.is_action_pressed("flight assist reduce speed", true):
			flight_assist_throttle -= current_assist_throttle_increment
		flight_assist_throttle = clamp(flight_assist_throttle,-100, 100)
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
		#all pilot specific parameters are defined here.
		current_prefered_non_mouse_axe = Interior.Current_Pilot.prefered_non_mouse_axe
		current_mouse_deadzone = Interior.Current_Pilot.mouse_deadzone
		current_max_mouse_distance = Interior.Current_Pilot.max_mouse_distance
		current_flight_mouse_sensitivity = Interior.Current_Pilot.flight_mouse_sensitivity
		current_is_relative_mouse = Interior.Current_Pilot.relative_flight_mouse
		current_assist_throttle_increment = Interior.Current_Pilot.assist_throttle_increment
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
