extends CharacterBody3D

signal fail_recalibrate
#depracated: signal parent_call(is_depracated: bool, host: CharacterBody3D)
enum spacestates {grounded, airborne, spaceborne}
enum targetstates {none, ship, misc}
##The mother of all (normal) movement
@onready var world : Node3D = get_node("../environment")
##Parent
@onready var Parent := get_node("../")
##Reparent nodes
@onready var reparent_casts : Array[RayCast3D] = [$horirotation/Primaray,$horirotation/Primaray/BackRay,$horirotation/Primaray/FrontRay,
$horirotation/Primaray/LeftRay, $horirotation/Primaray/RightRay, $horirotation/Primaray/topray]
@onready var reparent_casts_defs : PackedVector3Array
@onready var GCheckRay := $horirotation/GCheckRay

@onready var meshpivot := $Meshpivot
@onready var pivot := $horirotation
@onready var omnipivot := $horirotation/vertication
@onready var cam := $horirotation/vertication/Playercam

##children that must be vertically transformed for height-sensitive actions.
@onready var height_adjustables : Array
@onready var Collision_Capsule := $Collision
##ALERT: TEMPORARY; ALL LOGIC INCLUDING THIS MUST BE REMOVED WHEN IMPLEMENTING PROPER RIGGED CHARACTERS
@onready var TEMP_MESH_CAPSULE := $Meshpivot/Placeholdermesh
##Global context shader.
@export var CShader_outline_thickness_def := 10.0
var Context_shader : ShaderMaterial = load("res://Interactible/Variable_outliner.tres")
var ShaderTween : Tween

##Two audio channels intended to allow smooth interpolation between two ambiences. This is NOT to play 2 simultaneous ambiences
@onready var audio_ambient_player_1 := $Ambient1
@onready var audio_ambient_player_2 := $Ambient2
##global audio interpolation tweener repository?
var Audio_Tweens : Dictionary = {}
var ambience_progress := 0.0

@export var  SPEED := 5.0
@export var ACCEL := 15.0
@export var JUMP_VELOCITY := 4.5
@export var HEIGHT := 1.7
var player_radius := 0.4
@export var atmos_density := 1.0
##Whether I should keep this or fully replace with spacestate is subject to debate.
@export var in_atmosphere := true
@export var spacestate = spacestates.grounded

var current_height := 1.7
##Apparently, the reparent logic needs to be done before move and slide. otherwise it can cause unnecessary teleporting. 
##This variant queues the target object before it can be swapped.
var PENDING_TARGET_OBJECT : Node3D
##Target node that the player will rotate, experience gravity, move, and see relative to.
var target_object: Node3D
var target_object_parent
var target_type := targetstates.none
var first_target_relative_position : Vector3
var transition_frame := false
var recalibrate := false
var recalibrate_progress := 0.0
var recalibrate_pivot_correction := true

var current_gravity := 9.8
var current_gravity_dir := Vector3.DOWN

##NOTE: Depracated
var plat_jumped := false
var plat_relative_pos: Vector3

var time_airborne := 0
var frame_count := 0
##the context menu is a system to allow seamless interaction with various objects in the environment. 
##This boolean enables and disables it. Uses the context shader.
var is_in_context_menu := false
@onready var contiming := $Contiming

var is_pilot := false
var is_active := true
var was_active := true
##I think you know what this is
func _ready() -> void:
	process_physics_priority = 0
	Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED)
	
	for x in range(6):
		#default target vectors for reparent vectors.
		reparent_casts_defs.append(reparent_casts[x].target_position)
	for x in [$Collision,$Meshpivot,$horirotation,$deb]:
		height_adjustables.append(x)
	height_adjust(false)
	await get_tree().create_timer(3.0).timeout
	Context_shader_toggle()
