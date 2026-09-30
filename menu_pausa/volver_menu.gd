extends Button

@export var menu_principal: PackedScene

func _ready() -> void:
	pressed.connect(_volver, 4)
	

func _volver():
	get_tree().change_scene_to_file("res://escenas/menu_principal/menu_principal.tscn")
