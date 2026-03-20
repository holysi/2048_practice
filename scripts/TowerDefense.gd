# scripts/TowerDefense.gd
extends Control

# Normalized waypoints (0..1) — enemies enter from RIGHT, exit LEFT (toward base)
const WAYPOINTS_NORMALIZED: Array = [
	Vector2(1.0, 0.25),
	Vector2(0.7, 0.25),
	Vector2(0.7, 0.65),
	Vector2(0.3, 0.65),
	Vector2(0.3, 0.25),
	Vector2(0.0, 0.25),
]

const GRID_COLS: int = 64
const GRID_ROWS: int = 64
const MAX_LIVES: int = 20
const UI_BAR_H: int = 32   # height of top and bottom info bars (px)

var lives: int = MAX_LIVES
var _world_waypoints: Array = []   # Array of Vector2, world coords
var _grid: Array = []              # Array[Array] of Tower or null
var _blocked: Array = []           # Array[Array] of bool — path cells

@onready var enemy_container: Node2D = $PathLayer/EnemyContainer
@onready var tower_container: Node2D = $MapLayer/TowerContainer
@onready var projectile_container: Node2D = $ProjectileContainer
@onready var wave_manager: WaveManager = $WaveManager
@onready var gold_label: Label = $UI/TopBar/GoldLabel
@onready var lives_label: Label = $UI/TopBar/LivesLabel
@onready var wave_label: Label = $UI/BottomBar/WaveLabel
@onready var wave_button: Button = $UI/BottomBar/WaveButton
@onready var path_visual: Line2D = $PathVisual

@export var enemy_scene: PackedScene
@export var tower_scene: PackedScene
@export var projectile_scene: PackedScene

var cell_size: float = 1.0    # computed in _ready after layout
var grid_offset: Vector2 = Vector2.ZERO   # offset from TowerDefense origin to grid top-left

var _selected_tower_type: int = 0  # default BASIC
var _info_panel: PanelContainer = null
var _wave_countdown_active: bool = false
var _wave_launching: bool = false
var _countdown_wave_num: int = 0
var _td_game_over: bool = false