##I think you know what this is
func _physics_process(delta: float) -> void:

	frame_count += 1
	if recalibrate:
		reparent_recalibrate(delta)
	elif target_object:
		global_rotation = target_object.global_rotation
		
	if !is_active:
		for x in reparent_casts:
			x.enabled = false
		reparent_casts[0].process_mode = Node.PROCESS_MODE_DISABLED
		GCheckRay.process_mode = Node.PROCESS_MODE_DISABLED
		was_active = is_active
		height_adjust(false)
		return
	elif is_active and !was_active:
		for x in reparent_casts:
			x.enabled = true
		reparent_casts[0].process_mode = Node.PROCESS_MODE_PAUSABLE
		GCheckRay.process_mode = Node.PROCESS_MODE_PAUSABLE
		was_active = is_active
	
	#recalibration
	
	#reorient relative to "parent"
	
	
	#movement
	up_dir_calibrate()
	if spacestate == spacestates.grounded and in_atmosphere:
		grounded_movement(delta)
	else:
		atmos_movement(delta)
	
	#gravity and jumping
	if is_on_floor() and plat_jumped:
		plat_jumped = false
	#jump
	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity += -current_gravity_dir * JUMP_VELOCITY
		if target_object:
			plat_jumped = true
			plat_relative_pos = target_object.to_local(position)
	
	if Input.is_action_pressed("crouch"):
		height_adjust(true)
	elif Input.is_action_just_released("crouch"):
		height_adjust(false)
	#depracated high-speed movement safety
	#if target_object_parent:
		#if ("linear_velocity" in target_object_parent):
		#
			#floor_snap_length = target_object_parent.linear_velocity.length() * 0.018 + 0.1
			#pass
	#off groun
	
	if is_on_floor():
		time_airborne = 0
		spacestate = spacestates.grounded
	if !is_on_floor() and in_atmosphere:
		time_airborne += 1
		if target_object:
			velocity += current_gravity_dir * current_gravity * delta * 1.5
			##NOTE: depracated
			if plat_jumped:
				var _global_position := target_object.to_global(plat_relative_pos)
				var intmvmt := velocity * delta
				var new_global : Vector3 = _global_position + intmvmt
				plat_relative_pos = target_object.to_local(new_global)
				
				position = new_global
		else:
			velocity += get_gravity() * delta
		if time_airborne > 120 and target_type != targetstates.ship:
			spacestate = spacestates.airborne
	
	var pre_move_and_slide_position : Vector3 = global_position


	move_and_slide()
	if PENDING_TARGET_OBJECT:
		##THE SOLUTION HAS FINALLY BEEN IMPLEMENTED...
		target_object_swap(PENDING_TARGET_OBJECT)
		PENDING_TARGET_OBJECT = null
		recalibrate = true
	elif target_type != targetstates.ship:
		static_player_moving_world_adjust(pre_move_and_slide_position)
	apply_floor_snap()

		
	$deb.position = velocity / 4
	
##calibrates up_direction and 'current_gravity_dir' relative to 'target_object'. defaults if 'target_object' is null.
##TODO: maybe if I implement planets, perhaps include some more extra?
func up_dir_calibrate() -> void:
	
	if target_object:
		current_gravity_dir = -target_object.global_basis.y.normalized()
		#apparently causes issues
		up_direction = target_object.global_basis.y.normalized()
	else:
		current_gravity_dir = Vector3.DOWN
		up_direction = Vector3.UP
##Handles reparenting orientation
func reparent_recalibrate(delta: float):
	plat_jumped = false
	recalibrate_progress = min(recalibrate_progress + delta, 0.5)
	var eased_progress := recalibrate_progress * recalibrate_progress * (3.0 - 2.0 * recalibrate_progress)
	var pivot_global_y : float = pivot.global_rotation.y
	##NOTE: Please don't remove this for stability reasons.
	if global_basis.y.dot(target_object.global_basis.y) <= 0:
		await get_tree().physics_frame
		if global_basis.y.dot(target_object.global_basis.y) <= 0:
			recalibrate_pivot_correction = false
	
	global_basis = Basis(global_basis.get_rotation_quaternion().slerp(target_object.global_basis.get_rotation_quaternion(),eased_progress))
	if recalibrate_pivot_correction:
		pivot.global_rotation.y = pivot_global_y
		pivot.rotation = Vector3(0,pivot.rotation.y, 0)
	##Finish
	if recalibrate_progress >= 0.5:
		
		recalibrate = false
		recalibrate_progress = 0.0
		recalibrate_pivot_correction = true
