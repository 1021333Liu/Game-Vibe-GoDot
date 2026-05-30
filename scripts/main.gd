extends Node2D

const ROOM_MIN := Vector2(160, 100)
const ROOM_MAX := Vector2(1760, 980)
const BULLET_SPEED := 980.0
const BULLET_LIFETIME := 1.25
const BASE_SHOT_COOLDOWN := 0.75
const MELEE_COOLDOWN := 0.54
const BOOSTED_SHOT_COOLDOWN := 0.42
const SHOT_BOOST_DURATION := 5.5
const WIND_SHOT_CHARGES := 6
const SPEED_BOOST_DURATION := 7.0
const SPEED_BOOST_MULTIPLIER := 1.3
const ENEMY_SPEED := 130.0
const PLAYER_SIZE := Vector2(36, 36)
const ENEMY_SIZE := Vector2(42, 42)
const BULLET_SIZE := Vector2(18, 10)
const PICKUP_SIZE := Vector2(30, 30)
const MELEE_RANGE := 76.0
const MELEE_WIDTH := 88.0
const MELEE_LIFETIME := 0.13
const MELEE_TRAIL_LIFETIME := 0.09
const MELEE_SLASH_WIDTH := 13.0
const HIT_FLASH_TIME := 0.16
const HIT_BURST_LIFETIME := 0.2
const MELEE_HIT_KNOCKBACK := 330.0
const RANGED_HIT_KNOCKBACK := 210.0
const SPAWN_SAFETY_PADDING := 28.0
const NORMAL_PICKUP_DROP_CHANCE := 0.18
const ELITE_PICKUP_DROP_CHANCE := 0.42
const BOSS_PICKUP_DROP_CHANCE := 1.0
const HAZARD_CONTACT_COOLDOWN := 0.95
const EARLY_ROOM_COUNT := 3
const LATE_ROOM_SPEED_STEP := 0.06
const BOSS_ROOM_SPEED_BONUS := 0.08
const LATE_ROOM_HP_STEP := 1
const ENEMY_CHASE_STEER := 90.0
const ENEMY_WANDER_STEER := 34.0
const ELITE_RUSH_INTERVAL := 3.2
const ELITE_RUSH_DURATION := 0.85
const ELITE_RUSH_SCALE := 1.85
const BOSS_ACTION_INTERVAL := 3.05
const BOSS_CHARGE_DURATION := 0.7
const BOSS_CHARGE_SCALE := 2.15
const BOSS_SUMMON_LIMIT := 4
const ENEMY_COLOR := Color(0.78, 0.18, 0.17)
const ELITE_COLOR := Color(0.88, 0.32, 0.16)
const LOCKED_EXIT_COLOR := Color(0.15, 0.18, 0.2)
const OPEN_EXIT_COLOR := Color(0.28, 0.9, 0.42)
const PLAYER_ART_PATH := "res://assets/player_monk.svg"
const ENEMY_ART_PATH := "res://assets/enemy_imp.svg"
const ELITE_ART_PATH := "res://assets/enemy_elite.svg"
const BOSS_ART_PATH := "res://assets/boss_blackwind.svg"
const GATE_ART_PATH := "res://assets/gate_green.svg"
const PICKUP_SHOT_ART_PATH := "res://assets/pickup_shot.svg"
const PICKUP_SPEED_ART_PATH := "res://assets/pickup_speed.svg"
const PICKUP_SHIELD_ART_PATH := "res://assets/pickup_shield.svg"

var shot_timer := 0.0
var shot_boost_timer := 0.0
var wind_shot_charges := 0
var message_timer := 0.0
var room_message := ""
var enemies: Array[Dictionary] = []
var bullets: Array[Dictionary] = []
var melee_effects: Array[Dictionary] = []
var slash_trails: Array[Dictionary] = []
var hit_bursts: Array[Dictionary] = []
var pickups: Array[Dictionary] = []
var hazards: Array[Dictionary] = []
var solid_wall_rects: Array[Rect2] = []
var doors_open := false
var ended := false
var room_complete := false
var run_complete := false
var current_room_index := 0
var current_room_type := "combat"
var room_templates: Array[Dictionary] = []
var room_pools: Dictionary = {}
var started := false
var paused := false
var room_reward_granted := false
var clear_reward_stacks := 0
var shield_charges := 0
var last_reward_name := "无"
var collected_rewards: Array[String] = []
var run_time := 0.0
var pickup_cue_timer := 0.0
var hazard_contact_timer := 0.0
var shot_meter_fill: ColorRect
var art_textures: Dictionary = {}
var room_spawn_guard_index := 0
var last_facing := Vector2.RIGHT
var weapon_pivot: Node2D
var weapon_line: Line2D
var weapon_swing_timer := 0.0

@onready var player: CharacterBody2D = $Player
@onready var room_border: Node2D = $RoomBorder
@onready var walls_root: Node2D = $Walls
@onready var enemies_root: Node2D = $Enemies
@onready var bullets_root: Node2D = $Bullets
@onready var doors_root: Node2D = $Doors
@onready var exit_hint: ColorRect = $ExitHint
@onready var exit_label: Label = $ExitHint/ExitLabel
@onready var hud_label: Label = $CanvasLayer/HUD
@onready var hud_hp_cell: ColorRect = $CanvasLayer/HudHpCell
@onready var hud_hp_value: Label = $CanvasLayer/HudHpValue
@onready var hud_enemy_value: Label = $CanvasLayer/HudEnemyValue
@onready var hud_attack_cell: ColorRect = $CanvasLayer/HudAttackCell
@onready var hud_attack_value: Label = $CanvasLayer/HudAttackValue
@onready var hud_reward_icon: TextureRect = $CanvasLayer/HudRewardIcon
@onready var hud_reward_value: Label = $CanvasLayer/HudRewardValue
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
@onready var route_panel: ColorRect = $CanvasLayer/RoutePanel
@onready var route_accent: ColorRect = $CanvasLayer/RouteAccent
@onready var route_map_root: Control = $CanvasLayer/RouteMapRoot
@onready var route_preview_label: Label = $CanvasLayer/RoutePreview
@onready var complete_overlay: ColorRect = $CanvasLayer/CompleteOverlay
@onready var complete_summary_label: Label = $CanvasLayer/CompleteOverlay/CompletePanel/CompleteSummary
@onready var complete_route_label: Label = $CanvasLayer/CompleteOverlay/CompletePanel/CompleteRoute
@onready var complete_loot_label: Label = $CanvasLayer/CompleteOverlay/CompletePanel/CompleteLoot
@onready var reward_panel: ColorRect = $CanvasLayer/RewardPanel
@onready var reward_accent: ColorRect = $CanvasLayer/RewardAccent
@onready var reward_name_label: Label = $CanvasLayer/RewardName
@onready var reward_effect_label: Label = $CanvasLayer/RewardEffect
@onready var reward_state_label: Label = $CanvasLayer/RewardState
@onready var loot_panel: ColorRect = $CanvasLayer/LootPanel
@onready var loot_title_label: Label = $CanvasLayer/LootTitle
@onready var loot_list_label: Label = $CanvasLayer/LootList
@onready var combat_panel: ColorRect = $CanvasLayer/CombatPanel
@onready var combat_accent: ColorRect = $CanvasLayer/CombatAccent
@onready var combat_mode_label: Label = $CanvasLayer/CombatMode
@onready var combat_detail_label: Label = $CanvasLayer/CombatDetail
@onready var choice_panel: ColorRect = $CanvasLayer/ChoicePanel
@onready var choice_accent: ColorRect = $CanvasLayer/ChoiceAccent
@onready var choice_text_label: Label = $CanvasLayer/ChoiceText
@onready var encounter_panel: ColorRect = $CanvasLayer/EncounterPanel
@onready var encounter_accent: ColorRect = $CanvasLayer/EncounterAccent
@onready var encounter_type_label: Label = $CanvasLayer/EncounterType
@onready var encounter_hint_label: Label = $CanvasLayer/EncounterHint
@onready var run_state_panel: ColorRect = $CanvasLayer/RunStatePanel
@onready var run_state_accent: ColorRect = $CanvasLayer/RunStateAccent
@onready var run_state_tag_label: Label = $CanvasLayer/RunStateTag
@onready var run_state_phase_label: Label = $CanvasLayer/RunStatePhase
@onready var pickup_cue_label: Label = $CanvasLayer/PickupCue
@onready var start_overlay: ColorRect = $CanvasLayer/StartOverlay
@onready var pause_overlay: ColorRect = $CanvasLayer/PauseOverlay
@onready var background_rect: ColorRect = $Background
@onready var room_frame_rect: ColorRect = $RoomFrame

func _ready() -> void:
	randomize()
	_load_art_textures()
	player.room_min = ROOM_MIN
	player.room_max = ROOM_MAX
	player.hurt.connect(_on_player_hurt)
	_attach_art(player.get_node("Body"), "player")
	_spawn_player_weapon_visual()
	_draw_room_border()
	room_pools = _build_room_pools()
	room_templates = _build_curated_room_route()
	_spawn_shot_meter()
	_update_route_preview()
	_load_room(0, true)
	_set_ui_running_state(false)
	_update_reward_panel()
	_update_reward_icon()
	_update_choice_status()
	_update_run_state_banner("待战")
	_update_hud()

