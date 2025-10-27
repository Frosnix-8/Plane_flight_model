extends Node3D
var onetwo = false
@onready var player = $CharacterBody3D
@onready var environment = $environment
# Called when the node enters the scene tree for the first time
func _ready() -> void:
	print("welcome to the prototype(tm). here are a few things you can do:
		1: board the ship, jump on it, whatever. 
		2: fly the ship. Press and hold F to open the interaction menu (or context menu for some reason).
		Close up objects are clickable. Due to a lackluster budget, expect bugs.")
# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(_delta: float) -> void:
	
	if environment.position.length() > 100000:
		environment.position = Vector3(0,-2,0)
		player.velocity = Vector3.ZERO
		print("reset")