##handles (airborne TODO) and spaceborne movement
func atmos_movement(delta: float):
	var direction : Vector3
	var input_dir := -Input.get_vector("back", "forward","left","right")
	#note: directions reversed because it only works that way for some reason
	direction = Vector3(input_dir.x, Input.get_axis("jump", "crouch"), input_dir.y).normalized() * omnipivot.global_basis.inverse() * -1
	if direction and velocity.length() <= 50:
		velocity += direction * delta * ACCEL * 0.6
	elif velocity.length() > 50:
		velocity -= velocity * delta
	else:
		velocity -= velocity * delta * 0.05
	#$deb.position = lerp($deb.position,direction, 0.5)
##handles grounded and almost grounded movement
func grounded_movement(delta: float) -> void:
	var direction := Vector3.ZERO
	var input_dir := Input.get_vector("back", "forward","right","left")
	var _SPEED : float = SPEED *( Input.get_axis("crouch","sprint") * 0.5 + 1 )
	var _ACCEL : float = SPEED *(Input.get_axis("crouch","sprint") * 0.2 + 1)
	#get rotated direction with basises
	if target_object:
		var forward = -pivot.global_basis.z
		var right = pivot.global_basis.x
	
		var platform_up = target_object.global_basis.y
		forward = (forward - platform_up * forward.dot(platform_up)).normalized()
		right = (right - platform_up * right.dot(platform_up)).normalized()
		direction = Vector3((forward * input_dir.y + right * input_dir.x)).normalized()
	else:
		direction = Vector3(pivot.global_basis * Vector3(input_dir.x, 0, -input_dir.y)).normalized()
	#apply movement
	if direction and is_on_floor():
		if velocity.length() <= SPEED:
			velocity = velocity.move_toward(direction * _SPEED, delta * ACCEL)
		else:
			velocity = velocity.move_toward(direction * _SPEED * 0.95, delta * ACCEL)
	elif !direction and is_on_floor():
		velocity = velocity.move_toward(Vector3.ZERO, 15 * delta)
		
	else:
		velocity = velocity.move_toward(direction * _SPEED, atmos_density * delta * 2.0)
##handles height adjustment and crouching. TODO: smooth it out.
func height_adjust(do_crouch: bool = true):
	##TODO: Smooth out crouching.
	var shape : CapsuleShape3D = Collision_Capsule.get_shape()
	if do_crouch:
		#print("adjusting crouch...")
		shape.set_height(HEIGHT / 2)
		current_height = HEIGHT / 2
		shape.set_radius(player_radius * 1.3)
		
	else:
		shape.set_height(HEIGHT)
		current_height = HEIGHT
		shape.set_radius(player_radius)
	for x:Node3D in height_adjustables:
		x.position.y = current_height / 2
	#print("offsetting adjustables by ", current_height / 2)
##handles correcting movement for the "static player" game model
func static_player_moving_world_adjust(delta: Vector3):
	world.position -= global_position - delta
	#print("STMW: ",position - delta)
	global_position = Vector3.ZERO
##mouse controls and misc.
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		if !is_pilot:
			if !is_in_context_menu and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
				pivot.rotation.y -= event.relative.x * 0.001
				omnipivot.rotation.z -= event.relative.y * 0.001
				omnipivot.rotation.z = clamp(omnipivot.rotation.z,-PI * 0.35, PI * 0.35)
			elif is_in_context_menu:
				if !contiming.is_stopped():
					return
				pivot.rotation.y = lerp(pivot.rotation.y,pivot.rotation.y - event.relative.x * 0.001, 0.1)
				omnipivot.rotation.z = lerp(omnipivot.rotation.z, omnipivot.rotation.z - event.relative.y * 0.001, 0.1)
				omnipivot.rotation.z = clamp(omnipivot.rotation.z,-PI * 0.35, PI * 0.35)
	if event is InputEventMouseButton and !is_in_context_menu:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