func _physics_process(delta: float) -> void:
	if Input.is_key_pressed(KEY_R):
		get_tree().reload_current_scene()
	if not started or paused:
		return
	if ended:
		return
	run_time += delta
	shot_timer = maxf(0.0, shot_timer - delta)
	shot_boost_timer = maxf(0.0, shot_boost_timer - delta)
	message_timer = maxf(0.0, message_timer - delta)
	pickup_cue_timer = maxf(0.0, pickup_cue_timer - delta)
	hazard_contact_timer = maxf(0.0, hazard_contact_timer - delta)
	_update_player_weapon_visual(delta)
	_handle_shoot_input()
	_update_bullets(delta)
	_update_melee_effects(delta)
	_update_slash_trails(delta)
	_update_hit_bursts(delta)
	_update_enemies(delta)
	_update_hazards(delta)
	_update_pickups(delta)
	_check_pickup_contact()
	_check_hazard_contact()
	_check_enemy_contact()
	_check_door_contact()
	_update_pickup_cue_visibility()
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
	last_facing = direction
	_start_weapon_swing()
	shot_timer = _current_shot_cooldown()
	if _can_fire_wind_shot():
		_spawn_bullet(direction)
		wind_shot_charges -= 1
		if wind_shot_charges <= 0:
			shot_boost_timer = 0.0
			_show_room_message("定风珠灵力已尽：回到近战", 1.1)
	else:
		_spawn_melee_attack(direction)

func _spawn_melee_attack(direction: Vector2) -> void:
	var slash := Line2D.new()
	slash.width = MELEE_SLASH_WIDTH
	slash.default_color = Color(1.0, 0.82, 0.28, 0.82)
	slash.joint_mode = Line2D.LINE_JOINT_ROUND
	slash.begin_cap_mode = Line2D.LINE_CAP_ROUND
	slash.end_cap_mode = Line2D.LINE_CAP_ROUND
	slash.position = player.position
	slash.points = _build_slash_points(direction)
	bullets_root.add_child(slash)
	_spawn_slash_trail(slash.position, slash.points, slash.default_color)
	melee_effects.append({
		"node": slash,
		"life": MELEE_LIFETIME,
	})
	_damage_enemies_in_melee(_get_melee_rect(direction), direction)

func _get_melee_rect(direction: Vector2) -> Rect2:
	var horizontal := absf(direction.x) > 0.0
	var size := Vector2(MELEE_RANGE, MELEE_WIDTH) if horizontal else Vector2(MELEE_WIDTH, MELEE_RANGE)
	var offset := Vector2(direction.x * (PLAYER_SIZE.x * 0.5 + size.x * 0.5), direction.y * (PLAYER_SIZE.y * 0.5 + size.y * 0.5))
	return Rect2(player.position + offset - size / 2.0, size)

func _build_slash_points(direction: Vector2) -> PackedVector2Array:
	var forward := direction.normalized()
	var side := Vector2(-forward.y, forward.x)
	var center := forward * (PLAYER_SIZE.x * 0.45 + MELEE_RANGE * 0.45)
	return PackedVector2Array([
		center - side * (MELEE_WIDTH * 0.42) - forward * 8.0,
		center + side * (MELEE_WIDTH * 0.06) + forward * 10.0,
		center + side * (MELEE_WIDTH * 0.42) - forward * 6.0,
	])

func _damage_enemies_in_melee(melee_rect: Rect2, direction: Vector2) -> void:
	var hit_indices: Array[int] = []
	for i in enemies.size():
		var enemy_node: ColorRect = enemies[i].node
		if melee_rect.intersects(Rect2(enemy_node.position, enemy_node.size)):
			hit_indices.append(i)
	for i in range(hit_indices.size() - 1, -1, -1):
		_damage_enemy(hit_indices[i], direction, true)

func _update_melee_effects(delta: float) -> void:
	for i in range(melee_effects.size() - 1, -1, -1):
		var effect := melee_effects[i]
		var node: CanvasItem = effect.node
		effect.life -= delta
		if is_instance_valid(node):
			node.modulate.a = clampf(effect.life / MELEE_LIFETIME, 0.0, 1.0)
		if effect.life <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			melee_effects.remove_at(i)

func _spawn_slash_trail(origin: Vector2, points: PackedVector2Array, slash_color: Color) -> void:
	var trail := Line2D.new()
	trail.width = MELEE_SLASH_WIDTH * 0.62
	trail.default_color = Color(slash_color.r, slash_color.g, slash_color.b, 0.45)
	trail.joint_mode = Line2D.LINE_JOINT_ROUND
	trail.begin_cap_mode = Line2D.LINE_CAP_ROUND
	trail.end_cap_mode = Line2D.LINE_CAP_ROUND
	trail.position = origin + last_facing * 5.0
	trail.points = points
	bullets_root.add_child(trail)
	slash_trails.append({
		"node": trail,
		"life": MELEE_TRAIL_LIFETIME,
	})

func _update_slash_trails(delta: float) -> void:
	for i in range(slash_trails.size() - 1, -1, -1):
		var trail := slash_trails[i]
		var node: CanvasItem = trail.node
		trail.life -= delta
		if is_instance_valid(node):
			node.modulate.a = clampf(trail.life / MELEE_TRAIL_LIFETIME, 0.0, 1.0)
		if trail.life <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			slash_trails.remove_at(i)

func _spawn_hit_burst(center: Vector2, is_melee_hit: bool, behavior: String) -> void:
	var burst := ColorRect.new()
	var start_size := Vector2(16.0, 16.0) if is_melee_hit else Vector2(12.0, 12.0)
	var end_size := Vector2(52.0, 52.0) if is_melee_hit else Vector2(38.0, 38.0)
	var burst_color := Color(0.95, 0.84, 0.44, 0.86)
	if behavior == "elite":
		burst_color = Color(1.0, 0.52, 0.25, 0.92)
	elif behavior == "boss":
		burst_color = Color(0.9, 0.44, 0.96, 0.94)
	burst.position = center - start_size * 0.5
	burst.size = start_size
	burst.color = burst_color
	bullets_root.add_child(burst)
	hit_bursts.append({
		"node": burst,
		"life": HIT_BURST_LIFETIME,
		"max_life": HIT_BURST_LIFETIME,
		"center": center,
		"start_size": start_size,
		"end_size": end_size,
		"color": burst_color,
	})

func _update_hit_bursts(delta: float) -> void:
	for i in range(hit_bursts.size() - 1, -1, -1):
		var burst := hit_bursts[i]
		var node: ColorRect = burst.node
		var life := float(burst.get("life", HIT_BURST_LIFETIME)) - delta
		burst.life = life
		var max_life := maxf(0.001, float(burst.get("max_life", HIT_BURST_LIFETIME)))
		var t := clampf(1.0 - life / max_life, 0.0, 1.0)
		var start_size: Vector2 = burst.get("start_size", Vector2(12.0, 12.0))
		var end_size: Vector2 = burst.get("end_size", Vector2(36.0, 36.0))
		var center: Vector2 = burst.get("center", Vector2.ZERO)
		if center == Vector2.ZERO and is_instance_valid(node):
			center = node.position + node.size * 0.5
		var color: Color = burst.get("color", Color(0.95, 0.84, 0.44, 0.86))
		if is_instance_valid(node):
			node.size = start_size.lerp(end_size, t)
			node.position = center - node.size * 0.5
			node.color = Color(color.r, color.g, color.b, color.a * (1.0 - t))
		if life <= 0.0:
			if is_instance_valid(node):
				node.queue_free()
			hit_bursts.remove_at(i)

func _spawn_player_weapon_visual() -> void:
	weapon_pivot = Node2D.new()
	weapon_pivot.name = "WeaponPivot"
	player.add_child(weapon_pivot)
	weapon_line = Line2D.new()
	weapon_line.name = "HeldStaff"
	weapon_line.width = 5.0
	weapon_line.default_color = Color(0.96, 0.72, 0.24, 1.0)
	weapon_line.joint_mode = Line2D.LINE_JOINT_ROUND
	weapon_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	weapon_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	weapon_line.points = PackedVector2Array([Vector2(4.0, 0.0), Vector2(40.0, 0.0)])
	weapon_pivot.add_child(weapon_line)
	var grip := Line2D.new()
	grip.name = "StaffGrip"
	grip.width = 8.0
	grip.default_color = Color(0.34, 0.18, 0.08, 1.0)
	grip.points = PackedVector2Array([Vector2(4.0, 0.0), Vector2(18.0, 0.0)])
	weapon_pivot.add_child(grip)
	_update_player_weapon_visual(0.0)

func _start_weapon_swing() -> void:
	weapon_swing_timer = MELEE_LIFETIME if not _can_fire_wind_shot() else 0.08

func _update_player_weapon_visual(delta: float) -> void:
	if weapon_pivot == null:
		return
	weapon_swing_timer = maxf(0.0, weapon_swing_timer - delta)
	var move_direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if move_direction != Vector2.ZERO and shot_timer <= 0.0:
		last_facing = move_direction.normalized()
	var swing_ratio := weapon_swing_timer / MELEE_LIFETIME if weapon_swing_timer > 0.0 else 0.0
	var swing_angle := lerpf(-0.55, 0.5, 1.0 - swing_ratio) if swing_ratio > 0.0 else 0.18
	weapon_pivot.rotation = last_facing.angle() + swing_angle
	weapon_pivot.position = last_facing * 8.0 + Vector2(0.0, 2.0)
	weapon_line.default_color = Color(0.62, 0.9, 1.0, 1.0) if _can_fire_wind_shot() else Color(0.96, 0.72, 0.24, 1.0)

