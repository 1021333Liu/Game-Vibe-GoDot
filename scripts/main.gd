extends Node2D

const ROOM_MIN := Vector2(160, 100)
const ROOM_MAX := Vector2(1760, 980)
const BULLET_SPEED := 980.0
const BULLET_LIFETIME := 1.25
const BASE_SHOT_COOLDOWN := 0.75
const BOOSTED_SHOT_COOLDOWN := 0.38
const SHOT_BOOST_DURATION := 7.0
const ENEMY_SPEED := 130.0
const PLAYER_SIZE := Vector2(36, 36)
const ENEMY_SIZE := Vector2(42, 42)
const BULLET_SIZE := Vector2(18, 10)
const PICKUP_SIZE := Vector2(30, 30)
const HIT_FLASH_TIME := 0.16
const HIT_KNOCKBACK := 260.0
const ENEMY_COLOR := Color(0.78, 0.18, 0.17)
const ELITE_COLOR := Color(0.88, 0.32, 0.16)
const LOCKED_EXIT_COLOR := Color(0.15, 0.18, 0.2)
const OPEN_EXIT_COLOR := Color(0.28, 0.9, 0.42)

var shot_timer := 0.0
var shot_boost_timer := 0.0
var message_timer := 0.0
var room_message := ""
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var doors_open := false
var ended := false
var room_complete := false
var run_complete := false
var current_room_index := 0
var room_templates: Array[Dictionary] = []
var room_pools: Dictionary = {}
var started := false
var paused := false
var shot_meter_fill: ColorRect

@onready var player: CharacterBody2D = $Player
@onready var room_border: Node2D = $RoomBorder
@onready var walls_root: Node2D = $Walls
@onready var enemies_root: Node2D = $Enemies
@onready var bullets_root: Node2D = $Bullets
@onready var doors_root: Node2D = $Doors
@onready var exit_hint: ColorRect = $ExitHint
@onready var exit_label: Label = $ExitHint/ExitLabel
@onready var hud_label: Label = $CanvasLayer/HUD
@onready var objective_label: Label = $CanvasLayer/Objective
@onready var hud_panel: ColorRect = $CanvasLayer/HUDPanel
@onready var hud_accent: ColorRect = $CanvasLayer/HUDAccent
@onready var objective_panel: ColorRect = $CanvasLayer/ObjectivePanel
@onready var door_status_accent: ColorRect = $CanvasLayer/DoorStatusAccent
@onready var room_info_panel: ColorRect = $CanvasLayer/RoomInfoPanel
@onready var room_info_accent: ColorRect = $CanvasLayer/RoomInfoAccent
@onready var room_title_label: Label = $CanvasLayer/RoomTitle
@onready var room_progress_label: Label = $CanvasLayer/RoomProgress
@onready var room_hint_label: Label = $CanvasLayer/RoomHint
@onready var room_lore_label: Label = $CanvasLayer/RoomLore
@onready var start_overlay: ColorRect = $CanvasLayer/StartOverlay
@onready var pause_overlay: ColorRect = $CanvasLayer/PauseOverlay

func _ready() -> void:
	randomize()
	player.room_min = ROOM_MIN
	player.room_max = ROOM_MAX
	player.hurt.connect(_on_player_hurt)
	_draw_room_border()
	room_pools = _build_room_pools()
	room_templates = _build_room_route()
	_spawn_shot_meter()
	_load_room(0, true)
	_set_ui_running_state(false)
	_update_hud()

func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	if not started or paused:
		return
	if ended:
		return
	shot_timer = maxf(0.0, shot_timer - delta)
	shot_boost_timer = maxf(0.0, shot_boost_timer - delta)
	message_timer = maxf(0.0, message_timer - delta)
	_handle_shoot_input()
	_update_bullets(delta)
	_update_enemies(delta)
	_update_pickups(delta)
	_check_pickup_contact()
	_check_enemy_contact()
	_check_door_contact()
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
	shot_timer = _current_shot_cooldown()
	_spawn_bullet(direction)

