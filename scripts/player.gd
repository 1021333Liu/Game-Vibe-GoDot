extends CharacterBody2D

signal hurt

@export var move_speed: float = 420.0
@export var room_min := Vector2(160, 100)
@export var room_max := Vector2(1760, 980)

var health: int = 3
var invincible_time: float = 0.0
var speed_boost_time: float = 0.0
var speed_boost_multiplier: float = 1.0
var solid_rects: Array[Rect2] = []

@onready var body: ColorRect = $Body

func _physics_process(delta: float) -> void:
	invincible_time = maxf(0.0, invincible_time - delta)
	speed_boost_time = maxf(0.0, speed_boost_time - delta)
	if speed_boost_time <= 0.0:
		speed_boost_multiplier = 1.0
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var previous_position := global_position
	velocity = direction * move_speed * speed_boost_multiplier
	move_and_slide()
	global_position.x = clampf(global_position.x, room_min.x + 18.0, room_max.x - 18.0)
	global_position.y = clampf(global_position.y, room_min.y + 18.0, room_max.y - 18.0)
	_resolve_wall_overlap(previous_position)

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

func apply_speed_boost(duration: float, multiplier: float) -> void:
	speed_boost_time = maxf(speed_boost_time, duration)
	speed_boost_multiplier = maxf(speed_boost_multiplier, multiplier)

func get_speed_boost_time() -> float:
	return speed_boost_time

func set_solid_rects(rects: Array[Rect2]) -> void:
	solid_rects = rects.duplicate()

func _resolve_wall_overlap(previous_position: Vector2) -> void:
	if solid_rects.is_empty():
		return
	var current_position := global_position
	if not _rect_intersects_any(_player_rect_at(current_position)):
		return
	var x_only := Vector2(previous_position.x, current_position.y)
	if not _rect_intersects_any(_player_rect_at(x_only)):
		global_position = x_only
		return
	var y_only := Vector2(current_position.x, previous_position.y)
	if not _rect_intersects_any(_player_rect_at(y_only)):
		global_position = y_only
		return
	global_position = previous_position

func _player_rect_at(center_position: Vector2) -> Rect2:
	return Rect2(center_position - Vector2(18.0, 18.0), Vector2(36.0, 36.0))

func _rect_intersects_any(rect: Rect2) -> bool:
	for solid in solid_rects:
		if rect.intersects(solid):
			return true
	return false