func _spawn_bullet(direction: Vector2) -> void:
	var bullet := ColorRect.new()
	bullet.size = BULLET_SIZE if direction.x != 0.0 else Vector2(BULLET_SIZE.y, BULLET_SIZE.x)
	bullet.position = player.position - bullet.size / 2.0
	bullet.color = Color(0.58, 0.9, 1.0) if _can_fire_wind_shot() else Color(1.0, 0.82, 0.24)
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
			_damage_enemy(hit_index, bullet.velocity.normalized(), false)

func _spawn_walls(walls: Array) -> void:
	solid_wall_rects.clear()
	for wall_rect in walls:
		var wall := ColorRect.new()
		wall.position = wall_rect.position
		wall.size = wall_rect.size
		wall.color = Color(0.34, 0.35, 0.38)
		wall.add_to_group("wall")
		var wall_inner := ColorRect.new()
		wall_inner.position = Vector2(3.0, 3.0)
		wall_inner.size = Vector2(maxf(2.0, wall.size.x - 6.0), maxf(2.0, wall.size.y - 6.0))
		wall_inner.color = Color(0.22, 0.23, 0.26, 0.88)
		wall.add_child(wall_inner)
		var wall_edge := ColorRect.new()
		wall_edge.position = Vector2(0.0, 0.0)
		wall_edge.size = Vector2(wall.size.x, 6.0)
		wall_edge.color = Color(0.56, 0.53, 0.44, 0.42)
		wall.add_child(wall_edge)
		walls_root.add_child(wall)
		solid_wall_rects.append(Rect2(wall.position, wall.size))
	_update_player_solid_rects()

func _update_player_solid_rects() -> void:
	if player != null and player.has_method("set_solid_rects"):
		player.call("set_solid_rects", solid_wall_rects)

func _spawn_hazards(configs: Array, room_type: String = "combat") -> void:
	for config in configs:
		var hazard_type := String(config.get("type", "spike"))
		var hazard := ColorRect.new()
		var rect: Rect2 = config.get("rect", Rect2(ROOM_MIN + Vector2(220, 220), Vector2(120, 80)))
		hazard.position = rect.position
		hazard.size = rect.size
		hazard.color = _get_hazard_color(hazard_type, 0.0)
		walls_root.add_child(hazard)
		hazards.append({
			"node": hazard,
			"type": hazard_type,
			"phase": randf_range(0.0, TAU),
			"armed": bool(config.get("armed", true)),
			"cooldown_scale": _room_hazard_cooldown_scale(room_type),
		})

func _update_hazards(delta: float) -> void:
	for hazard in hazards:
		hazard.phase += delta
		var node: ColorRect = hazard.node
		node.color = _get_hazard_color(String(hazard.get("type", "spike")), float(hazard.phase))

func _get_hazard_color(hazard_type: String, phase: float) -> Color:
	var pulse := 0.08 * sin(phase * 5.0)
	if hazard_type == "fire":
		return Color(0.95, 0.22 + pulse, 0.08, 0.58)
	if hazard_type == "wind":
		return Color(0.42, 0.7, 0.95, 0.38 + pulse)
	return Color(0.72, 0.12, 0.16, 0.52 + pulse)

func _clear_hazards() -> void:
	for hazard in hazards:
		var node: ColorRect = hazard.node
		if is_instance_valid(node):
			node.queue_free()
	hazards.clear()

func _check_hazard_contact() -> void:
	if hazard_contact_timer > 0.0:
		return
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for hazard in hazards:
		if not bool(hazard.get("armed", true)):
			continue
		var node: ColorRect = hazard.node
		if player_rect.intersects(Rect2(node.position, node.size)):
			hazard_contact_timer = HAZARD_CONTACT_COOLDOWN * float(hazard.get("cooldown_scale", 1.0))
			if shield_charges > 0:
				shield_charges -= 1
				_show_room_message("护身符挡下机关伤害", 1.1)
				_update_reward_panel()
				return
			if player.take_hit():
				_show_room_message(_get_hazard_hit_message(String(hazard.get("type", "spike"))), 1.2)
				_update_reward_panel()
			if not player.is_alive():
				ended = true
				objective_label.text = "取经受阻：按 R 重开"
			return

func _get_hazard_hit_message(hazard_type: String) -> String:
	if hazard_type == "fire":
		return "机关灼伤：短暂无敌"
	if hazard_type == "wind":
		return "黑风卷身：短暂无敌"
	return "机关刺伤：短暂无敌"

func _room_hazard_cooldown_scale(room_type: String) -> float:
	if current_room_index < 2:
		return 1.0
	if room_type == "boss":
		return 0.82
	if room_type == "elite":
		return 0.9
	return 0.95

func _spawn_enemies(configs: Array) -> void:
	for config in configs:
		_spawn_enemy(config)

func _spawn_enemy(config: Dictionary) -> void:
	var hp := int(config.get("hp", 1))
	var enemy_position: Vector2 = _resolve_enemy_spawn_position(config.get("position", Vector2.ZERO))
	var enemy_velocity: Vector2 = config.get("velocity", Vector2.RIGHT)
	var behavior := String(config.get("behavior", _default_enemy_behavior(hp)))
	hp = _scale_enemy_hp(hp, behavior)
	var speed := float(config.get("speed", ENEMY_SPEED)) * _room_enemy_speed_scale(behavior)
	var enemy := ColorRect.new()
	enemy.position = enemy_position
	enemy.size = ENEMY_SIZE if hp == 1 else Vector2(58, 58)
	if behavior == "boss":
		enemy.size = Vector2(78, 78)
	var base_color := ENEMY_COLOR if hp == 1 else ELITE_COLOR
	if behavior == "boss":
		base_color = Color(0.44, 0.22, 0.58)
	enemy.color = base_color
	_attach_art(enemy, _get_enemy_art_key(hp, behavior))
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
		"velocity": enemy_velocity.normalized() * speed,
		"speed": speed,
		"hp": hp,
		"max_hp": hp,
		"base_color": base_color,
		"hit_flash": 0.0,
		"hp_fill": hp_fill,
		"behavior": behavior,
		"state": "idle",
		"state_timer": 0.0,
		"action_timer": float(config.get("action_timer", randf_range(0.8, 2.2))),
		"wander_phase": randf_range(0.0, TAU),
	}
	enemies.append(enemy_state)
	_update_enemy_status(enemy_state)

func _update_enemies(delta: float) -> void:
	for enemy in enemies:
		var node: ColorRect = enemy.node
		enemy.hit_flash = maxf(0.0, enemy.hit_flash - delta)
		node.color = Color(1.0, 0.92, 0.62) if enemy.hit_flash > 0.0 else enemy.base_color
		_update_enemy_behavior(enemy, delta)
		var move_velocity: Vector2 = enemy.velocity
		if enemy.state == "rushing":
			move_velocity *= ELITE_RUSH_SCALE
		elif enemy.state == "charging":
			move_velocity *= BOSS_CHARGE_SCALE
		node.position += move_velocity * delta
		var rect := Rect2(node.position, node.size)
		var bounced := false
		if rect.position.x <= ROOM_MIN.x or rect.end.x >= ROOM_MAX.x:
			enemy.velocity.x *= -1.0
			bounced = true
		if rect.position.y <= ROOM_MIN.y or rect.end.y >= ROOM_MAX.y:
			enemy.velocity.y *= -1.0
			bounced = true
		if _enemy_hits_wall(node):
			enemy.velocity = _slide_enemy_velocity(enemy.velocity, node)
			bounced = true
		if bounced:
			node.position.x = clampf(node.position.x, ROOM_MIN.x, ROOM_MAX.x - node.size.x)
			node.position.y = clampf(node.position.y, ROOM_MIN.y, ROOM_MAX.y - node.size.y)

func _slide_enemy_velocity(velocity: Vector2, node: ColorRect) -> Vector2:
	var horizontal_try := Vector2(-velocity.x, velocity.y)
	var vertical_try := Vector2(velocity.x, -velocity.y)
	var rect_h := Rect2(node.position + horizontal_try.normalized() * 6.0, node.size)
	if horizontal_try.length() > 0.0 and not _enemy_rect_hits_wall(rect_h):
		return horizontal_try
	var rect_v := Rect2(node.position + vertical_try.normalized() * 6.0, node.size)
	if vertical_try.length() > 0.0 and not _enemy_rect_hits_wall(rect_v):
		return vertical_try
	return -velocity

func _update_enemy_behavior(enemy: Dictionary, delta: float) -> void:
	var behavior := String(enemy.get("behavior", "wander"))
	if behavior == "chase":
		_steer_enemy_toward_player(enemy, delta, 0.72)
		_add_enemy_wander(enemy, delta)
	elif behavior == "elite":
		_update_elite_behavior(enemy, delta)
	elif behavior == "boss":
		_update_boss_behavior(enemy, delta)
	else:
		_add_enemy_wander(enemy, delta)
	_limit_enemy_velocity(enemy, float(enemy.get("speed", ENEMY_SPEED)))

