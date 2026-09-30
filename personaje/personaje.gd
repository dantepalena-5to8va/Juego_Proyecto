extends CharacterBody2D

#Animacion y Area
@export var animacion : AnimatedSprite2D
@export var area_2d : Area2D


#Velocidad
var _velocidad: float = 150.0
var _velocidad_salto: float = -350.0


#Vida y Balas
signal vida_cambiada(actual: int, maxima: int)
signal municion_cambiada(actual: int, maxima: int)
signal muerto

@export var vida_maxima: int = 3
@export var municion_maxima: int = 7
@export var cadencia: float = 0.3
@export var escena_bala: PackedScene

var vida_actual: int
var municion: int
var puede_disparar: bool = true

var _muerto: bool = false


func _ready():
	area_2d.body_entered.connect(_on_area_2d_body_entered)
	
	vida_actual = vida_maxima
	municion = municion_maxima
	vida_cambiada.emit(vida_actual, vida_maxima)
	municion_cambiada.emit(municion, municion_maxima)


func _physics_process(delta):
	
	if _muerto:
		get_tree().change_scene_to_file("res://escenas/dellota/derrota.tscn")
		return
	
	velocity += get_gravity() * delta
	
	if Input.is_action_just_pressed("saltar") and is_on_floor():
		velocity.y = _velocidad_salto
	
	if Input.is_action_pressed("derecha"):
		velocity.x = _velocidad
		animacion.flip_h = false
	elif Input.is_action_pressed("izquierda"):
		velocity.x = -_velocidad
		animacion.flip_h = true
	else:
		velocity.x = 0
	
	move_and_slide()
	
	if !is_on_floor():
		animacion.play("saltar")
	elif velocity.x != 0:
		animacion.play("correr")
	else:
		animacion.play("idle")
	
	if Input.is_action_just_pressed("disparar"):
		disparar()
	if Input.is_action_just_pressed("recargar"):
		municion = municion_maxima
		municion_cambiada.emit(municion, municion_maxima)
	
	if Input.is_action_just_pressed("pausar"):
		
		get_tree().paused
		get_tree().change_scene_to_file("res://escenas/menu_pausa/menu_pausa.tscn")
	


func recibir_dano(cantidad: int = 1) -> void:
	vida_actual = max(vida_actual - cantidad, 0)
	vida_cambiada.emit(vida_actual, vida_maxima)
	if vida_actual == 0:
		muerto.emit()


func disparar() -> void:
	if not puede_disparar or municion <= 0 or escena_bala == null:
		return

	puede_disparar = false
	municion -= 1
	municion_cambiada.emit(municion, municion_maxima)

	var dir: float = -1.0 if animacion.flip_h else 1.0

	var bala := escena_bala.instantiate()
	bala.rotation = 0.0 if dir > 0 else PI
	get_tree().current_scene.add_child(bala)

	await get_tree().create_timer(cadencia).timeout
	puede_disparar = true


func curar(cantidad: int = 1) -> void:
	vida_actual = min(vida_actual + cantidad, vida_maxima)
	vida_cambiada.emit(vida_actual, vida_maxima)



func _on_area_2d_body_entered(_body: Node2D) -> void:
	
	_muerto = true
	animacion.stop()
	
	await get_tree().create_timer(0.5).timeout
	get_tree().call_deferred("reload_current_scene")