##misc input
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_end"):
		get_tree().quit()
		
	if Input.is_action_just_pressed("Context_Menu_Activate"):
		Input.mouse_mode = Input.MOUSE_MODE_CONFINED
		await get_tree().process_frame
		Input.warp_mouse(get_viewport().get_visible_rect().size / 2)
		is_in_context_menu = true
		contiming.start()
		Context_shader_toggle()
	elif Input.is_action_just_released("Context_Menu_Activate"):
		is_in_context_menu = false
		Input.mouse_mode = (Input.MOUSE_MODE_CAPTURED)
		Context_shader_toggle()
##handles if the target_object is lost due to a time-out
func _on_ray_cast_3d_parent_lost() -> void:
		
	if in_atmosphere:
		target_object_swap(get_tree().root.get_child(0))
		
		#reparent(target_object, true)
		recalibrate = true
	else: 
		target_object_swap(get_tree().root.get_child(0))

		#reparent(target_object,true)
	#print("lost parent, resetting...")
##verifies and reparents to arg1. Also handles target's parent.
func _on_ray_cast_3d_reparent(guest: Node3D) -> void:
	
	if !GCheckRay.ground_check(-guest.global_basis.y.normalized(), guest):
		fail_recalibrate.emit()
		return
	
	PENDING_TARGET_OBJECT = guest
	
	#recalibrate = true
##Shrinks reparent raycasts when on a ship.
func raycast_resize():
	if target_type == targetstates.ship:
		for x: int in reparent_casts.size():
			reparent_casts[x].target_position = reparent_casts_defs[x] / 2
	else:
		for x: int in reparent_casts.size():
			reparent_casts[x].target_position = reparent_casts_defs[x]
##checks for ship compatibility when swapping target_object. requires arg1
func target_object_swap(new_target: Node3D):
	var _velocity : Vector3
	##check if the new and old parent are related. If so, same ship.
	if new_target.is_in_group("Ship"):
		if new_target.The_Captain == target_object_parent:
			print("new target is same ship!")
			call_deferred("get_ambience", true)
			target_object.call("child_announcement", self, false)
			target_object = new_target
			target_object.call("child_announcement", self, true)
			call_deferred("get_ambience", false)
			return
	
	if target_object:
		if target_type == targetstates.ship:
			_velocity = target_object_ship_disembark()
		else: 
			call_deferred("get_ambience", true)
	###
	target_object = new_target
	###
	if target_object.is_in_group("Ship"):
		target_object_ship_board()
	else:
		target_object_misc_enter()
	velocity += _velocity

##DON'T TOUCH IT
##DON'T EVEN THINK ABOUT CHANGING IT
##IT'S PERFECT JUST THE WAY IT IS
func target_object_ship_disembark() -> Vector3:
	print("initiating ship disembark...")
	transition_frame = true
	
	var player_world_position := global_position
	var ship_velocity = target_object_parent.linear_velocity
	
	target_object_parent.call("child_call", self, false, world)
	target_object.call("child_announcement", self, false)
	
	#Doesn't my previous function do that already??
	target_object_parent.top_level = false
	#target_object_parent.position = ship_world_position - world.global_position
	
	call_deferred("get_ambience", true)
	target_type = targetstates.none
	target_object_parent = null
	
	print(world.global_position)
	#Claude told me to not use my function. maybe it's a bit different here?
	#Ah yes. static_player_moving_world_compensation uses the actual global position,
	#This does not. it uses the previous position.
	# this is pretty important maybe.
	##NOTE: this appears to send me back to the ship for some reason.
	##As a debug, I'm going to remove stuff and see what happens.
	var world_compensation := player_world_position

	world.position -= world_compensation
	global_position = Vector3.ZERO

	return ship_velocity
##DO NOT TOUCH IT
func target_object_ship_board() -> void:
	transition_frame = true

	target_object_parent = target_object.The_Captain
	target_type = targetstates.ship
	
	#var player_world_position := global_position

	#var player_relative_world_position := target_object.to_local(player_world_position)
	#var player_global_relative_position := target_object.to_global(player_relative_world_position)
	#global_position = player_global_relative_position
	target_object_parent.call("child_call", self, true, world)
	target_object.call("child_announcement", self, true)
	call_deferred("get_ambience", false)
	raycast_resize()
	static_player_moving_world_adjust(Vector3.ZERO)
	pass
