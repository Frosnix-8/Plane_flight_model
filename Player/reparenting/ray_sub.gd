extends RayCast3D
signal potential_obj(guest: Node3D, state: bool)
@onready var par

func _ready():
	par = get_parent()
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _physics_process(_delta: float) -> void:
	if par.timing % 5 != 0:
		return
	if get_collider():
		potential_obj.emit(get_collider(), false)
	
