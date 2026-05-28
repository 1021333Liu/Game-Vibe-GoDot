extends CharacterBody2D

signal hurt

@export var move_speed: float = 420.0
@export var room_min := Vector2(160, 100)
@export var room_max := Vector2(1760, 980)

var health: int = 3
var invincible_time: float = 0.0

@onready var body: ColorRect = $Body

func _physics_process(delta: float) -> void:
	invincible_time = maxf(0.0, invincible_time - delta)
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * move_speed
	move_and_slide()
	global_position.x = clampf(global_position.x, room_min.x + 18.0, room_max.x - 18.0)
	global_position.y = clampf(global_position.y, room_min.y + 18.0, room_max.y - 18.0)

	if invincible_time > 0.0:
		body.modulate.a = 0.55 if int(invincible_time * 12.0) % 2 == 0 else 1.0
	else:
		body.modulate.a = 1.0

func take_hit() -> bool:
	if invincible_time > 0.0:
		return false
	health = max(0, health - 1)
	invincible_time = 1.1
	hurt.emit()
	return true

func is_alive() -> bool:
	return health > 0
