extends RayCast3D
signal parent_lost
signal reparent(guest: Node3D)

var timing := 0
var guestobj: Node3D
var lastguest: Node3D

#checking whether you can reparent to the object currently stood on
func _physics_process(_delta: float) -> void:
	timing += 1
	if timing % 5 != 0:
		if timing >= 9223372036854775800:
			timing = 0
		#print(timing)
		#print("skipped tming")
		return
	guestobj = get_collider()
	if guestobj == null:
		return
	else:
		neo_check_guest(guestobj)
	return
	#if guestobj.is_in_group("Platform"):
		#if is_in_group("off_plat"):
			#remove_from_group("off_plat")
			#add_to_group("on_plat")
			#reparent.emit(guestobj)
			#print(guestobj.name," is eligible")
		#$Scopekeep.start()
		#
	#elif guestobj.is_in_group("normal") and is_in_group("on_plat"):
		#remove_from_group("on_plat")
		#add_to_group("off_plat")
		#reparent.emit(guestobj)
		#print(guestobj.name," is eligible")
		#$Scopekeep.start()
		#$Scopekeep.stop()
		
func neo_check_guest(guest: Node3D):

	if guest != null:
		if guest != lastguest and get_collider() != lastguest:

			
			reparent.emit(guest)
			lastguest = guest
			
			#print("initiating reparent to ", guest.name)
			$Scopekeep.start()
		elif guest == lastguest:
			#print("guest ineligible for reparent: ", guest.name)
			$Scopekeep.start()

func check_guest_eligible(guest: Node3D, state: bool):
	if is_colliding():
		return
		
	if state == true:
		if is_in_group("off_plat"):
			remove_from_group("off_plat")
			add_to_group("on_plat")
			reparent.emit(guest)
			print(guest.name," is eligible")
		$Scopekeep.start()
	elif is_in_group("on_plat") and state == false:
		remove_from_group("on_plat")
		add_to_group("off_plat")
		reparent.emit(guest)
		print(guest.name," is eligible")
		$Scopekeep.start()
		$Scopekeep.stop()

func _on_scopekeep_timeout() -> void:
	parent_lost.emit()
	lastguest = null
	#print("lost parent, resetting...")
	return
	#reparent.emit(get_tree().root.get_child(0))
	#remove_from_group("on_plat")
	#add_to_group("off_plat")
	#print("scope reset")

func _on_character_body_3d_fail_recalibrate() -> void:
	lastguest = null
	print("failed to recalibrate; resetting memory")



func _on_right_ray_potential_obj(guest: Node3D, _state: bool) -> void:
	neo_check_guest(guest)
func _on_left_ray_potential_obj(guest: Node3D, _state: bool) -> void:
	neo_check_guest(guest)
func _on_front_ray_potential_obj(guest: Node3D, _state: bool) -> void:
	neo_check_guest(guest)
func _on_back_ray_potential_obj(guest: Node3D, _state: bool) -> void:
	neo_check_guest(guest)
func _on_topray_potential_obj(guest: Node3D, _state: bool) -> void:
	neo_check_guest(guest)
