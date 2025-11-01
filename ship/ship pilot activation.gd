extends MeshInstance3D


var outline : ShaderMaterial = mesh.surface_get_material(0).next_pass
var outliner : Shader = mesh.surface_get_material(0).next_pass.shader
var highlight : ShaderMaterial = mesh.surface_get_material(0).next_pass.next_pass
var highlighter : Shader = mesh.surface_get_material(0).next_pass.next_pass.shader
@onready var click_check := $CollisionShape3D
@onready var Interior := get_node("../")
var mouse_on_obj := false
@export var Interact_distance := 2.9
var outline_thickness_def := 0.0
##shut up i know its a magic number whatever
var highlight_color_def : Array[Color] = [Color(), Color()]
var is_too_far := false
var tween1 : Tween #opacity of ring
var tween2 : Tween #opacity of highlight
var tween3 : Tween #color of highlight

var active := false

func _ready() -> void:
	outline_thickness_def = outline.get_shader_parameter("thickness")
	highlight_color_def[0] = get_instance_shader_parameter("highlight_color")
	highlight_color_def[1] = get_instance_shader_parameter("click_color")
func _physics_process(_delta: float) -> void:
	if is_too_far:
		shader_tween_method(tween2, "opacity2", get_instance_shader_parameter("opacity2"), 0.0, 0.1)
		mouse_on_obj = false
func _input(_event: InputEvent) -> void:
	if Input.is_action_just_released("Context_Menu_Activate"):
		if tween2:
			shader_tween_method(tween2, "opacity2", get_instance_shader_parameter("opacity2"), 0.0, 0.1)
		set_instance_shader_parameter("hightlight_color", highlight_color_def[1])
		shader_tween_method(tween3, "highlight_color", get_instance_shader_parameter("highlight_color"), highlight_color_def[0], 0.3)
func on_mouse_exited() -> void:
	#tween2
	shader_tween_method(tween2, "opacity2", get_instance_shader_parameter("opacity2"),0.0,0.1)
	mouse_on_obj = false
func _input_event(_camera: Node, event: InputEvent, _event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if _camera.global_position.distance_to(_event_position) >= Interact_distance:
		
		is_too_far = true
	else:
		is_too_far = false
	if event is InputEventMouseButton:
		if event.is_pressed() and !is_too_far:
			set_instance_shader_parameter("highlight_color", highlight_color_def[1])
			
			if _camera == get_node("../Seating/Pilotcam"):
				
				Interior.pilot_toggle(null, true)
				
			else:
				Interior.pilot_toggle(_camera.cam_player, false)

			$AudioStreamPlayer3D.play()
			
			
			
			
		else:
			shader_tween_method(tween3, "highlight_color", get_instance_shader_parameter("highlight_color"), highlight_color_def[0], 0.05, false, Tween.EASE_OUT)
	if event is InputEventMouseMotion and !is_too_far and !mouse_on_obj:
		if !tween2 or !tween2.is_running(): 
			tween2 = create_tween()
			tween2.tween_method(func(x: float): set_instance_shader_parameter("opacity2", x), get_instance_shader_parameter("opacity2"), 0.3, 0.1)
			set_instance_shader_parameter("highlight_color", highlight_color_def[0])
			mouse_on_obj = true
	
##for cleanliness reasons, simplifies shader modifications.
func shader_tween_method(target_tween: Tween, property: String, from, to, duration : float, do_parallel: bool = false, _ease : Tween.EaseType = Tween.EASE_IN, trans : Tween.TransitionType = Tween.TRANS_LINEAR, kill_previous: bool = true, is_global: bool = false, shader: Shader = null):
	if kill_previous and target_tween:
		target_tween.kill()
		target_tween = create_tween()
	elif !target_tween:
		target_tween = create_tween()
	target_tween.set_parallel(do_parallel)
	target_tween.set_ease(_ease)
	target_tween.set_trans(trans)
	if !is_global:
		target_tween.tween_method(func(x): set_instance_shader_parameter(property, x), from, to, duration)
		return
	elif !shader:
		print("shader is nil. Aborting...")
		return
	else:
		target_tween.tween_property(shader, property, to, duration)

func camera_ajust():
	pass
