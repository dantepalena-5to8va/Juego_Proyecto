extends Area2D

@export var velocidad: float = 500.0
@export var dano: int = 1

func _ready():
	pass
	$VisibleOnScreenNotifier2D.screen_exited.connect(queue_free)
	body_entered.connect(_on_body_entered)

func _physics_process(delta: float):
	position += transform.x * velocidad * delta

func _on_body_entered(body: Node):
	if body.has_method("recibir_dano"):
		body.recibir_dano(dano)
	queue_free()