func _steer_enemy_toward_player(enemy: Dictionary, delta: float, strength_scale: float = 1.0) -> void:
	var node: ColorRect = enemy.node
	var enemy_center := node.position + node.size / 2.0
	var target := (player.position - enemy_center).normalized()
	enemy.velocity += target * ENEMY_CHASE_STEER * strength_scale * delta

func _add_enemy_wander(enemy: Dictionary, delta: float) -> void:
	enemy.wander_phase += delta * 1.7
	var drift := Vector2(cos(enemy.wander_phase), sin(enemy.wander_phase * 0.73))
	enemy.velocity += drift * ENEMY_WANDER_STEER * delta

func _update_elite_behavior(enemy: Dictionary, delta: float) -> void:
	_steer_enemy_toward_player(enemy, delta, 0.55)
	if enemy.state == "rushing":
		enemy.state_timer -= delta
		if enemy.state_timer <= 0.0:
			enemy.state = "idle"
			enemy.action_timer = ELITE_RUSH_INTERVAL
		return
	enemy.action_timer -= delta
	if enemy.action_timer <= 0.0:
		enemy.state = "rushing"
		enemy.state_timer = ELITE_RUSH_DURATION
		_show_room_message("精英急袭：拉开身位", 0.9)

func _update_boss_behavior(enemy: Dictionary, delta: float) -> void:
	_steer_enemy_toward_player(enemy, delta, 0.42)
	if enemy.state == "charging":
		enemy.state_timer -= delta
		if enemy.state_timer <= 0.0:
			enemy.state = "idle"
			enemy.action_timer = BOSS_ACTION_INTERVAL
		return
	enemy.action_timer -= delta
	if enemy.action_timer > 0.0:
		return
	if _count_live_enemies("summon") < BOSS_SUMMON_LIMIT and randi() % 2 == 0:
		_spawn_boss_summon(enemy)
		_show_room_message("黑风妖王召来小妖", 1.0)
	else:
		enemy.state = "charging"
		enemy.state_timer = BOSS_CHARGE_DURATION
		enemy.velocity = (player.position - (enemy.node.position + enemy.node.size / 2.0)).normalized() * float(enemy.get("speed", ENEMY_SPEED))
		_show_room_message("黑风妖王冲刺", 1.0)

func _limit_enemy_velocity(enemy: Dictionary, max_speed: float) -> void:
	enemy.velocity = enemy.velocity.limit_length(max_speed)

func _count_live_enemies(behavior: String) -> int:
	var count := 0
	for enemy in enemies:
		if String(enemy.get("behavior", "")) == behavior:
			count += 1
	return count

func _spawn_boss_summon(boss_enemy: Dictionary) -> void:
	var boss_node: ColorRect = boss_enemy.node
	var spawn_position := boss_node.position + Vector2(randf_range(-120.0, 120.0), randf_range(-92.0, 92.0))
	spawn_position.x = clampf(spawn_position.x, ROOM_MIN.x + 48.0, ROOM_MAX.x - 96.0)
	spawn_position.y = clampf(spawn_position.y, ROOM_MIN.y + 48.0, ROOM_MAX.y - 96.0)
	_spawn_enemy({
		"position": spawn_position,
		"velocity": Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)),
		"hp": 1,
		"behavior": "summon",
		"speed": ENEMY_SPEED * 1.05,
	})

func _resolve_enemy_spawn_position(raw_position: Vector2) -> Vector2:
	var min_x := ROOM_MIN.x + SPAWN_SAFETY_PADDING
	var max_x := ROOM_MAX.x - ENEMY_SIZE.x - SPAWN_SAFETY_PADDING
	var min_y := ROOM_MIN.y + SPAWN_SAFETY_PADDING
	var max_y := ROOM_MAX.y - ENEMY_SIZE.y - SPAWN_SAFETY_PADDING
	var spawn := Vector2(
		clampf(raw_position.x, min_x, max_x),
		clampf(raw_position.y, min_y, max_y)
	)
	var probe_size := ENEMY_SIZE
	var tries := 0
	while tries < 10 and (_enemy_rect_hits_wall(Rect2(spawn, probe_size)) or _enemy_rect_hits_hazard(Rect2(spawn, probe_size))):
		var angle := float((room_spawn_guard_index + tries) % 12) * TAU / 12.0
		var radius := 38.0 + float(tries) * 14.0
		var candidate := spawn + Vector2(cos(angle), sin(angle)) * radius
		candidate.x = clampf(candidate.x, min_x, max_x)
		candidate.y = clampf(candidate.y, min_y, max_y)
		spawn = candidate
		tries += 1
	room_spawn_guard_index += 1
	return spawn

func _room_enemy_speed_scale(behavior: String) -> float:
	if current_room_index < EARLY_ROOM_COUNT:
		return 1.0
	var late_steps: int = max(0, current_room_index - 1)
	var speed_scale: float = 1.0 + float(late_steps) * LATE_ROOM_SPEED_STEP
	if current_room_type == "boss" or behavior == "boss":
		speed_scale += BOSS_ROOM_SPEED_BONUS
	elif current_room_type == "elite" or behavior == "elite":
		speed_scale += 0.04
	return minf(speed_scale, 1.24)

func _scale_enemy_hp(base_hp: int, behavior: String) -> int:
	if current_room_index < EARLY_ROOM_COUNT:
		return base_hp
	if behavior == "summon":
		return base_hp
	if current_room_type == "boss" and behavior == "boss":
		return base_hp + LATE_ROOM_HP_STEP
	if current_room_index >= 3 and (behavior == "elite" or base_hp >= 3):
		return base_hp + LATE_ROOM_HP_STEP
	return base_hp

func _default_enemy_behavior(hp: int) -> String:
	if hp >= 8:
		return "boss"
	if hp >= 3:
		return "elite"
	return "chase"

func _check_enemy_contact() -> void:
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for enemy in enemies:
		var node: ColorRect = enemy.node
		if player_rect.intersects(Rect2(node.position, node.size)):
			if shield_charges > 0:
				shield_charges -= 1
				_show_room_message("护身符触发：抵挡一次伤害", 1.1)
				return
			player.take_hit()
			if not player.is_alive():
				ended = true
				objective_label.text = "取经受阻：按 R 重开"

func _damage_enemy(index: int, hit_direction: Vector2, is_melee_hit: bool) -> void:
	var enemy := enemies[index]
	enemy.hp -= 1
	var node: ColorRect = enemy.node
	var enemy_behavior := String(enemy.get("behavior", "chase"))
	_spawn_hit_burst(node.position + node.size / 2.0, is_melee_hit, enemy_behavior)
	enemy.hit_flash = HIT_FLASH_TIME
	var knockback := MELEE_HIT_KNOCKBACK if is_melee_hit else RANGED_HIT_KNOCKBACK
	var speed_cap := ENEMY_SPEED * (1.85 if is_melee_hit else 1.55)
	enemy.velocity = (enemy.velocity + hit_direction * knockback).limit_length(speed_cap)
	if enemy.hp <= 0:
		var dropped := _try_spawn_enemy_pickup(enemy, node.position + node.size / 2.0)
		node.queue_free()
		enemies.remove_at(index)
		_show_room_message("妖怪退散：掉落法宝" if dropped else "妖怪退散", 1.2 if dropped else 0.8)
		if enemies.is_empty():
			_open_doors()
	else:
		_update_enemy_status(enemy)
		_show_room_message("命中：妖怪被击退", 0.8)

func _try_spawn_enemy_pickup(enemy: Dictionary, center_position: Vector2) -> bool:
	var behavior := String(enemy.get("behavior", "wander"))
	var chance := NORMAL_PICKUP_DROP_CHANCE
	if behavior == "elite":
		chance = ELITE_PICKUP_DROP_CHANCE
	elif behavior == "boss":
		chance = BOSS_PICKUP_DROP_CHANCE
	elif behavior == "summon":
		chance = 0.08
	if randf() > chance:
		return false
	_spawn_pickup(center_position)
	return true

func _spawn_pickup(center_position: Vector2) -> void:
	_spawn_reward_pickup(center_position, _roll_room_reward())

func _spawn_reward_pickup(center_position: Vector2, reward_type: String, options: Dictionary = {}) -> void:
	var pickup := ColorRect.new()
	pickup.size = PICKUP_SIZE
	pickup.position = center_position - PICKUP_SIZE / 2.0
	var reward_name := "定风珠"
	var reward_color := Color(0.2, 0.68, 1.0)
	if reward_type == "speed":
		reward_name = "腾云符"
		reward_color = Color(0.25, 0.88, 0.62)
	elif reward_type == "shield":
		reward_name = "护身符"
		reward_color = Color(0.98, 0.84, 0.3)
	pickup.color = reward_color
	_attach_art(pickup, _get_pickup_art_key(reward_type))
	pickup.add_to_group("pickup")
	add_child(pickup)
	pickups.append({
		"node": pickup,
		"life": float(options.get("life", 9.0)),
		"type": reward_type,
		"name": reward_name,
		"choice_group": String(options.get("choice_group", "")),
	})

func _roll_room_reward() -> String:
	var roll := randi() % 3
	if roll == 0:
		return "shot"
	if roll == 1:
		return "speed"
	return "shield"

