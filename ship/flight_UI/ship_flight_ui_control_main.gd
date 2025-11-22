extends Control
signal UI_order(type: String, variants)
var is_active := false
#Code with methods. this code does not directly access other variables, rather should be called from the parent above.
#methods here serve to be called by a parent.

##Activates or deactivates, resetting the entire system.
func control_toggle_activation(is_activating : bool):
	is_active = is_activating
	if !is_activating:
		for x in get_children():
			x.visible = false
	else:
		for x in get_children():
			x.visible = false
		$welcome.visible = true
