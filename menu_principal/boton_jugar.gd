extends Button

@export var tutorial_01: PackedScene


func _ready() -> void:
	pressed.connect(_jugar, 4)


func _jugar():
	get_tree().change_scene_to_packed(tutorial_01)