func _update_pickups(delta: float) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		var node: ColorRect = pickup.node
		var life := float(pickup.get("life", 9.0))
		life -= delta
		pickup.life = life
		var should_blink := life < 2.0 and life < 900.0
		node.modulate.a = 0.45 if should_blink and int(life * 10.0) % 2 == 0 else 1.0
		if pickup.life <= 0.0:
			node.queue_free()
			pickups.remove_at(i)

func _clear_pickup_choice_group(choice_group: String) -> void:
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		if String(pickup.get("choice_group", "")) != choice_group:
			continue
		var node: ColorRect = pickup.node
		if is_instance_valid(node):
			node.queue_free()
		pickups.remove_at(i)

func _check_pickup_contact() -> void:
	var player_rect := Rect2(player.position - PLAYER_SIZE / 2.0, PLAYER_SIZE)
	for i in range(pickups.size() - 1, -1, -1):
		var pickup := pickups[i]
		var node: ColorRect = pickup.node
		if player_rect.intersects(Rect2(node.position, node.size)):
			var reward_type := String(pickup.get("type", "shot"))
			var reward_name := String(pickup.get("name", "定风珠"))
			if reward_type == "speed":
				player.apply_speed_boost(SPEED_BOOST_DURATION, SPEED_BOOST_MULTIPLIER)
				_show_room_message("拾取%s：%.0f 秒内移速提升" % [reward_name, SPEED_BOOST_DURATION], 1.8)
			elif reward_type == "shield":
				shield_charges = min(shield_charges + 1, _max_shield_charges())
				_show_room_message("拾取%s：护盾+1" % reward_name, 1.8)
			else:
				shot_boost_timer = SHOT_BOOST_DURATION
				wind_shot_charges = WIND_SHOT_CHARGES
				shot_timer = minf(shot_timer, BOOSTED_SHOT_COOLDOWN)
				_show_room_message("拾取%s：%.0f 秒内可远程 %d 发" % [reward_name, SHOT_BOOST_DURATION, WIND_SHOT_CHARGES], 1.8)
			last_reward_name = reward_name
			_record_reward(reward_name)
			_show_pickup_cue(_build_pickup_cue_text(reward_type, reward_name))
			_update_reward_panel()
			node.queue_free()
			pickups.remove_at(i)
			var choice_group := String(pickup.get("choice_group", ""))
			if choice_group != "":
				_clear_pickup_choice_group(choice_group)
				_update_run_state_banner("已择")
				_show_room_message("休整选择已定：另一路馈赠消散", 1.6)
			return

func _open_doors() -> void:
	if doors_open:
		return
	doors_open = true
	_grant_room_clear_reward()
	_set_exit_open()
	_spawn_door(Vector2(ROOM_MAX.x - 72, (ROOM_MIN.y + ROOM_MAX.y) / 2.0 - 28.0))
	_update_run_state_banner("清房")
	_show_room_message("房间已净：绿色传送门开启", 3.0)

func _spawn_door(door_position: Vector2) -> void:
	var door := ColorRect.new()
	door.position = door_position
	door.size = Vector2(56, 56)
	door.color = OPEN_EXIT_COLOR
	_attach_art(door, "gate")
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
				_show_complete_overlay()
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
	var tree := get_tree()
	if tree == null:
		return false
	var bullet_rect := Rect2(node.position, node.size)
	for wall in tree.get_nodes_in_group("wall"):
		if bullet_rect.intersects(Rect2(wall.position, wall.size)):
			return true
	return false

func _enemy_hits_wall(node: ColorRect) -> bool:
	return _enemy_rect_hits_wall(Rect2(node.position, node.size))

func _enemy_rect_hits_wall(enemy_rect: Rect2) -> bool:
	var tree := get_tree()
	if tree == null:
		return false
	for wall in tree.get_nodes_in_group("wall"):
		if enemy_rect.intersects(Rect2(wall.position, wall.size)):
			return true
	return false

func _enemy_rect_hits_hazard(enemy_rect: Rect2) -> bool:
	for hazard in hazards:
		var node: ColorRect = hazard.node
		if not is_instance_valid(node):
			continue
		if enemy_rect.intersects(Rect2(node.position, node.size)):
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
	return BOOSTED_SHOT_COOLDOWN if _can_fire_wind_shot() else MELEE_COOLDOWN

func _can_fire_wind_shot() -> bool:
	return shot_boost_timer > 0.0 and wind_shot_charges > 0

func _current_bullet_speed() -> float:
	var speed_scale := 1.0 + 0.05 * float(clear_reward_stacks)
	var boosted_scale := 1.18 if _can_fire_wind_shot() else 1.0
	return BULLET_SPEED * boosted_scale * speed_scale

func _grant_room_clear_reward() -> void:
	if room_reward_granted:
		return
	if current_room_type == "rest":
		return
	room_reward_granted = true
	clear_reward_stacks = min(clear_reward_stacks + 1, 5)
	last_reward_name = "气势加持"
	_record_reward(last_reward_name)
	_show_pickup_cue("获得气势加持：弹速提升（常驻）")
	_show_room_message("清房奖励：气势+1（弹速提升）", 1.6)
	_update_reward_panel()

func _spawn_rest_room_reward() -> void:
	if current_room_type != "rest":
		return
	if not pickups.is_empty():
		return
	var reward_options := _roll_rest_reward_choices()
	var center_y := (ROOM_MIN.y + ROOM_MAX.y) * 0.5
	var choice_group := "rest_%d" % current_room_index
	_spawn_reward_pickup(Vector2(ROOM_MIN.x + 680.0, center_y), reward_options[0], {
		"choice_group": choice_group,
		"life": 999.0,
	})
	_spawn_reward_pickup(Vector2(ROOM_MAX.x - 680.0, center_y), reward_options[1], {
		"choice_group": choice_group,
		"life": 999.0,
	})
	_show_room_message("休整馈赠：二选一，触碰后另一个消失", 2.2)

func _roll_rest_reward_choices() -> Array[String]:
	var first := _roll_room_reward()
	var second := _roll_room_reward()
	var guard := 0
	while second == first and guard < 8:
		second = _roll_room_reward()
		guard += 1
	return [first, second]

func _max_shield_charges() -> int:
	return 1 if current_room_type == "rest" else 2

func _show_room_message(message: String, duration: float) -> void:
	room_message = message
	message_timer = duration
	objective_label.text = room_message

func _load_art_textures() -> void:
	art_textures = {
		"player": _load_svg_texture(PLAYER_ART_PATH),
		"enemy": _load_svg_texture(ENEMY_ART_PATH),
		"elite": _load_svg_texture(ELITE_ART_PATH),
		"boss": _load_svg_texture(BOSS_ART_PATH),
		"gate": _load_svg_texture(GATE_ART_PATH),
		"pickup_shot": _load_svg_texture(PICKUP_SHOT_ART_PATH),
		"pickup_speed": _load_svg_texture(PICKUP_SPEED_ART_PATH),
		"pickup_shield": _load_svg_texture(PICKUP_SHIELD_ART_PATH),
	}

func _load_svg_texture(path: String) -> Texture2D:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return null
	var svg_text := file.get_as_text()
	var image := Image.new()
	var error := image.load_svg_from_string(svg_text)
	if error != OK:
		return null
	return ImageTexture.create_from_image(image)

func _attach_art(target: ColorRect, art_key: String) -> void:
	var texture: Texture2D = art_textures.get(art_key)
	if texture == null:
		return
	target.color.a = 0.42
	var art := TextureRect.new()
	art.name = "Art"
	art.texture = texture
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	art.position = Vector2.ZERO
	art.size = target.size
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	target.add_child(art)

func _get_enemy_art_key(hp: int, behavior: String = "") -> String:
	if behavior == "boss" or hp >= 8:
		return "boss"
	if behavior == "elite" or hp > 1:
		return "elite"
	return "enemy"

