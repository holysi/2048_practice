# scripts/Enemy.gd
class_name Enemy
extends CharacterBody2D

enum EnemyType { BASIC, ARMORED, FAST, FLYING, BOSS }

@export var enemy_type: EnemyType = EnemyType.BASIC

var max_hp: int = 60
var hp: int = 60
var speed: float = 80.0
var armor: int = 0
var gold_reward: int = 10
var slow_factor: float = 1.0   # multiplied by speed; 0.5 = half speed

var _waypoints: Array = []     # Array of Vector2, assigned by WaveManager
var _waypoint_index: int = 0
var path_progress: float = 0.0  # 0..1, used for tower targeting priority

signal died(gold_value: int)
signal reached_exit

@onready var hp_bar: ProgressBar = $HPBar

func _ready() -> void:
	# Set collision shape
	var col_shape := $CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	col_shape.shape = circle
	# Set physics layer (enemies on layer 2)
	set_collision_layer_value(2, true)
	set_collision_layer_value(1, false)
	set_collision_mask_value(1, false)
	_apply_stats()
	if _waypoints.size() > 0:
		global_position = _waypoints[0]

func _apply_stats() -> void:
	var colors := [Color(0.8, 0.2, 0.2), Color(0.5, 0.5, 0.5), Color(0.9, 0.8, 0.1), Color(0.2, 0.4, 0.9), Color(0.6, 0.1, 0.8)]
	match enemy_type:
		EnemyType.BASIC:
			max_hp = 60; hp = 60; speed = 80.0; armor = 0; gold_reward = 10
		EnemyType.ARMORED:
			max_hp = 150; hp = 150; speed = 55.0; armor = 8; gold_reward = 20
		EnemyType.FAST:
			max_hp = 35; hp = 35; speed = 160.0; armor = 0; gold_reward = 15
		EnemyType.FLYING:
			max_hp = 80; hp = 80; speed = 100.0; armor = 0; gold_reward = 18
		EnemyType.BOSS:
			max_hp = 800; hp = 800; speed = 40.0; armor = 15; gold_reward = 100
	$Body.color = colors[enemy_type]

func _physics_process(delta: float) -> void:
	if _waypoint_index >= _waypoints.size():
		reached_exit.emit()
		queue_free()
		return
	var target_pos: Vector2 = _waypoints[_waypoint_index]
	var dir := (target_pos - global_position).normalized()
	velocity = dir * speed * slow_factor
	move_and_slide()
	if global_position.distance_to(target_pos) < 6.0:
		_waypoint_index += 1
		path_progress = float(_waypoint_index) / float(_waypoints.size())

func take_damage(amount: int) -> void:
	var actual := max(1, amount - armor)
	hp -= actual
	if hp_bar:
		hp_bar.value = float(hp) / float(max_hp) * 100.0
	if hp <= 0:
		died.emit(gold_reward)
		queue_free()

func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	await get_tree().create_timer(duration).timeout
	if is_instance_valid(self):
		slow_factor = 1.0
