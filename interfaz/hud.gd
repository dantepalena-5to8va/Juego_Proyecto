extends CanvasLayer

@export var textura_llena: Texture2D
@export var textura_vacia: Texture2D

@onready var corazones: HBoxContainer = $MarginContainer/VBoxContainer/corazones
@onready var label_municion: Label = $MarginContainer/VBoxContainer/balas

func _ready() -> void:
	var player := get_tree().get_first_node_in_group("personaje")
	if player == null:
		return
	player.vida_cambiada.connect(_on_vida_cambiada)
	player.municion_cambiada.connect(_on_municion_cambiada)

func _on_vida_cambiada(actual: int, maxima: int) -> void:
	while corazones.get_child_count() < maxima:
		var icono := TextureRect.new()
		icono.custom_minimum_size = Vector2(32, 32)
		icono.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		corazones.add_child(icono)

	for i in corazones.get_child_count():
		corazones.get_child(i).texture = textura_llena if i < actual else textura_vacia

func _on_municion_cambiada(actual: int, maxima: int) -> void:
	label_municion.text = "%d / %d" % [actual, maxima]