func _get_pickup_art_key(reward_type: String) -> String:
	if reward_type == "speed":
		return "pickup_speed"
	if reward_type == "shield":
		return "pickup_shield"
	return "pickup_shot"

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
		"hazards": room_template.hazards.duplicate(true) if room_template.has("hazards") else [],
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
				"hazards": [
					{ "type": "spike", "rect": Rect2(760, 300, 110, 94) },
					{ "type": "spike", "rect": Rect2(1050, 686, 110, 94) },
				],
				"enemies": [
					{ "position": Vector2(360, 250), "velocity": Vector2(1, 0.75), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED * 0.95 },
					{ "position": Vector2(1450, 280), "velocity": Vector2(-0.8, 1), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED * 0.95 },
					{ "position": Vector2(420, 760), "velocity": Vector2(1, -0.9), "hp": 1, "behavior": "wander", "speed": ENEMY_SPEED * 1.05 },
					{ "position": Vector2(1420, 760), "velocity": Vector2(-1, -0.72), "hp": 2, "behavior": "chase", "speed": ENEMY_SPEED },
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
					{ "position": Vector2(360, 380), "velocity": Vector2(1, 0.6), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED },
					{ "position": Vector2(1470, 360), "velocity": Vector2(-1, 0.66), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED },
					{ "position": Vector2(400, 700), "velocity": Vector2(0.9, -0.9), "hp": 1, "behavior": "wander", "speed": ENEMY_SPEED * 1.08 },
					{ "position": Vector2(1450, 710), "velocity": Vector2(-0.8, -0.92), "hp": 1, "behavior": "wander", "speed": ENEMY_SPEED * 1.08 },
				],
			},
			{
				"id": "combat_spider",
				"hint": "别被中路牵制，先破两翼",
				"lore": "蛛丝结网，越急越乱",
				"name": "盘丝洞窄厅",
				"type": "combat",
				"walls": [
					Rect2(420, 260, 180, 40),
					Rect2(1320, 260, 180, 40),
					Rect2(420, 780, 180, 40),
					Rect2(1320, 780, 180, 40),
					Rect2(760, 390, 110, 300),
					Rect2(1050, 390, 110, 300),
				],
				"hazards": [
					{ "type": "spike", "rect": Rect2(890, 390, 140, 82) },
					{ "type": "spike", "rect": Rect2(890, 608, 140, 82) },
				],
				"enemies": [
					{ "position": Vector2(420, 420), "velocity": Vector2(1, 0.7), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED * 1.04 },
					{ "position": Vector2(1460, 420), "velocity": Vector2(-1, 0.7), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED * 1.04 },
					{ "position": Vector2(420, 690), "velocity": Vector2(1, -0.7), "hp": 1, "behavior": "wander", "speed": ENEMY_SPEED * 1.14 },
					{ "position": Vector2(1460, 690), "velocity": Vector2(-1, -0.7), "hp": 2, "behavior": "wander", "speed": ENEMY_SPEED * 1.1 },
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
					{ "position": Vector2(960, 520), "velocity": Vector2(1, 0.4), "hp": 4, "behavior": "elite", "speed": ENEMY_SPEED * 0.9 },
					{ "position": Vector2(560, 500), "velocity": Vector2(1, -0.7), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED },
					{ "position": Vector2(1320, 520), "velocity": Vector2(-1, 0.75), "hp": 1, "behavior": "chase", "speed": ENEMY_SPEED },
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
				"hazards": [
					{ "type": "fire", "rect": Rect2(700, 340, 120, 110) },
					{ "type": "fire", "rect": Rect2(1100, 630, 120, 110) },
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(1, 0.25), "hp": 5, "behavior": "elite", "speed": ENEMY_SPEED * 0.94 },
					{ "position": Vector2(650, 420), "velocity": Vector2(0.9, -0.95), "hp": 2, "behavior": "chase", "speed": ENEMY_SPEED * 1.04 },
					{ "position": Vector2(1270, 620), "velocity": Vector2(-0.9, 0.95), "hp": 2, "behavior": "chase", "speed": ENEMY_SPEED * 1.04 },
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
					{ "position": Vector2(960, 520), "velocity": Vector2(0.9, 0.58), "hp": 4, "behavior": "elite", "speed": ENEMY_SPEED * 0.92 },
					{ "position": Vector2(620, 520), "velocity": Vector2(1, -0.58), "hp": 2, "behavior": "wander", "speed": ENEMY_SPEED * 1.12 },
					{ "position": Vector2(1300, 520), "velocity": Vector2(-1, 0.58), "hp": 2, "behavior": "wander", "speed": ENEMY_SPEED * 1.12 },
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
		"boss": [
			{
				"id": "boss_blackwind",
				"name": "黑风山妖王",
				"type": "boss",
				"hint": "先清两翼，再压首领走位",
				"lore": "黑风卷林，袈裟旧案再起波澜",
				"walls": [
					Rect2(500, 260, 220, 46),
					Rect2(1200, 260, 220, 46),
					Rect2(500, 774, 220, 46),
					Rect2(1200, 774, 220, 46),
					Rect2(870, 390, 180, 52),
					Rect2(870, 636, 180, 52),
				],
				"hazards": [
					{ "type": "wind", "rect": Rect2(760, 470, 120, 140) },
					{ "type": "wind", "rect": Rect2(1040, 470, 120, 140) },
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(0.95, 0.42), "hp": 8, "behavior": "boss", "speed": ENEMY_SPEED * 0.82 },
					{ "position": Vector2(620, 430), "velocity": Vector2(1.0, -0.72), "hp": 2, "behavior": "chase", "speed": ENEMY_SPEED },
					{ "position": Vector2(1290, 630), "velocity": Vector2(-1.0, 0.72), "hp": 2, "behavior": "chase", "speed": ENEMY_SPEED },
				],
			},
			{
				"id": "boss_lion_camel",
				"name": "狮驼岭三魔影",
				"type": "boss",
				"hint": "不要恋战，绕开中场风区逐个削血",
				"lore": "岭上风腥，三影压境",
				"walls": [
					Rect2(440, 245, 260, 46),
					Rect2(1220, 245, 260, 46),
					Rect2(440, 790, 260, 46),
					Rect2(1220, 790, 260, 46),
					Rect2(850, 410, 220, 54),
					Rect2(850, 616, 220, 54),
				],
				"hazards": [
					{ "type": "wind", "rect": Rect2(730, 470, 120, 140) },
					{ "type": "fire", "rect": Rect2(1070, 470, 120, 140) },
				],
				"enemies": [
					{ "position": Vector2(960, 520), "velocity": Vector2(0.85, 0.45), "hp": 10, "behavior": "boss", "speed": ENEMY_SPEED * 0.86 },
					{ "position": Vector2(560, 430), "velocity": Vector2(1.0, -0.62), "hp": 3, "behavior": "elite", "speed": ENEMY_SPEED * 0.96 },
					{ "position": Vector2(1360, 650), "velocity": Vector2(-1.0, 0.62), "hp": 3, "behavior": "elite", "speed": ENEMY_SPEED * 0.96 },
				],
			},
		],
	}

func _build_room_route() -> Array[Dictionary]:
	return _build_curated_room_route()

func _build_curated_room_route() -> Array[Dictionary]:
	var all_rooms: Array[Dictionary] = []
	all_rooms.append_array(room_pools.combat)
	all_rooms.append_array(room_pools.elite)
	all_rooms.append_array(room_pools.rest)
	all_rooms.append_array(room_pools.boss)
	var route_ids := [
		"combat_bridge",
		"combat_bone",
		"elite_default",
		"rest_calm",
		"combat_spider",
		"elite_fire_cloud",
		"rest_dragon",
		"elite_jindou",
		"boss_blackwind",
		"boss_lion_camel",
	]
	var route: Array[Dictionary] = []
	for room_id in route_ids:
		route.append(_clone_room_template(_find_room_template(all_rooms, room_id)))
	return route

func _find_room_template(rooms: Array[Dictionary], room_id: String) -> Dictionary:
	for room in rooms:
		if String(room.get("id", "")) == room_id:
			return room
	return rooms[0]

func _load_room(room_index: int, is_first_room: bool) -> void:
	current_room_index = clampi(room_index, 0, max(0, room_templates.size() - 1))
	if is_first_room:
		run_complete = false
	room_complete = false
	room_reward_granted = false
	ended = false
	doors_open = false
	message_timer = 0.0
	room_message = ""
	hazard_contact_timer = 0.0
	shot_boost_timer = 0.0
	wind_shot_charges = 0
	room_spawn_guard_index = 0
	bullets.clear()
	melee_effects.clear()
	enemies.clear()
	pickups.clear()
	_clear_hazards()
	_clear_node_children(bullets_root)
	_clear_node_children(enemies_root)
	_clear_node_children(doors_root)
	_clear_node_children(walls_root)
	for pickup in get_tree().get_nodes_in_group("pickup"):
		pickup.queue_free()
	_set_exit_locked()
	var room_config := room_templates[current_room_index]
	current_room_type = String(room_config.get("type", "combat"))
	_update_room_info_panel(room_config)
	_update_route_preview()
	_update_reward_panel()
	_update_run_state_banner("入场")
	_spawn_walls(room_config.walls)
	_spawn_hazards(room_config.get("hazards", []), current_room_type)
	_spawn_enemies(room_config.enemies)
	_spawn_rest_room_reward()
	player.global_position = Vector2(ROOM_MIN.x + 88.0, (ROOM_MIN.y + ROOM_MAX.y) * 0.5)
	if room_config.enemies.is_empty():
		_open_doors()
	var prefix := "进入" if is_first_room else "抵达"
	_show_room_message("%s：%s (%d/%d)" % [prefix, room_config.name, current_room_index + 1, room_templates.size()], 2.0)

