extends Node3D
@onready var ship := $ship
@onready var interior := $interior
@onready var exterior := $exterior
@export var is_frozen := false

func _ready() -> void:
	ship.freeze = is_frozen
