extends Node2D

const ROOM_MIN := Vector2(160, 100)
const ROOM_MAX := Vector2(1760, 980)
const BULLET_SPEED := 980.0
const BULLET_LIFETIME := 1.25
const SHOT_COOLDOWN := 0.75
const ENEMY_SPEED := 130.0
const PLAYER_SIZE := Vector2(36, 36)
const ENEMY_SIZE := Vector2(42, 42)
const BULLET_SIZE := Vector2(18, 10)

var shot_timer := 0.0
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var doors_open := false
var ended := false

@onready var player: CharacterBody2D = $Player
@onready var walls_root: Node2D = $Walls
@onready var enemies_root: Node2D = $Enemies
@onready var bullets_root: Node2D = $Bullets
@onready var doors_root: Node2D = $Doors
@onready var hud_label: Label = $CanvasLayer/HUD
@onready var objective_label: Label = $CanvasLayer/Objective

func _ready() -> void:
	player.room_min = ROOM_MIN
	player.room_max = ROOM_MAX
	player.hurt.connect(_on_player_hurt)
	_spawn_walls()
	_spawn_enemies()
	_update_hud()

func _physics_process(delta: float) -> void:
	if ended:
		return
	shot_timer = maxf(0.0, shot_timer - delta)
	_handle_shoot_input()
	_update_bullets(delta)
	_update_enemies(delta)
	_check_enemy_contact()
	_update_hud()

func _handle_shoot_input() -> void:
	if shot_timer > 0.0:
		return
	var direction := Vector2.ZERO
	if Input.is_action_pressed("shoot_left"):
		direction = Vector2.LEFT
	elif Input.is_action_pressed("shoot_right"):
		direction = Vector2.RIGHT
	elif Input.is_action_pressed("shoot_up"):
		direction = Vector2.UP
	elif Input.is_action_pressed("shoot_down"):
		direction = Vector2.DOWN
	if direction == Vector2.ZERO:
		return
	shot_timer = SHOT_COOLDOWN
	_spawn_bullet(direction)

func _spawn_bullet(direction: Vector2) -> void:
	var bullet := ColorRect.new()
	bullet.size = BULLET_SIZE if direction.x != 0.0 else Vector2(BULLET_SIZE.y, BULLET_SIZE.x)
	bullet.position = player.position - bullet.size / 2.0
	bullet.color = Color(1.0, 0.82, 0.24)
	bullets_root.add_child(bullet)
	bullets.append({
		"node": bullet,
		"velocity": direction * BULLET_SPEED,
		"life": BULLET_LIFETIME,
	})

func _update_bullets(delta: float) -> void:
	for i in range(bullets.size() - 1, -1, -1):
		var bullet := bullets[i]
		var node: ColorRect = bullet.node
		bullet.life -= delta
		node.position += bullet.velocity * delta
		if bullet.life <= 0.0 or not _room_rect().has_point(node.position):
			node.queue_free()
			bullets.remove_at(i)
			continue
		if _bullet_hits_wall(node):
			node.queue_free()
			bullets.remove_at(i)
			continue
		var hit_index := _bullet_hit_enemy_index(node)
		if hit_index != -1:
			node.queue_free()
			bullets.remove_at(i)
			_damage_enemy(hit_index)

func _spawn_walls() -> void:
	var walls := [
		Rect2(470, 210, 260, 48),
		Rect2(470, 810, 260, 48),
		Rect2(1190, 210, 260, 48),
		Rect2(1190, 810, 260, 48),
		Rect2(890, 440, 140, 200),
	]
	for wall_rect in walls:
		var wall := ColorRect.new()
		wall.position = wall_rect.position
		wall.size = wall_rect.size
		wall.color = Color(0.34, 0.35, 0.38)
		wall.add_to_group("wall")
		walls_root.add_child(wall)

func _spawn_enemies() -> void:
	var configs := [
		{ "position": Vector2(360, 250), "velocity": Vector2(1, 0.75), "hp": 1 },
		{ "position": Vector2(1450, 280), "velocity": Vector2(-0.8, 1), "hp": 1 },
		{ "position": Vector2(420, 760), "velocity": Vector2(1, -0.9), "hp": 1 },
		{ "position": Vector2(1420, 760), "velocity": Vector2(-1, -0.72), "hp": 2 },
	]
	for config in configs:
		_spawn_enemy(config.position, config.velocity.normalized() * ENEMY_SPEED, config.hp)