func _spawn_bullet(direction: Vector2) -> void:
	var bullet := ColorRect.new()
	bullet.size = BULLET_SIZE if direction.x != 0.0 else Vector2(BULLET_SIZE.y, BULLET_SIZE.x)
	bullet.position = player.position - bullet.size / 2.0
	bullet.color = Color(0.58, 0.9, 1.0) if shot_boost_timer > 0.0 else Color(1.0, 0.82, 0.24)
	bullets_root.add_child(bullet)
	bullets.append({
		"node": bullet,
		"velocity": direction * _current_bullet_speed(),
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
			_damage_enemy(hit_index, bullet.velocity.normalized())

func _spawn_walls(walls: Array) -> void:
	for wall_rect in walls:
		var wall := ColorRect.new()
		wall.position = wall_rect.position
		wall.size = wall_rect.size
		wall.color = Color(0.34, 0.35, 0.38)
		wall.add_to_group("wall")
		walls_root.add_child(wall)

func _spawn_enemies(configs: Array) -> void:
	for config in configs:
		_spawn_enemy(config.position, config.velocity.normalized() * ENEMY_SPEED, config.hp)

func _spawn_enemy(enemy_position: Vector2, enemy_velocity: Vector2, hp: int) -> void:
	var enemy := ColorRect.new()
	enemy.position = enemy_position
	enemy.size = ENEMY_SIZE if hp == 1 else Vector2(58, 58)
	var base_color := ENEMY_COLOR if hp == 1 else ELITE_COLOR
	enemy.color = base_color
	var hp_back := ColorRect.new()
	hp_back.name = "HpBack"
	hp_back.position = Vector2(0.0, -10.0)
	hp_back.size = Vector2(enemy.size.x, 5.0)
	hp_back.color = Color(0.02, 0.025, 0.03, 0.9)
	enemy.add_child(hp_back)
	var hp_fill := ColorRect.new()
	hp_fill.name = "HpFill"
	hp_fill.size = hp_back.size
	hp_fill.color = Color(0.95, 0.22, 0.18)
	hp_back.add_child(hp_fill)
	enemies_root.add_child(enemy)
	var enemy_state := {
		"node": enemy,
		"velocity": enemy_velocity,
		"hp": hp,
		"max_hp": hp,
		"base_color": base_color,
		"hit_flash": 0.0,
		"hp_fill": hp_fill,
	}
	enemies.append(enemy_state)
	_update_enemy_status(enemy_state)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		var node: ColorRect = enemy.node
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		node.color = Color(1.0, 0.92, 0.62) if enemy.hit_flash > 0.0 else enemy.base_color
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

func _damage_enemy(index: int, hit_direction: Vector2) -> void:
	var enemy := enemies[index]
	enemy.hp -= 1
	var node: ColorRect = enemy.node
	enemy.hit_flash = HIT_FLASH_TIME
	enemy.velocity = (enemy.velocity + hit_direction * HIT_KNOCKBACK).limit_length(ENEMY_SPEED * 1.9)
	if enemy.hp <= 0:
		_spawn_pickup(node.position + node.size / 2.0)
		node.queue_free()
		enemies.remove_at(index)
		_show_room_message("妖怪退散：掉落定风珠", 1.5)
		if enemies.is_empty():
			_open_doors()
	else:
		_update_enemy_status(enemy)
		_show_room_message("命中：妖怪被击退", 0.8)

func _spawn_pickup(center_position: Vector2) -> void:
	var pickup := ColorRect.new()
	pickup.size = PICKUP_SIZE
	pickup.position = center_position - PICKUP_SIZE / 2.0
	pickup.color = Color(0.2, 0.68, 1.0)
	pickup.add_to_group("pickup")
	add_child(pickup)
	pickups.append({
		"node": pickup,
		"life": 9.0,
	})

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		var node: ColorRect = pickup.node
		pickup.life -= delta
		node.modulate.a = 0.45 if pickup.life < 2.0 and int(pickup.life * 10.0) % 2 == 0 else 1.0
		if pickup.life <= 0.0:
			node.queue_free()
			pickups.remove_at(i)

func _check_pickup_contact() -> void:
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		var node: ColorRect = pickup.node
		if player_rect.intersects(Rect2(node.position, node.size)):
			shot_boost_timer = SHOT_BOOST_DURATION
			shot_timer = minf(shot_timer, BOOSTED_SHOT_COOLDOWN)
			_show_room_message("拾取定风珠：%.0f 秒内弹速提升" % SHOT_BOOST_DURATION, 1.8)
			node.queue_free()
			pickups.remove_at(i)

func _open_doors() -> void:
	if doors_open:
		return
	doors_open = true
	_set_exit_open()
	_spawn_door(Vector2(ROOM_MAX.x - 72, (ROOM_MIN.y + ROOM_MAX.y) / 2.0 - 28.0))
	_show_room_message("房间已净：绿色传送门开启", 3.0)

func _spawn_door(door_position: Vector2) -> void:
	var door := ColorRect.new()
	door.position = door_position
	door.size = Vector2(56, 56)
	door.color = OPEN_EXIT_COLOR
	doors_root.add_child(door)

func _check_door_contact() -> void:
	if not doors_open or room_complete or run_complete:
		return
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for door in doors_root.get_children():
		if player_rect.intersects(Rect2(door.position, door.size)):
			room_complete = true
			var next_room_index := current_room_index + 1
			if next_room_index >= room_templates.size():
				run_complete = true
				ended = true
				_show_room_message("%d 房路线已通关：按 R 重开" % room_templates.size(), 999.0)
			else:
				_load_room(next_room_index, false)

func _set_exit_locked() -> void:
	exit_hint.color = LOCKED_EXIT_COLOR
	exit_label.text = "封印中"
	var door_status := get_node_or_null("CanvasLayer/DoorStatus")
	if door_status is Label:
		door_status.text = "封印中"
		door_status.add_theme_color_override("font_color", Color(0.83, 0.87, 0.9))
	door_status_accent.color = Color(0.5, 0.57, 0.62, 1)
	hud_accent.color = Color(0.95, 0.68, 0.18, 1)
	objective_panel.color = Color(0.12, 0.14, 0.15, 0.82)

func _set_exit_open() -> void:
	exit_hint.color = OPEN_EXIT_COLOR
	exit_label.text = "已开启"
	var door_status := get_node_or_null("CanvasLayer/DoorStatus")
	if door_status is Label:
		door_status.text = "已开启"
		door_status.add_theme_color_override("font_color", OPEN_EXIT_COLOR)
	door_status_accent.color = Color(0.33, 0.82, 0.46, 1)
	hud_accent.color = Color(0.34, 0.84, 0.48, 1)
	objective_panel.color = Color(0.1, 0.18, 0.13, 0.86)

func _update_enemy_status(enemy: Dictionary) -> void:
	var hp_fill: ColorRect = enemy.hp_fill
	var node: ColorRect = enemy.node
	var hp_ratio := clampf(float(enemy.hp) / float(enemy.max_hp), 0.0, 1.0)
	hp_fill.size.x = node.size.x * hp_ratio
	hp_fill.visible = enemy.max_hp > 1 or enemy.hp < enemy.max_hp

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

func _spawn_shot_meter() -> void:
	var meter_back := ColorRect.new()
	meter_back.position = Vector2(32, 118)
	meter_back.size = Vector2(240, 12)
	meter_back.color = Color(0.1, 0.12, 0.15)
	$CanvasLayer.add_child(meter_back)

	shot_meter_fill = ColorRect.new()
	shot_meter_fill.position = meter_back.position
	shot_meter_fill.size = meter_back.size
	shot_meter_fill.color = Color(0.36, 0.92, 0.48)
	$CanvasLayer.add_child(shot_meter_fill)

func _current_shot_cooldown() -> float:
	return BOOSTED_SHOT_COOLDOWN if shot_boost_timer > 0.0 else BASE_SHOT_COOLDOWN

func _current_bullet_speed() -> float:
	return BULLET_SPEED * 1.25 if shot_boost_timer > 0.0 else BULLET_SPEED

func _show_room_message(message: String, duration: float) -> void:
	room_message = message
	message_timer = duration
	objective_label.text = room_message

func _clear_node_children(node: Node) -> void:
	for child in node.get_children():
		child.queue_free()

func _clone_room_template(room_template: Dictionary) -> Dictionary:
	return {
		"id": room_template.id,
		"name": room_template.name,
		"hint": room_template.hint if room_template.has("hint") else "",
		"lore": room_template.lore if room_template.has("lore") else "",
		"walls": room_template.walls.duplicate(true),
		"enemies": room_template.enemies.duplicate(true),
		"type": room_template.type,
	}

func _pick_room_from_pool(pool: Array, avoid_id: String = "") -> Dictionary:
	if pool.is_empty():
		return {}
	var picked: Dictionary = pool[randi() % pool.size()]
	if pool.size() > 1 and avoid_id != "":
		var guard := 0
		while picked.id == avoid_id and guard < 6:
			picked = pool[randi() % pool.size()]
			guard += 1
	return _clone_room_template(picked)

func _build_room_pools() -> Dictionary:
	return {
		"combat": [
			{
				"id": "combat_bridge",
				"hint": "清怪破印，稳住推进",
				"lore": "黄沙扑地，风声催人快行",
				"name": "流沙河浅滩",
				"type": "combat",
				"walls": [
					Rect2(470, 210, 260, 48),
					Rect2(470, 810, 260, 48),
					Rect2(1190, 210, 260, 48),
					Rect2(1190, 810, 260, 48),
					Rect2(890, 440, 140, 200),
				],
				"enemies": [
					{ "position": Vector2(360, 250), "velocity": Vector2(1, 0.75), "hp": 1 },
					{ "position": Vector2(1450, 280), "velocity": Vector2(-0.8, 1), "hp": 1 },
					{ "position": Vector2(420, 760), "velocity": Vector2(1, -0.9), "hp": 1 },
					{ "position": Vector2(1420, 760), "velocity": Vector2(-1, -0.72), "hp": 2 },
				],
			},
			{
				"id": "combat_bone",
				"hint": "绕开夹击，逐个击破",
				"lore": "残碑无言，阴火仍在摇曳",
				"name": "白骨岭荒庭",
				"type": "combat",
				"walls": [
					Rect2(520, 250, 190, 42),
					Rect2(1210, 250, 190, 42),
					Rect2(520, 788, 190, 42),
					Rect2(1210, 788, 190, 42),
					Rect2(900, 350, 120, 380),
				],
				"enemies": [
					{ "position": Vector2(360, 380), "velocity": Vector2(1, 0.6), "hp": 1 },
					{ "position": Vector2(1470, 360), "velocity": Vector2(-1, 0.66), "hp": 1 },
					{ "position": Vector2(400, 700), "velocity": Vector2(0.9, -0.9), "hp": 1 },
					{ "position": Vector2(1450, 710), "velocity": Vector2(-0.8, -0.92), "hp": 1 },
				],
			},
		],
		"elite": [
			{
				"id": "elite_default",
				"hint": "先身法，再集火首领",
				"lore": "鼓声沉闷，妖将守在险口",
				"name": "精英前哨",
				"type": "elite",
				"walls": [
					Rect2(360, 300, 220, 44),
					Rect2(360, 720, 220, 44),
					Rect2(1340, 300, 220, 44),
					Rect2(1340, 720, 220, 44),
					Rect2(840, 300, 240, 56),
					Rect2(840, 724, 240, 56),
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(1, 0.4), "hp": 4 },
					{ "position": Vector2(560, 500), "velocity": Vector2(1, -0.7), "hp": 1 },
					{ "position": Vector2(1320, 520), "velocity": Vector2(-1, 0.75), "hp": 1 },
				],
			},
			{
				"id": "elite_fire_cloud",
				"hint": "横移拉扯，别贴墙角",
				"lore": "火光跳动，热浪逼人难久停",
				"name": "火云洞前殿",
				"type": "elite",
				"walls": [
					Rect2(360, 250, 160, 44),
					Rect2(1400, 250, 160, 44),
					Rect2(360, 786, 160, 44),
					Rect2(1400, 786, 160, 44),
					Rect2(760, 520, 120, 44),
					Rect2(1040, 520, 120, 44),
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(1, 0.25), "hp": 5 },
					{ "position": Vector2(650, 420), "velocity": Vector2(0.9, -0.95), "hp": 2 },
					{ "position": Vector2(1270, 620), "velocity": Vector2(-0.9, 0.95), "hp": 2 },
				],
			},
			{
				"id": "elite_jindou",
				"hint": "利用中路空档穿行",
				"lore": "金光回旋，慢半拍便受困",
				"name": "金兜洞外环",
				"type": "elite",
				"walls": [
					Rect2(500, 300, 920, 34),
					Rect2(500, 746, 920, 34),
					Rect2(730, 420, 120, 220),
					Rect2(1070, 420, 120, 220),
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(0.9, 0.58), "hp": 4 },
					{ "position": Vector2(620, 520), "velocity": Vector2(1, -0.58), "hp": 2 },
					{ "position": Vector2(1300, 520), "velocity": Vector2(-1, 0.58), "hp": 2 },
				],
			},
		],
		"rest": [
			{
				"id": "rest_calm",
				"hint": "补给整顿，准备下一关",
				"lore": "灯火微明，片刻安宁亦是修行",
				"name": "宝物休整",
				"type": "rest",
				"walls": [
					Rect2(620, 300, 120, 40),
					Rect2(1180, 300, 120, 40),
					Rect2(620, 740, 120, 40),
					Rect2(1180, 740, 120, 40),
				],
				"enemies": [],
			},
			{
				"id": "rest_dragon",
				"hint": "记好出口方位，再起程",
				"lore": "水影浮金，深宫回响如潮声",
				"name": "龙宫偏殿",
				"type": "rest",
				"walls": [
					Rect2(500, 280, 200, 40),
					Rect2(1220, 280, 200, 40),
					Rect2(500, 760, 200, 40),
					Rect2(1220, 760, 200, 40),
					Rect2(900, 420, 120, 220),
				],
				"enemies": [],
			},
		],
	}

