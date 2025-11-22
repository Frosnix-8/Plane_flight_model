extends RayCast3D
signal eligible()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	if get_collider() and get_collider().is_in_group("Platform"):
		eligible.emit()
