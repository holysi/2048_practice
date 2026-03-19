# scripts/Tower.gd
class_name Tower
extends Node2D

enum TowerType { BASIC, SNIPER, SPLASH, SLOW, LASER }

@export var tower_type: TowerType = TowerType.BASIC
var level: int = 1
var grid_cell: Vector2i

# Loaded from TowerData.STATS
var damage: int = 10
var range_px: float = 80.0
var fire_rate: float = 1.0
var upgrade_cost: int = 75
var _can_hit_flying: bool = false

var _td: Node = null               # TowerDefense reference
var _projectile_scene: PackedScene = null

@onready var detection_area: Area2D = $DetectionArea
@onready var attack_timer: Timer = $AttackTimer
@onready var body: ColorRect = $Body
@onready var range_indicator: Node2D = $RangeIndicator

var _target: Enemy = null

func _ready() -> void:
	_apply_stats()
	_update_visuals()
	attack_timer.wait_time = 1.0 / fire_rate
	attack_timer.one_shot = false
	attack_timer.autostart = true
	attack_timer.timeout.connect(_on_attack_timer_timeout)
	var col := $DetectionArea/CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = range_px
	col.shape = circle
	detection_area.body_entered.connect(_on_body_entered)
	detection_area.body_exited.connect(_on_body_exited)
	detection_area.set_collision_mask_value(2, true)  # ground enemies
	if _can_hit_flying:
		detection_area.set_collision_mask_value(3, true)

func _apply_stats() -> void:
	var stats: Dictionary = TowerData.STATS[tower_type][level]
	damage = stats["damage"]
	range_px = stats["range"]
	fire_rate = stats["fire_rate"]
	upgrade_cost = stats["upgrade_cost"]
	_can_hit_flying = tower_type in [TowerType.SPLASH, TowerType.SLOW, TowerType.LASER]

func _update_visuals() -> void:
	var colors := [
		Color(0.2, 0.6, 1.0),   # BASIC — blue
		Color(0.8, 0.8, 0.2),   # SNIPER — yellow
		Color(0.9, 0.4, 0.1),   # SPLASH — orange
		Color(0.2, 0.9, 0.7),   # SLOW — cyan
		Color(0.9, 0.2, 0.9),   # LASER — magenta
	]
	body.color = colors[tower_type]

func _on_body_entered(body_node: Node2D) -> void:
	if body_node is Enemy and _target == null:
		_target = body_node

func _on_body_exited(body_node: Node2D) -> void:
	if body_node == _target:
		_target = null
		_find_best_target()

func _find_best_target() -> void:
	var bodies := detection_area.get_overlapping_bodies()
	var best: Enemy = null
	var best_progress := -1.0
	for b in bodies:
		if b is Enemy and b.path_progress > best_progress:
			best = b
			best_progress = b.path_progress
	_target = best

func _on_attack_timer_timeout() -> void:
	if _target == null or not is_instance_valid(_target):
		_find_best_target()
	if _target == null or not is_instance_valid(_target):
		return
	_fire()

func _fire() -> void:
	if _projectile_scene == null or _td == null:
		return
	var p: Projectile = _projectile_scene.instantiate()
	p.global_position = global_position
	match tower_type:
		TowerType.SPLASH:
			p.splash_radius = 50.0
		TowerType.SLOW:
			p.slow_factor = 0.5
			p.slow_duration = 2.0
		_:
			pass
	p.init(_target, damage, 300.0, _td)
	_td.projectile_container.add_child(p)

func upgrade() -> void:
	if upgrade_cost == 0:
		return  # max level
	level += 1
	_apply_stats()
	# Update collision shape radius
	var col := $DetectionArea/CollisionShape2D
	if col.shape is CircleShape2D:
		col.shape.radius = range_px
	attack_timer.wait_time = 1.0 / fire_rate
	_update_visuals()