func _build_room_route() -> Array[Dictionary]:
	var route: Array[Dictionary] = []
	var target_rooms := 4 + (randi() % 2)
	var last_combat_id := ""
	route.append(_pick_room_from_pool(room_pools.combat, last_combat_id))
	last_combat_id = route[route.size() - 1].id
	if target_rooms == 5:
		route.append(_pick_room_from_pool(room_pools.combat, last_combat_id))
		last_combat_id = route[route.size() - 1].id
	route.append(_pick_room_from_pool(room_pools.elite))
	route.append(_pick_room_from_pool(room_pools.combat, last_combat_id))
	route.append(_pick_room_from_pool(room_pools.rest))
	return route

func _load_room(room_index: int, is_first_room: bool) -> void:
	current_room_index = clampi(room_index, 0, max(0, room_templates.size() - 1))
	if is_first_room:
		run_complete = false
	room_complete = false
	ended = false
	doors_open = false
	message_timer = 0.0
	room_message = ""
	bullets.clear()
	enemies.clear()
	pickups.clear()
	_clear_node_children(bullets_root)
	_clear_node_children(enemies_root)
	_clear_node_children(doors_root)
	_clear_node_children(walls_root)
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.queue_free()
	_set_exit_locked()
	var room_config := room_templates[current_room_index]
	_update_room_info_panel(room_config)
	_spawn_walls(room_config.walls)
	_spawn_enemies(room_config.enemies)
	player.global_position = Vector2(ROOM_MIN.x + 88.0, (ROOM_MIN.y + ROOM_MAX.y) * 0.5)
	if room_config.enemies.is_empty():
		_open_doors()
	var prefix := "进入" if is_first_room else "抵达"
	_show_room_message("%s：%s (%d/%d)" % [prefix, room_config.name, current_room_index + 1, room_templates.size()], 2.0)

