extends MeshInstance3D

@onready var UI_port : SubViewport = $SubViewport

func _on_mouse_enter(camera: Node, event: InputEvent, event_position: Vector3, _normal: Vector3, _shape_idx: int) -> void:
	if event is InputEventMouse:
		var lip :Vector3 = to_local(event_position)
		var uv :Vector2 = clamp(Vector2(lip.x + 0.5, 0.5 - lip.y), Vector2.ZERO, Vector2.ONE) * Vector2(UI_port.size)
		var UI_event := event.duplicate()
		UI_event.position = uv
		UI_port.push_input(UI_event)
		print("received and pushed mouse input.")
	pass # Replace with function body.