func _ready() -> void:
	# Wait for layout to resolve so size is valid
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_compute_cell_size()        # 1. must run first — cell_size/grid_offset used by everything below
	_build_world_waypoints()    # 2. uses cell_size + grid_offset
	_init_grid()                # 3. calls _is_cell_on_path → uses cell_size + grid_offset
	_draw_path()
	_setup_wave_manager()
	if not GameManager.gold_changed.is_connected(_on_gold_changed):
		GameManager.gold_changed.connect(_on_gold_changed)
	if not GameManager.bomb_aoe_requested.is_connected(_on_bomb_aoe_requested):
		GameManager.bomb_aoe_requested.connect(_on_bomb_aoe_requested)
	wave_button.pressed.connect(_on_wave_button_pressed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	# Connect tower palette buttons — added dynamically below
	_build_tower_palette()

func _compute_cell_size() -> void:
	var available_w: float = size.x
	var available_h: float = size.y - 2.0 * UI_BAR_H
	cell_size = min(available_w / GRID_COLS, available_h / GRID_ROWS)
	var grid_w: float = cell_size * GRID_COLS
	var grid_h: float = cell_size * GRID_ROWS
	# grid_offset.y = UI_BAR_H: grid starts below top bar
	# grid_offset.x: center horizontally if grid is narrower than panel
	grid_offset = Vector2((size.x - grid_w) / 2.0, float(UI_BAR_H))

func _build_world_waypoints() -> void:
	_world_waypoints.clear()
	var grid_size := Vector2(cell_size * GRID_COLS, cell_size * GRID_ROWS)
	for npt in WAYPOINTS_NORMALIZED:
		_world_waypoints.append(grid_offset + npt * grid_size)

func _draw_path() -> void:
	path_visual.clear_points()
	for pt in _world_waypoints:
		path_visual.add_point(pt)

func _init_grid() -> void:
	_grid.clear()
	_blocked.clear()
	for row in GRID_ROWS:
		var grid_row := []
		var blocked_row := []
		for col in GRID_COLS:
			grid_row.append(null)
			blocked_row.append(_is_cell_on_path(row, col))
		_grid.append(grid_row)
		_blocked.append(blocked_row)

func _is_cell_on_path(row: int, col: int) -> bool:
	var cell_center := grid_offset + Vector2(col + 0.5, row + 0.5) * cell_size
	for i in range(_world_waypoints.size() - 1):
		var a: Vector2 = _world_waypoints[i]
		var b: Vector2 = _world_waypoints[i + 1]
		if _dist_point_to_segment(cell_center, a, b) < cell_size * 0.6:
			return true
	return false

func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t: float = clamp(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _setup_wave_manager() -> void:
	wave_manager.enemy_scene = enemy_scene
	wave_manager.enemy_container = enemy_container
	# Convert local waypoints → global so enemies (CharacterBody2D) spawn correctly.
	# _world_waypoints are in TowerDefense local space; enemies use global_position.
	var origin: Vector2 = get_global_rect().position
	var global_waypoints: Array = []
	for wp in _world_waypoints:
		global_waypoints.append(wp + origin)
	wave_manager.waypoints = global_waypoints
	wave_manager.enemy_reached_exit.connect(_on_enemy_reached_exit)
	wave_manager.enemy_killed.connect(_on_enemy_killed)

func _on_wave_button_pressed() -> void:
	if _wave_countdown_active:
		# Skip countdown — launch immediately
		_wave_countdown_active = false
		_launch_wave()
	else:
		# First wave (no countdown)
		_launch_wave()

func _on_wave_started(wave_num: int) -> void:
	_wave_launching = false
	wave_label.text = "Wave %d/%d" % [wave_num, WaveManager.WAVES.size()]
	wave_button.text = "Wave in progress..."

func _on_wave_completed(_wave_num: int) -> void:
	if wave_manager.current_wave >= WaveManager.WAVES.size():
		_on_all_waves_completed()
		return
	_countdown_wave_num = wave_manager.current_wave + 1
	_wave_countdown_active = true
	wave_button.disabled = false
	_run_countdown(3)

func _run_countdown(secs_left: int) -> void:
	if not _wave_countdown_active:
		return
	wave_button.text = "Wave %d (%ds)" % [_countdown_wave_num, secs_left]
	if secs_left <= 0:
		_wave_countdown_active = false
		_launch_wave()
		return
	await get_tree().create_timer(1.0).timeout
	if not is_instance_valid(self) or not _wave_countdown_active:
		return
	_run_countdown(secs_left - 1)

func _launch_wave() -> void:
	if _wave_launching:
		return
	_wave_launching = true
	_wave_countdown_active = false
	wave_button.disabled = true
	wave_button.text = "Wave in progress..."
	wave_manager.start_next_wave()

func _on_all_waves_completed() -> void:
	var overlay := ColorRect.new()
	overlay.color = Color(0.1, 0.3, 0.1, 0.8)
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.custom_minimum_size = Vector2(200, 0)
	overlay.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var title := Label.new()
	title.text = "Waves Cleared! 🎉"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	wave_label.text = "All Waves Done!"

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_enemy_reached_exit() -> void:
	if _td_game_over:   # prevent double-trigger from simultaneous exits
		return
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		_game_over()

func _pause_all_enemies() -> void:
	for e in enemy_container.get_children():
		if e is Enemy:
			e.set_physics_process(false)

func _stop_all_tower_timers() -> void:
	for tower in tower_container.get_children():
		if tower is Tower:
			tower.get_node("AttackTimer").stop()

func _game_over() -> void:
	_td_game_over = true
	wave_button.disabled = true
	_pause_all_enemies()
	_stop_all_tower_timers()
	wave_manager.set_paused(true)

	var overlay := ColorRect.new()
	overlay.name = "GameOverOverlay"
	overlay.color = Color(0, 0, 0, 0.75)
	add_child(overlay)
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	var panel := VBoxContainer.new()
	panel.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.custom_minimum_size = Vector2(220, 0)
	overlay.add_child(panel)
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical   = Control.GROW_DIRECTION_BOTH

	var title := Label.new()
	title.text = "💀 基地淪陷！"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(title)

	var sub := Label.new()
	sub.text = "所有敵人暫停移動"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	panel.add_child(sub)

	# Bomb button — only shown when player has bombs
	if GameManager.bomb_count > 0:
		var bomb_btn := Button.new()
		bomb_btn.name = "BombBtn"
		bomb_btn.text = "💣 投放炸彈 (×%d)" % GameManager.bomb_count
		bomb_btn.pressed.connect(func():
			_on_bomb_aoe_requested(Vector2.ZERO)
			# Refresh or hide button after use
			if GameManager.bomb_count <= 0:
				bomb_btn.queue_free()
			else:
				bomb_btn.text = "💣 投放炸彈 (×%d)" % GameManager.bomb_count
		)
		panel.add_child(bomb_btn)

	var retry_btn := Button.new()
	retry_btn.text = "↺ 重新開始"
	retry_btn.pressed.connect(_restart_td)
	panel.add_child(retry_btn)

func _restart_td() -> void:
	_td_game_over = false
	wave_manager.set_paused(false)
	GameManager.reset()   # restores gold to STARTING_GOLD, resets bomb_count mirror
	lives = MAX_LIVES
	lives_label.text = "Lives: %d" % lives
	wave_button.disabled = false
	wave_button.text = "Start Wave 1"
	wave_manager.reset()
	# Clear all enemies
	for child in enemy_container.get_children():
		child.queue_free()
	# Clear all towers and reset grid
	for child in tower_container.get_children():
		child.queue_free()
	_init_grid()
	# Remove game-over overlay if present
	var go_overlay := get_node_or_null("GameOverOverlay")
	if go_overlay:
		go_overlay.queue_free()
	_wave_countdown_active = false
	_wave_launching = false

func _build_tower_palette() -> void:
	var palette := $UI/BottomBar
	# Remove WaveButton temporarily — keep it but add tower buttons before it
	var tower_names := ["⚔ Basic\n50g", "🎯 Sniper\n80g", "💥 Splash\n100g", "❄ Slow\n70g", "⚡ Laser\n120g"]
	for i in tower_names.size():
		var btn := Button.new()
		btn.text = tower_names[i]
		btn.size_flags_horizontal = SIZE_EXPAND_FILL
		btn.pressed.connect(_on_tower_type_selected.bind(i))
		palette.add_child(btn)
		palette.move_child(btn, i)  # insert before WaveButton

func _on_tower_type_selected(type_int: int) -> void:
	_selected_tower_type = type_int

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not get_global_rect().has_point(event.position):
			return
		var local_pos := get_local_mouse_position()
		var cell := world_to_cell(local_pos)
		if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
			return
		var existing = _grid[cell.y][cell.x]
		if existing != null:
			_show_tower_info(existing)
		elif is_cell_placeable(cell):
			_close_tower_info()
			var cost: int = TowerData.STATS[_selected_tower_type][1]["cost"]
			if GameManager.spend_gold(cost):
				_place_tower(cell, _selected_tower_type)


func _show_tower_info(tower: Tower) -> void:
	_close_tower_info()
	var type_names := ["Basic", "Sniper", "Splash", "Slow", "Laser"]
	_info_panel = PanelContainer.new()
	_info_panel.custom_minimum_size = Vector2(160, 0)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	_info_panel.add_child(vbox)

	var title := Label.new()
	title.text = "%s Lv.%d" % [type_names[tower.tower_type], tower.level]
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var stats_lbl := Label.new()
	stats_lbl.text = "DMG: %d  RNG: %d\nRate: %.1f/s" % [tower.damage, int(tower.range_px), tower.fire_rate]
	vbox.add_child(stats_lbl)

	var gold_lbl := Label.new()
	gold_lbl.text = "💰 %d gold" % GameManager.gold
	gold_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(gold_lbl)

	if tower.upgrade_cost > 0:
		var upg_btn := Button.new()
		upg_btn.text = "Upgrade\n%d gold" % tower.upgrade_cost
		upg_btn.pressed.connect(func(): _upgrade_tower(tower))
		vbox.add_child(upg_btn)
	else:
		var max_lbl := Label.new()
		max_lbl.text = "MAX LEVEL"
		max_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vbox.add_child(max_lbl)

	var sell_btn := Button.new()
	var original_cost: int = TowerData.STATS[tower.tower_type][1]["cost"]
	sell_btn.text = "Sell\n%dg" % (original_cost / 2)
	sell_btn.pressed.connect(func():
		GameManager.earn_gold(original_cost / 2)
		_grid[tower.grid_cell.y][tower.grid_cell.x] = null
		_blocked[tower.grid_cell.y][tower.grid_cell.x] = false
		tower.queue_free()
		_close_tower_info()
	)
	vbox.add_child(sell_btn)

	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(_close_tower_info)
	vbox.add_child(close_btn)

	# Position near the tower, clamped inside bounds
	var world_pos := cell_to_world(tower.grid_cell)
	_info_panel.position = world_pos + Vector2(20, -80)

	add_child(_info_panel)
	# Clamp after adding so size is resolved next frame
	await get_tree().process_frame
	if not is_instance_valid(_info_panel):
		return
	_info_panel.position.x = clamp(_info_panel.position.x, 0.0, size.x - _info_panel.size.x)
	_info_panel.position.y = clamp(_info_panel.position.y, 0.0, size.y - _info_panel.size.y)


func _close_tower_info() -> void:
	if is_instance_valid(_info_panel):
		_info_panel.queue_free()
	_info_panel = null


func _upgrade_tower(tower: Tower) -> void:
	if tower.upgrade_cost <= 0:
		return
	if GameManager.spend_gold(tower.upgrade_cost):
		tower.upgrade()
		_show_tower_info(tower)   # Refresh panel

func _place_tower(cell: Vector2i, type_int: int) -> void:
	if tower_scene == null:
		return
	var t: Tower = tower_scene.instantiate()
	t.tower_type = type_int as Tower.TowerType
	t.grid_cell = cell
	t.init(self, projectile_scene)
	var world_pos := cell_to_world(cell)
	t.position = world_pos
	tower_container.add_child(t)
	_grid[cell.y][cell.x] = t
	_blocked[cell.y][cell.x] = true  # occupied

func apply_aoe_damage(center: Vector2, radius: float, damage: int) -> void:
	for enemy in enemy_container.get_children():
		if enemy is Enemy and enemy.global_position.distance_to(center) <= radius:
			enemy.take_damage(damage)

func cell_to_world(cell: Vector2i) -> Vector2:
	return grid_offset + Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var local := world_pos - grid_offset
	return Vector2i(int(local.x / cell_size), int(local.y / cell_size))

func is_cell_placeable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
		return false
	return not _blocked[cell.y][cell.x] and _grid[cell.y][cell.x] == null

func _on_enemy_killed(gold_value: int) -> void:
	GameManager.earn_gold(gold_value)

func _on_bomb_aoe_requested(_world_pos: Vector2) -> void:
	# Explode at center of the TD map
	var center := get_global_rect().get_center()
	apply_aoe_damage(center, size.x * 0.4, 80)
	_play_bomb_flash()

func _play_bomb_flash() -> void:
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.5)
	add_child(flash)
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	var tween := create_tween()
	tween.tween_property(flash, "modulate:a", 0.0, 0.4)
	tween.tween_callback(flash.queue_free)
