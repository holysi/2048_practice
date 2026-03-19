# scripts/TowerDefense.gd
extends Control

# Normalized waypoints (0..1) — converted to world coords after layout
const WAYPOINTS_NORMALIZED: Array = [
	Vector2(0.0, 0.3),
	Vector2(0.3, 0.3),
	Vector2(0.3, 0.7),
	Vector2(0.7, 0.7),
	Vector2(0.7, 0.3),
	Vector2(1.0, 0.3),
]

const GRID_COLS: int = 10
const GRID_ROWS: int = 14
const MAX_LIVES: int = 20

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

var _selected_tower_type: int = 0  # default BASIC
var _info_panel: PanelContainer = null
var _wave_countdown_active: bool = false
var _countdown_wave_num: int = 0

func _ready() -> void:
	# Wait for layout to resolve so size is valid
	await get_tree().process_frame
	if not is_instance_valid(self):
		return
	_build_world_waypoints()
	_init_grid()
	_draw_path()
	_setup_wave_manager()
	GameManager.gold_changed.connect(_on_gold_changed)
	wave_button.pressed.connect(_on_wave_button_pressed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	# Connect tower palette buttons — added dynamically below
	_build_tower_palette()

func _build_world_waypoints() -> void:
	_world_waypoints.clear()
	for npt in WAYPOINTS_NORMALIZED:
		_world_waypoints.append(npt * size)

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
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	var cell_center := Vector2(col + 0.5, row + 0.5) * cell_size
	for i in range(_world_waypoints.size() - 1):
		var a: Vector2 = _world_waypoints[i]
		var b: Vector2 = _world_waypoints[i + 1]
		if _dist_point_to_segment(cell_center, a, b) < cell_size.x * 0.6:
			return true
	return false

func _dist_point_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var ap := p - a
	var t := clamp(ap.dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

func _setup_wave_manager() -> void:
	wave_manager.enemy_scene = enemy_scene
	wave_manager.enemy_container = enemy_container
	wave_manager.waypoints = _world_waypoints.duplicate()
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
	wave_button.disabled = true
	wave_button.text = "Wave in progress..."
	wave_manager.start_next_wave()

func _on_all_waves_completed() -> void:
	wave_label.text = "All Waves Done!"

func _on_gold_changed(amount: int) -> void:
	gold_label.text = "Gold: %d" % amount

func _on_enemy_reached_exit() -> void:
	lives -= 1
	lives_label.text = "Lives: %d" % lives
	if lives <= 0:
		_game_over()

func _game_over() -> void:
	# Phase 7 will add full game-over overlay
	wave_button.text = "GAME OVER"
	wave_button.disabled = true

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
		var existing := _grid[cell.y][cell.x]
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
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	return Vector2(cell.x + 0.5, cell.y + 0.5) * cell_size

func world_to_cell(world_pos: Vector2) -> Vector2i:
	var cell_size := size / Vector2(GRID_COLS, GRID_ROWS)
	return Vector2i(int(world_pos.x / cell_size.x), int(world_pos.y / cell_size.y))

func is_cell_placeable(cell: Vector2i) -> bool:
	if cell.x < 0 or cell.x >= GRID_COLS or cell.y < 0 or cell.y >= GRID_ROWS:
		return false
	return not _blocked[cell.y][cell.x] and _grid[cell.y][cell.x] == null

func _on_enemy_killed(gold_value: int) -> void:
	GameManager.earn_gold(gold_value)