func _update_hud() -> void:
	var cooldown := _current_shot_cooldown()
	var charge_ratio := 1.0 - clampf(shot_timer / cooldown, 0.0, 1.0)
	var attack_mode := "远程" if _can_fire_wind_shot() else "近战"
	var charge := "%s就绪" % attack_mode if shot_timer <= 0.0 else "%s%d%%" % [attack_mode, roundi(charge_ratio * 100.0)]
	hud_label.text = "取经状态"
	hud_hp_value.text = _build_health_marks()
	hud_enemy_value.text = "%d" % enemies.size()
	hud_attack_value.text = charge
	hud_reward_value.text = "气 %d" % clear_reward_stacks
	hud_hp_cell.color = Color(0.18, 0.035, 0.035, 0.92) if player.health <= 1 else Color(0.11, 0.045, 0.04, 0.86)
	hud_attack_cell.color = Color(0.055, 0.13, 0.08, 0.88) if shot_timer <= 0.0 else Color(0.055, 0.085, 0.11, 0.86)
	if shot_meter_fill != null:
		shot_meter_fill.size.x = 240.0 * charge_ratio
		shot_meter_fill.color = Color(0.36, 0.92, 0.48) if shot_timer <= 0.0 else Color(1.0, 0.76, 0.25)
	_update_combat_status(charge_ratio)
	_update_choice_status()
	if message_timer > 0.0:
		objective_label.text = room_message
	elif not hazards.is_empty() and not doors_open and not ended:
		objective_label.text = "清空房间。红色/蓝色机关区会造成伤害。"
	elif not doors_open and not ended:
		objective_label.text = "近身斩妖。获得定风珠后可短暂远程攻击。"
	elif doors_open and not ended:
		objective_label.text = "房间已净，进入绿色传送门。"

func _update_combat_status(charge_ratio: float) -> void:
	if _can_fire_wind_shot():
		combat_mode_label.text = "当前：远程 · 定风珠 %.0f 秒" % shot_boost_timer
		combat_detail_label.text = "方向键发射灵弹；剩余 %d 发后回到近战" % wind_shot_charges
		combat_accent.color = Color(0.36, 0.92, 0.72, 1)
		combat_panel.color = Color(0.026, 0.07, 0.052, 0.9)
		if not doors_open:
			_update_run_state_banner("远程")
	else:
		var ready_text := "就绪" if shot_timer <= 0.0 else "蓄势 %d%%" % roundi(charge_ratio * 100.0)
		combat_mode_label.text = "当前：近战 · %s" % ready_text
		combat_detail_label.text = "方向键挥击；拾取定风珠后短时改为远程"
		combat_accent.color = Color(0.36, 0.76, 0.9, 1)
		combat_panel.color = Color(0.032, 0.044, 0.05, 0.88)
		if not doors_open:
			_update_run_state_banner("交战")

func _update_choice_status() -> void:
	if current_room_type == "rest":
		choice_panel.color = Color(0.03, 0.048, 0.06, 0.9)
		choice_accent.color = Color(0.28, 0.72, 0.9, 1)
		choice_text_label.text = "休整二选一：触碰其一后，另一馈赠消散"
		return
	if _can_fire_wind_shot():
		choice_panel.color = Color(0.03, 0.06, 0.05, 0.9)
		choice_accent.color = Color(0.36, 0.92, 0.72, 1)
		choice_text_label.text = "定风珠生效：剩余 %d 发远程灵弹" % wind_shot_charges
		return
	choice_panel.color = Color(0.03, 0.04, 0.048, 0.86)
	choice_accent.color = Color(0.42, 0.72, 0.94, 1)
	choice_text_label.text = "当前无临时法宝：默认方向键近战挥击"

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
	complete_overlay.visible = false
	hud_panel.visible = running
	hud_accent.visible = running
	hud_hp_cell.visible = running
	$CanvasLayer/HudHpIcon.visible = running
	hud_hp_value.visible = running
	$CanvasLayer/HudEnemyCell.visible = running
	$CanvasLayer/HudEnemyIcon.visible = running
	hud_enemy_value.visible = running
	hud_attack_cell.visible = running
	$CanvasLayer/HudAttackIcon.visible = running
	hud_attack_value.visible = running
	$CanvasLayer/HudRewardCell.visible = running
	hud_reward_icon.visible = running
	hud_reward_value.visible = running
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
	route_panel.visible = running
	route_accent.visible = running
	$CanvasLayer/RouteTitle.visible = running
	route_map_root.visible = running
	route_preview_label.visible = running
	encounter_panel.visible = running
	encounter_accent.visible = running
	$CanvasLayer/EncounterTitle.visible = running
	encounter_type_label.visible = running
	encounter_hint_label.visible = running
	run_state_panel.visible = running
	run_state_accent.visible = running
	run_state_tag_label.visible = running
	run_state_phase_label.visible = running
	reward_panel.visible = running
	reward_accent.visible = running
	$CanvasLayer/RewardTitle.visible = running
	reward_name_label.visible = running
	reward_effect_label.visible = running
	reward_state_label.visible = running
	loot_panel.visible = running
	loot_title_label.visible = running
	loot_list_label.visible = running
	combat_panel.visible = running
	combat_accent.visible = running
	$CanvasLayer/CombatTitle.visible = running
	combat_mode_label.visible = running
	combat_detail_label.visible = running
	choice_panel.visible = running
	choice_accent.visible = running
	$CanvasLayer/ChoiceTitle.visible = running
	choice_text_label.visible = running
	pickup_cue_label.visible = running and pickup_cue_timer > 0.0
	$ExitHint.visible = running
	if running:
		_update_run_state_banner()

func _start_run() -> void:
	started = true
	paused = false
	_reset_run_state()
	pickup_cue_label.visible = false
	complete_overlay.visible = false
	_update_route_preview()
	_update_reward_panel()
	_update_choice_status()
	_update_run_state_banner("入场")
	_set_ui_running_state(true)
	_set_paused_state(false)
	_show_room_message("试炼开始：清空房间，破除封印。", 1.6)

func _reset_run_state() -> void:
	run_time = 0.0
	pickup_cue_timer = 0.0
	clear_reward_stacks = 0
	shield_charges = 0
	shot_boost_timer = 0.0
	wind_shot_charges = 0
	collected_rewards.clear()
	last_reward_name = "无"
	_update_loot_list()

func _set_paused_state(value: bool) -> void:
	paused = value
	pause_overlay.visible = paused

func _update_room_info_panel(room_config: Dictionary) -> void:
	var room_name := String(room_config.get("name", "未知试炼"))
	var room_hint := String(room_config.get("hint", "清怪破印，稳住推进"))
	var room_lore := String(room_config.get("lore", "古道漫漫，心定则路明"))
	var room_type := String(room_config.get("type", "combat"))
	var room_type_label := _get_room_type_label(room_type)
	room_title_label.text = "第 %02d 关：%s" % [current_room_index + 1, room_name]
	room_progress_label.text = "固定十关进度 %d / %d · %s" % [current_room_index + 1, room_templates.size(), room_type_label]
	room_hint_label.text = "提示：%s" % room_hint
	room_lore_label.text = "短句：%s" % room_lore
	room_info_accent.color = _get_room_type_accent(room_type)
	_apply_room_palette(room_type)
	_update_encounter_panel(room_type)

func _get_room_type_label(room_type: String) -> String:
	if room_type == "rest":
		return "宝物休整"
	if room_type == "elite":
		return "精英战"
	if room_type == "boss":
		return "妖王战"
	return "普通战"

func _get_room_type_accent(room_type: String) -> Color:
	if room_type == "rest":
		return Color(0.28, 0.72, 0.9, 1)
	if room_type == "elite":
		return Color(0.95, 0.46, 0.22, 1)
	if room_type == "boss":
		return Color(0.78, 0.38, 0.88, 1)
	return Color(0.74, 0.56, 0.24, 1)

func _apply_room_palette(room_type: String) -> void:
	if background_rect == null or room_frame_rect == null:
		return
	if room_type == "rest":
		background_rect.color = Color(0.055, 0.08, 0.1, 1)
		room_frame_rect.color = Color(0.1, 0.15, 0.18, 1)
	elif room_type == "elite":
		background_rect.color = Color(0.085, 0.07, 0.055, 1)
		room_frame_rect.color = Color(0.15, 0.11, 0.09, 1)
	elif room_type == "boss":
		background_rect.color = Color(0.08, 0.055, 0.095, 1)
		room_frame_rect.color = Color(0.14, 0.1, 0.17, 1)
	else:
		background_rect.color = Color(0.07, 0.08, 0.1, 1)
		room_frame_rect.color = Color(0.12, 0.13, 0.15, 1)

func _format_run_time(seconds: float) -> String:
	var total := maxi(0, int(seconds))
	var minutes := floori(float(total) / 60.0)
	var remain := total % 60
	return "%02d:%02d" % [minutes, remain]

func _get_route_lines() -> PackedStringArray:
	var lines: PackedStringArray = []
	for i in range(room_templates.size()):
		var room := room_templates[i]
		var mark := "•"
		if run_complete:
			mark = "√"
		elif i < current_room_index:
			mark = "√"
		elif i == current_room_index and started and not run_complete:
			mark = "→"
		lines.append("%s %d. %s" % [mark, i + 1, String(room.get("name", "未知房间"))])
	return lines

func _update_route_preview() -> void:
	_draw_route_map()
	route_preview_label.text = _build_route_legend()
	_update_reward_panel()

func _show_complete_overlay() -> void:
	complete_overlay.visible = true
	var total_rooms := room_templates.size()
	complete_summary_label.text = "总计 %d 房 / 用时 %s / 剩余生命 %d" % [total_rooms, _format_run_time(run_time), player.health]
	complete_loot_label.text = "战利：气势 %d / 法宝 %s" % [clear_reward_stacks, _get_collected_reward_text()]
	complete_route_label.text = "路线复盘：\n%s" % "\n".join(_get_route_lines())

