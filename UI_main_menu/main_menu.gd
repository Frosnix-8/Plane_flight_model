
extends Control




func _on_quitbutton_pressed() -> void:
	get_tree().quit()


func _on_startbutton_pressed() -> void:
	get_tree().change_scene_to_file("res://main/main.tscn")