##DO NOT TOUCH IT...
func target_object_misc_enter() -> void:

	target_type = targetstates.misc
	target_object_parent = null
	
	call_deferred("get_ambience", false)
	raycast_resize()
	
	#static_player_moving_world_adjust(Vector3.ZERO)

##retrieves the target object's ambience for immersion reasons.\n
##TODO: add tweening to volume
func get_ambience(is_removing: bool = false):
	
	if !target_object or !("ambience" in target_object):
		return
	var received_ambience : AudioStream = target_object.ambience
	var received_ambience_vol : float = target_object.ambience_vol
	#print(ambience_progress)
	if is_removing:
		#remove from any ambience node the specified audio.
		#print("initiating ambience removal.")
		for x : AudioStreamPlayer in [audio_ambient_player_1, audio_ambient_player_2]:
			if x.stream == received_ambience:
				#print("removed ambience.")
				audio_fade_out(x)
				continue
			#print("did not find specified ambience in ", x.name)
	else:
		# Assign to a free ambience node the received ambience.
		#print("initiating ambience assignment.")
		for x : AudioStreamPlayer in [audio_ambient_player_1, audio_ambient_player_2]:
			if x.stream:
				#print("failed to assign to ", x.name)
				continue
			#print("successfully assigned to: ", x.name)
			x.stream = received_ambience
			audio_fade_in(x,received_ambience_vol)
			break
	#print("completed!")
	return received_ambience
##Handles fading in audio.
func audio_fade_in(Player: AudioStreamPlayer,ambience_vol:= 0.0, fade_duration:= 1.0):
	if Audio_Tweens.has(Player):
		Audio_Tweens[Player].kill()
	
	Player.set_deferred("volume_db", -80.0)
	Player.play(ambience_progress)
	#print("beginning audio fade-in, time is: ", fade_duration)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_IN)
	tween.tween_property(Player, "volume_db", ambience_vol, fade_duration)
	Audio_Tweens[Player] = tween
##Handles fading out audio.
func audio_fade_out(Player: AudioStreamPlayer, fade_duration:= 3.0):
	if Audio_Tweens.has(Player):
		Audio_Tweens[Player].kill()
	var tween :Tween= create_tween()
	print("fading out...")
	#print("beginning audio fade-out, time is: ", fade_duration)
	ambience_progress = Player.get_playback_position()
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(Player, "volume_db", -80.0, fade_duration)
	tween.tween_callback(func():
		Player.stop
		Player.stream = null
		print("completed")
		)
##Handles fading in and out of context mode
func Context_shader_toggle():
	
	if is_in_context_menu:
		if ShaderTween:
			ShaderTween.kill()
		ShaderTween = create_tween()
		ShaderTween.set_ease(Tween.EASE_IN)
		ShaderTween.set_trans(Tween.TRANS_CIRC)
		ShaderTween.tween_property(Context_shader,  "shader_parameter/opacity", 1.0, 0.1)
		ShaderTween.parallel()
		ShaderTween.tween_property(Context_shader, "shader_parameter/thickness", CShader_outline_thickness_def, 0)
	else:
		if ShaderTween:
			ShaderTween.kill()
		ShaderTween = create_tween()
		ShaderTween.set_ease(Tween.EASE_IN)
		ShaderTween.set_trans(Tween.TRANS_CUBIC)
		ShaderTween.tween_property(Context_shader, "shader_parameter/opacity", 0.0, 0.3)
		ShaderTween.parallel()
		ShaderTween.tween_property(Context_shader, "shader_parameter/thickness", 0, 0.3)
##When starting to pilot a ship, this variable puts you in the mode.
func pilot_activation(is_disabling: bool):
	if is_disabling:
		is_active = true
		is_pilot = false
		return
	is_active = false
	is_pilot = true

	height_adjust(false)