func _update_hud() -> void:
	var cooldown := _current_shot_cooldown()
	var charge_ratio := 1.0 - clampf(shot_timer / cooldown, 0.0, 1.0)
	var charge := "READY" if shot_timer <= 0.0 else "%d%%" % roundi(charge_ratio * 100.0)
	var boost := " / 定风珠 %.0fs" % shot_boost_timer if shot_boost_timer > 0.0 else ""
	hud_label.text = "HP %d / 妖怪 %d / 攻击 %s%s" % [player.health, enemies.size(), charge, boost]
	if shot_meter_fill != null:
		shot_meter_fill.size.x = 240.0 * charge_ratio
		shot_meter_fill.color = Color(0.36, 0.92, 0.48) if shot_timer <= 0.0 else Color(1.0, 0.76, 0.25)
	if message_timer > 0.0:
		objective_label.text = room_message
	elif not doors_open and not ended:
		objective_label.text = "清空房间。蓝色掉落会短暂强化弹道。"
	elif doors_open and not ended:
		objective_label.text = "房间已净，进入绿色传送门。"

func _on_player_hurt() -> void:
	_show_room_message("受伤：短暂无敌", 1.2)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER and not started:
			_start_run()
			return
		if event.keycode == KEY_P and started and not ended:
			_set_paused_state(not paused)