func _draw_route_map() -> void:
	_clear_node_children(route_map_root)
	if room_templates.is_empty():
		return
	var total := room_templates.size()
	var columns := 5
	var step_x := 92.0
	var row_gap := 48.0
	var start_x := 20.0
	var start_y := 26.0
	var points: Array[Vector2] = []
	for i in range(total):
		var column := i % columns
		var row := floori(float(i) / float(columns))
		points.append(Vector2(start_x + step_x * float(column), start_y + row_gap * float(row)))
	for i in range(points.size() - 1):
		_add_route_link(points[i], points[i + 1], i < current_room_index or run_complete)
	for i in range(points.size()):
		_add_route_node(i, points[i])

func _add_route_link(from_point: Vector2, to_point: Vector2, cleared: bool) -> void:
	var delta := to_point - from_point
	var link := ColorRect.new()
	link.position = from_point + delta / 2.0 - Vector2(delta.length() / 2.0, 2.0)
	link.size = Vector2(delta.length(), 4.0)
	link.rotation = delta.angle()
	link.pivot_offset = Vector2(delta.length() / 2.0, 2.0)
	link.color = Color(0.76, 0.62, 0.34, 0.92) if cleared else Color(0.26, 0.31, 0.35, 0.9)
	route_map_root.add_child(link)

func _add_route_node(index: int, center: Vector2) -> void:
	var room := room_templates[index]
	var room_type := String(room.get("type", "combat"))
	var is_current := index == current_room_index and started and not run_complete
	var is_cleared := index < current_room_index or run_complete
	var node := ColorRect.new()
	node.position = center - Vector2(22.0, 22.0)
	node.size = Vector2(44.0, 44.0)
	node.color = _get_route_node_color(room_type, is_current, is_cleared)
	route_map_root.add_child(node)

	var marker := Label.new()
	marker.position = node.position + Vector2(0.0, 6.0)
	marker.size = node.size
	marker.text = _get_route_node_mark(room_type, is_current, is_cleared)
	marker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	marker.add_theme_font_size_override("font_size", 19)
	marker.add_theme_color_override("font_color", Color(0.98, 0.92, 0.76, 1))
	route_map_root.add_child(marker)

	var index_label := Label.new()
	index_label.position = node.position + Vector2(0.0, 26.0)
	index_label.size = node.size
	index_label.text = "%02d" % (index + 1)
	index_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	index_label.add_theme_font_size_override("font_size", 11)
	index_label.add_theme_color_override("font_color", Color(0.74, 0.82, 0.9, 1))
	route_map_root.add_child(index_label)

func _get_route_node_color(room_type: String, is_current: bool, is_cleared: bool) -> Color:
	if is_current:
		return Color(0.95, 0.62, 0.18, 1)
	if is_cleared:
		return Color(0.22, 0.54, 0.34, 0.95)
	if room_type == "rest":
		return Color(0.12, 0.38, 0.48, 0.92)
	if room_type == "elite":
		return Color(0.5, 0.22, 0.13, 0.92)
	if room_type == "boss":
		return Color(0.38, 0.16, 0.43, 0.92)
	return Color(0.18, 0.21, 0.24, 0.92)

func _get_route_node_mark(room_type: String, is_current: bool, is_cleared: bool) -> String:
	if is_current:
		return "今"
	if is_cleared:
		return "过"
	if room_type == "rest":
		return "宝"
	if room_type == "elite":
		return "精"
	if room_type == "boss":
		return "王"
	return "战"

func _build_route_legend() -> String:
	var current_name := "未知试炼"
	var current_type := "combat"
	if not room_templates.is_empty():
		var current_room := room_templates[current_room_index]
		current_name = String(current_room.get("name", current_name))
		current_type = String(current_room.get("type", current_type))
	return "第 %d/%d 关：%s · %s" % [current_room_index + 1, room_templates.size(), current_name, _get_room_type_label(current_type)]

func _update_encounter_panel(room_type: String) -> void:
	encounter_accent.color = _get_room_type_accent(room_type)
	if room_type == "boss":
		encounter_panel.color = Color(0.07, 0.04, 0.075, 0.92)
		encounter_type_label.text = "妖王战 · 高压阶段"
		encounter_hint_label.text = "先保命再输出，留意冲刺与召妖提示。"
		return
	if room_type == "elite":
		encounter_panel.color = Color(0.075, 0.045, 0.03, 0.92)
		encounter_type_label.text = "精英战 · 节奏突进"
		encounter_hint_label.text = "精英急袭前摇明显，横移拉开再反打。"
		return
	if room_type == "rest":
		encounter_panel.color = Color(0.03, 0.055, 0.072, 0.92)
		encounter_type_label.text = "宝物休整 · 无怪房"
		encounter_hint_label.text = "二选一法宝，按路线短板补强本局能力。"
		return
	encounter_panel.color = Color(0.04, 0.035, 0.03, 0.9)
	encounter_type_label.text = "普通战 · 清怪开门"
	encounter_hint_label.text = "优先处理贴身威胁，再清远端目标。"

func _update_run_state_banner(phase_hint: String = "") -> void:
	var room_type := current_room_type
	run_state_tag_label.text = _get_room_type_label(room_type)
	if room_type == "boss":
		run_state_accent.color = Color(0.78, 0.38, 0.88, 1)
		run_state_panel.color = Color(0.07, 0.04, 0.075, 0.9)
	elif room_type == "elite":
		run_state_accent.color = Color(0.95, 0.46, 0.22, 1)
		run_state_panel.color = Color(0.075, 0.045, 0.03, 0.9)
	elif room_type == "rest":
		run_state_accent.color = Color(0.28, 0.72, 0.9, 1)
		run_state_panel.color = Color(0.03, 0.055, 0.072, 0.9)
	else:
		run_state_accent.color = Color(0.74, 0.56, 0.24, 1)
		run_state_panel.color = Color(0.03, 0.035, 0.04, 0.88)

	var phase_text := phase_hint
	if doors_open:
		phase_text = "传送门已开"
	elif room_type == "rest":
		phase_text = "二选一抉择" if phase_text == "" else phase_text
	elif _can_fire_wind_shot():
		phase_text = "灵弹剩余 %d 发" % wind_shot_charges
	elif phase_text == "":
		phase_text = "交战中"
	run_state_phase_label.text = phase_text

func _build_pickup_cue_text(reward_type: String, reward_name: String) -> String:
	if reward_type == "speed":
		return "获得%s：移速提升（临时）" % reward_name
	if reward_type == "shield":
		return "获得%s：护盾层数 +1" % reward_name
	return "获得%s：弹速提升（临时）" % reward_name

func _show_pickup_cue(text_value: String) -> void:
	pickup_cue_label.text = text_value
	pickup_cue_timer = 1.5
	pickup_cue_label.visible = true

func _update_pickup_cue_visibility() -> void:
	pickup_cue_label.visible = pickup_cue_timer > 0.0 and started and not paused

func _update_reward_panel() -> void:
	var reward_name := last_reward_name
	if reward_name == "" or reward_name == "无":
		reward_name_label.text = "当前法宝：未持有"
		reward_effect_label.text = "效果：等待拾取灵珠"
		reward_state_label.text = "状态：未获得"
		_update_loot_list()
		reward_accent.color = Color(0.32, 0.72, 0.92, 1)
		return

	var shot_state := "临时 %d 发" % wind_shot_charges if _can_fire_wind_shot() else "未激活"
	var speed_time := _get_player_speed_boost_time()
	var speed_state := "临时" if speed_time > 0.0 else "未激活"
	var shield_state := "可抵伤 %d 次" % shield_charges if shield_charges > 0 else "未持有"
	reward_name_label.text = "当前法宝：%s" % reward_name
	reward_effect_label.text = "效果：气势层数 %d / 定风珠 %.0fs / 腾云符 %.0fs" % [clear_reward_stacks, shot_boost_timer, speed_time]
	reward_state_label.text = "状态：定风珠%s / 腾云符%s / 护身符%s" % [shot_state, speed_state, shield_state]
	_update_loot_list()
	reward_accent.color = Color(0.34, 0.84, 0.48, 1) if clear_reward_stacks > 0 else Color(0.32, 0.72, 0.92, 1)
	_update_reward_icon()

func _get_player_speed_boost_time() -> float:
	if player != null and player.has_method("get_speed_boost_time"):
		return float(player.call("get_speed_boost_time"))
	return 0.0

func _build_health_marks() -> String:
	var marks := ""
	for i in range(3):
		marks += "■" if i < player.health else "□"
	return marks

func _update_reward_icon() -> void:
	var icon_key := "pickup_shot"
	if last_reward_name == "腾云符":
		icon_key = "pickup_speed"
	elif last_reward_name == "护身符":
		icon_key = "pickup_shield"
	var texture: Texture2D = art_textures.get(icon_key)
	if hud_reward_icon != null:
		hud_reward_icon.texture = texture

func _record_reward(reward_name: String) -> void:
	if reward_name == "" or reward_name == "无":
		return
	if not collected_rewards.has(reward_name):
		collected_rewards.append(reward_name)
	_update_loot_list()

func _update_loot_list() -> void:
	if loot_list_label == null:
		return
	var reward_text := _get_collected_reward_text()
	loot_list_label.text = "法宝：%s / 气势 %d" % [reward_text, clear_reward_stacks]

func _get_collected_reward_text() -> String:
	if collected_rewards.is_empty():
		return "无"
	return "、".join(collected_rewards)
