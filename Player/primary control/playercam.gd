extends Camera3D
##For some input events tied to certain objects, this comes in handy for identifying the player.
@onready var cam_player = self.get_node("../../../")