func _draw_room_border() -> void:
	var outer := ColorRect.new()
	outer.position = ROOM_MIN - Vector2(14, 14)
	outer.size = (ROOM_MAX - ROOM_MIN) + Vector2(28, 28)
	outer.color = Color(0.24, 0.18, 0.12, 0.92)
	room_border.add_child(outer)
	var inner := ColorRect.new()
	inner.position = ROOM_MIN - Vector2(8, 8)
	inner.size = (ROOM_MAX - ROOM_MIN) + Vector2(16, 16)
	inner.color = Color(0.43, 0.3, 0.16, 0.9)
	room_border.add_child(inner)

func _set_ui_running_state(running: bool) -> void:
	start_overlay.visible = not running
	hud_panel.visible = running
	hud_accent.visible = running
	objective_panel.visible = running
	$CanvasLayer/HUD.visible = running
	$CanvasLayer/Objective.visible = running
	$CanvasLayer/DoorStatusPanel.visible = running
	$CanvasLayer/DoorStatusTitle.visible = running
	$CanvasLayer/DoorStatus.visible = running
	$CanvasLayer/DoorStatusAccent.visible = running
	room_info_panel.visible = running
	room_info_accent.visible = running
	room_title_label.visible = running
	room_progress_label.visible = running
	room_hint_label.visible = running
	room_lore_label.visible = running
	$ExitHint.visible = running

func _start_run() -> void:
	started = true
	paused = false
	_set_ui_running_state(true)
	_set_paused_state(false)
	_show_room_message("试炼开始：清空房间，破除封印。", 1.6)

func _set_paused_state(value: bool) -> void:
	paused = value
	pause_overlay.visible = paused

func _update_room_info_panel(room_config: Dictionary) -> void:
	var room_name := String(room_config.get("name", "未知试炼"))
	var room_hint := String(room_config.get("hint", "清怪破印，稳住推进"))
	var room_lore := String(room_config.get("lore", "古道漫漫，心定则路明"))
	room_title_label.text = "试炼：%s" % room_name
	room_progress_label.text = "进度 %d / %d" % [current_room_index + 1, room_templates.size()]
	room_hint_label.text = "说明：%s" % room_hint
	room_lore_label.text = "短句：%s" % room_lore
	room_info_accent.color = Color(0.74, 0.56, 0.24, 1)
