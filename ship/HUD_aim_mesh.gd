extends MeshInstance3D
var Line : ImmediateMesh
#For the very first isntance, it's important this is not equal to mouse_relative_position.
var previous_mouse_position := Vector2(999999999,99999999)
var line_thread := Thread.new()
##NOTE: rather than manually update an intermediate variant i'm going to simply reference the actual vector2 mouse position variant from the ship.
@onready var Interior := get_node("../../")
@onready var Captain := get_node("../../../ship")
@export var width : float = 10.0

func _ready() -> void:
	Line = mesh
	width  /= (get_viewport().get_visible_rect().size.x)
##NOTE: THE ONLY JOB OF THIS SCRIPT IS TO HANDLE THE SHIPS' HUD. NO ASSIGNING OUTSIDE VARIABLES.

func _process(_delta: float) -> void:
	if !Captain.piloted:
		return
	if Interior.Current_Pilot.is_in_context_menu:
		return
	if previous_mouse_position == Captain.mouse_relative_position:
		return
	Line_update(width)
	previous_mouse_position = Captain.mouse_relative_position
	
func Line_update(_width: float):
	Line.clear_surfaces()
	
	# Start at origin, end at mouse position (converted to 3D)
	var start := Vector3.ZERO
	var end := Vector3(Captain.mouse_relative_position.x, -Captain.mouse_relative_position.y, 0)
	
	# Calculate direction and perpendicular for width
	var direction := (end - start).normalized()
	# Perpendicular in XY plane (90 degree rotation)
	var perpendicular := Vector3(-direction.y, direction.x, 0) * (_width * 0.5)
	
	Line.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	Line.surface_add_vertex(start - perpendicular)
	Line.surface_add_vertex(start + perpendicular)
	Line.surface_add_vertex(end - perpendicular)
	Line.surface_add_vertex(end + perpendicular)
	Line.surface_end()