func _spawn_enemy(enemy_position: Vector2, enemy_velocity: Vector2, hp: int) -> void:
	var enemy := ColorRect.new()
	enemy.position = enemy_position
	enemy.size = ENEMY_SIZE if hp == 1 else Vector2(58, 58)
	enemy.color = Color(0.78, 0.18, 0.17) if hp == 1 else Color(0.88, 0.32, 0.16)
	enemies_root.add_child(enemy)
	enemies.append({
		"node": enemy,
		"velocity": enemy_velocity,
		"hp": hp,
		"max_hp": hp,
	})

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		var node: ColorRect = enemy.node
		node.position += enemy.velocity * delta
		var rect := Rect2(node.position, node.size)
		var bounced := false
		if rect.position.x <= ROOM_MIN.x or rect.end.x >= ROOM_MAX.x:
			enemy.velocity.x *= -1.0
			bounced = true
		if rect.position.y <= ROOM_MIN.y or rect.end.y >= ROOM_MAX.y:
			enemy.velocity.y *= -1.0
			bounced = true
		if _enemy_hits_wall(node):
			enemy.velocity *= -1.0
			bounced = true
		if bounced:
			node.position.x = clampf(node.position.x, ROOM_MIN.x, ROOM_MAX.x - node.size.x)
			node.position.y = clampf(node.position.y, ROOM_MIN.y, ROOM_MAX.y - node.size.y)

func _check_enemy_contact() -> void:
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for enemy in enemies:
		var node: ColorRect = enemy.node
		if player_rect.intersects(Rect2(node.position, node.size)):
			player.take_hit()
			if not player.is_alive():
				ended = true
				objective_label.text = "取经受阻：按 R 重开"

func _damage_enemy(index: int) -> void:
	var enemy := enemies[index]
	enemy.hp -= 1
	var node: ColorRect = enemy.node
	node.color = Color(1.0, 0.64, 0.24)
	if enemy.hp <= 0:
		node.queue_free()
		enemies.remove_at(index)
		if enemies.is_empty():
			_open_doors()

func _open_doors() -> void:
	if doors_open:
		return
	doors_open = true
	_spawn_door(Vector2(ROOM_MAX.x - 72, (ROOM_MIN.y + ROOM_MAX.y) / 2.0 - 28.0))
	objective_label.text = "妖怪已清：绿色门已开启"

func _spawn_door(door_position: Vector2) -> void:
	var door := ColorRect.new()
	door.position = door_position
	door.size = Vector2(56, 56)
	door.color = Color(0.28, 0.9, 0.42)
	doors_root.add_child(door)

func _bullet_hit_enemy_index(node: ColorRect) -> int:
	var bullet_rect := Rect2(node.position, node.size)
	for i in enemies.size():
		var enemy_node: ColorRect = enemies[i].node
		if bullet_rect.intersects(Rect2(enemy_node.position, enemy_node.size)):
			return i
	return -1

func _bullet_hits_wall(node: ColorRect) -> bool:
	var bullet_rect := Rect2(node.position, node.size)
	for wall in get_tree().get_nodes_in_group("wall"):
		if bullet_rect.intersects(Rect2(wall.position, wall.size)):
			return true
	return false

func _enemy_hits_wall(node: ColorRect) -> bool:
	var enemy_rect := Rect2(node.position, node.size)
	for wall in get_tree().get_nodes_in_group("wall"):
		if enemy_rect.intersects(Rect2(wall.position, wall.size)):
			return true
	return false

func _room_rect() -> Rect2:
	return Rect2(ROOM_MIN, ROOM_MAX - ROOM_MIN)

func _update_hud() -> void:
	var charge := "READY" if shot_timer <= 0.0 else "%.1fs" % shot_timer
	hud_label.text = "HP %d / 妖 %d / 攻击 %s" % [player.health, enemies.size(), charge]
	if not doors_open and not ended:
		objective_label.text = "当前目标：清掉妖怪，开启传送门"

func _on_player_hurt() -> void:
	objective_label.text = "受伤：短暂无敌"
