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

func _ready() -> void:
	# Wait for layout to resolve so size is valid
	await get_tree().process_frame
	_build_world_waypoints()
	_init_grid()
	_draw_path()
	_setup_wave_manager()
	GameManager.gold_changed.connect(_on_gold_changed)
	wave_button.pressed.connect(_on_wave_button_pressed)
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)

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
		if _dist_point_to_segment(cell_center, a, b) < cell_size.length() * 0.8:
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

func _on_wave_button_pressed() -> void:
	wave_button.disabled = true
	wave_manager.start_next_wave()

func _on_wave_started(wave_num: int) -> void:
	wave_label.text = "Wave %d/%d" % [wave_num, WaveManager.WAVES.size()]

func _on_wave_completed(_wave_num: int) -> void:
	if wave_manager.current_wave < WaveManager.WAVES.size():
		wave_button.text = "Start Wave %d" % (wave_manager.current_wave + 1)
		wave_button.disabled = false
	else:
		wave_label.text = "Victory!"

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
