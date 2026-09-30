extends Button


func _ready() -> void:
	pressed.connect(_salir)


func _salir():
	get_tree().quit()
