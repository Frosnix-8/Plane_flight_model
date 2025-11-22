extends MeshInstance3D

#I think I should make a state machine for all the different interfaces that will be available.
enum UI_tabs {welcome, general, specs, defense, offense, comms}
var UI_page : int = UI_tabs.welcome
var activated := false


#CHILDREN

##Viewport of UI interface.
@onready var UI_port : SubViewport = $UI_viewport
##UI Interface. call for methods controlling.
@onready var UI_control : Control = $UI_viewport/UI_control_main

#PARENTS

##Interior section of ship being controlled.
@onready var Interior : AnimatableBody3D = get_node("../../")
##Physics model of ship being controlled.
@onready var Ship : RigidBody3D

func _physics_process(_delta: float) -> void:
	if Interior.fcount % 15 == 0:
		match Interior.is_activated:
			true:
				get_surface_override_material(0).emission_energy_multiplier = 1
			false:
				get_surface_override_material(0).emission_energy_multiplier = 0

##As a matter of fact, anyone can press the buttons.
func _on_mouse_enter(_camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouse:
		var lip :Vector3 = to_local(event_position)
		var uv :Vector2 = clamp(Vector2(lip.x + 0.5, 0.5 - lip.y), Vector2.ZERO, Vector2.ONE) * Vector2(UI_port.size)
		var UI_event := event.duplicate()
		UI_event.position = uv
		UI_port.push_input(UI_event)
		print("received input")
		
