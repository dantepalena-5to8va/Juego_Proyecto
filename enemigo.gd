extends CharacterBody2D
# Enemigo de la cueva: patrulla, persigue al jugador y ataca cuerpo a cuerpo.
# Recibe daño con recibir_dano(cantidad), igual que el jugador.

signal muerto

enum Estado { PATRULLA, PERSECUCION, ATACANDO, HERIDO, MUERTO }

@export var animacion: AnimatedSprite2D
@export var zona_ataque: Area2D          # hitbox de sus mordidas
@export var deteccion: Area2D            # radio en el que "ve" al jugador
@export var detector_borde: RayCast2D    # evita que se caiga de las plataformas

@export var vida_maxima: int = 4
@export var velocidad_patrulla: float = 30.0
@export var velocidad_persecucion: float = 55.0
@export var rango_ataque: float = 30.0          # distancia horizontal para atacar
@export var enfriamiento_ataque: float = 1.0    # segundos entre ataques
@export var patrullar: bool = false             # false = se queda quieto hasta ver al jugador
# El arte original mira a la IZQUIERDA
@export_enum("Izquierda:-1", "Derecha:1") var mirando: int = -1

# Cuánto está corrido el cuerpo dentro del frame de 96x96 (se multiplica por la escala)
const DESPLAZAMIENTO_SPRITE_X := 13.0

# frames = en cuáles el golpe conecta | impulso = embestida hacia adelante (0 = quieto)
const ATAQUES = [
	{"anim": "ataque1", "frames": Vector2i(3, 4), "dano": 1, "impulso": 0.0},
	{"anim": "ataque2", "frames": Vector2i(3, 4), "dano": 1, "impulso": 0.0},
	{"anim": "ataque3", "frames": Vector2i(2, 4), "dano": 1, "impulso": 110.0},
	{"anim": "ataque4", "frames": Vector2i(2, 3), "dano": 1, "impulso": 0.0},
]

var estado: Estado = Estado.PATRULLA
var vida_actual: int
var objetivo: Node2D = null
var ataque: Dictionary = {}
var tiempo_ataque_restante: float = 0.0
var golpeados: Array[Node] = []


func _ready() -> void:
	vida_actual = vida_maxima
	_mirar(mirando)
	
	zona_ataque.body_entered.connect(_on_zona_ataque_body_entered)
	deteccion.body_entered.connect(_on_deteccion_body_entered)
	deteccion.body_exited.connect(_on_deteccion_body_exited)
	animacion.animation_finished.connect(_on_animacion_finished)
	animacion.frame_changed.connect(_on_animacion_frame_changed)
	animacion.play("idle")


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
	tiempo_ataque_restante -= delta
	
	match estado:
		Estado.PATRULLA:
			_patrullar()
		Estado.PERSECUCION:
			_perseguir()
		Estado.ATACANDO:
			_proceso_ataque()
		Estado.HERIDO:
			velocity.x = move_toward(velocity.x, 0.0, 400.0 * delta)
		Estado.MUERTO:
			velocity.x = 0.0
	
	move_and_slide()


# ---------- Movimiento ----------

func _mirar(dir: int) -> void:
	mirando = dir
	animacion.flip_h = dir > 0
	animacion.position.x = DESPLAZAMIENTO_SPRITE_X * absf(animacion.scale.x) * dir
	zona_ataque.position.x = absf(zona_ataque.position.x) * dir
	detector_borde.position.x = absf(detector_borde.position.x) * dir
	detector_borde.force_raycast_update()


func _hay_suelo_adelante() -> bool:
	return not is_on_floor() or detector_borde.is_colliding()


func _patrullar() -> void:
	if objetivo != null and is_instance_valid(objetivo):
		estado = Estado.PERSECUCION
		return
	if not patrullar:
		velocity.x = 0.0
		animacion.play("idle")
		return
	if is_on_wall() or not _hay_suelo_adelante():
		_mirar(-mirando)
	velocity.x = mirando * velocidad_patrulla
	animacion.play("caminar")


func _perseguir() -> void:
	if objetivo == null or not is_instance_valid(objetivo):
		estado = Estado.PATRULLA
		return
	
	var dx: float = objetivo.global_position.x - global_position.x
	var dy: float = objetivo.global_position.y - global_position.y
	if absf(dx) > 4.0:
		_mirar(1 if dx > 0.0 else -1)
	
	var en_rango: bool = absf(dx) <= rango_ataque and absf(dy) < 24.0
	if en_rango and tiempo_ataque_restante <= 0.0:
		_iniciar_ataque()
		return
	
	if absf(dx) <= rango_ataque or not _hay_suelo_adelante():
		velocity.x = 0.0
		animacion.play("idle")
	else:
		velocity.x = mirando * velocidad_persecucion
		animacion.play("caminar")


# ---------- Ataque ----------

func _iniciar_ataque() -> void:
	estado = Estado.ATACANDO
	ataque = ATAQUES.pick_random()
	golpeados.clear()
	velocity.x = 0.0
	animacion.play(ataque["anim"])


func _proceso_ataque() -> void:
	var rango: Vector2i = ataque["frames"]
	var f: int = animacion.frame
	var impulso: float = ataque["impulso"]
	if impulso > 0.0 and f >= rango.x and f <= rango.y and _hay_suelo_adelante():
		velocity.x = mirando * impulso
	else:
		velocity.x = 0.0


# Enciende la hitbox solo en los frames donde la mordida conecta
func _on_animacion_frame_changed() -> void:
	if estado != Estado.ATACANDO:
		return
	var rango: Vector2i = ataque["frames"]
	zona_ataque.set_deferred("monitoring", animacion.frame >= rango.x and animacion.frame <= rango.y)


func _on_zona_ataque_body_entered(body: Node2D) -> void:
	if body in golpeados:
		return
	if body.has_method("recibir_dano"):
		golpeados.append(body)
		body.recibir_dano(ataque["dano"])


func _on_animacion_finished() -> void:
	match estado:
		Estado.ATACANDO:
			zona_ataque.set_deferred("monitoring", false)
			tiempo_ataque_restante = enfriamiento_ataque
			estado = Estado.PERSECUCION if objetivo != null else Estado.PATRULLA
		Estado.HERIDO:
			estado = Estado.PERSECUCION if objetivo != null else Estado.PATRULLA


# ---------- Vida ----------

func recibir_dano(cantidad: int = 1) -> void:
	if estado == Estado.MUERTO:
		return
	vida_actual -= cantidad
	if vida_actual <= 0:
		_morir()
		return
	zona_ataque.set_deferred("monitoring", false)
	estado = Estado.HERIDO
	animacion.play("herido")


func _morir() -> void:
	estado = Estado.MUERTO
	zona_ataque.set_deferred("monitoring", false)
	deteccion.set_deferred("monitoring", false)
	set_deferred("collision_layer", 0)   # ya no se le puede pegar ni estorba
	animacion.play("muerte")
	muerto.emit()


# ---------- Detección del jugador ----------

func _on_deteccion_body_entered(body: Node2D) -> void:
	objetivo = body


func _on_deteccion_body_exited(body: Node2D) -> void:
	if body == objetivo:
		objetivo = null
