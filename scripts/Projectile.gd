# scripts/Projectile.gd
class_name Projectile
extends Area2D

var damage: int = 10
var speed: float = 300.0
var splash_radius: float = 0.0   # 0 = single target; >0 = AOE on impact
var slow_factor: float = 0.0     # 0 = no slow; e.g. 0.5 = slow to 50% speed
var slow_duration: float = 1.5

var _target: Enemy = null
var _td: Node = null   # reference to TowerDefense for apply_aoe_damage

func _ready() -> void:
	var col := $CollisionShape2D
	var circle := CircleShape2D.new()
	circle.radius = 4.0
	col.shape = circle
	set_collision_layer_value(1, false)
	set_collision_mask_value(2, true)   # detect enemy layer 2

func init(target: Enemy, dmg: int, spd: float, td_ref: Node) -> void:
	_target = target
	damage = dmg
	speed = spd
	_td = td_ref

func _physics_process(delta: float) -> void:
	if _target == null or not is_instance_valid(_target):
		queue_free()
		return
	var dir := (_target.global_position - global_position).normalized()
	global_position += dir * speed * delta
	if global_position.distance_to(_target.global_position) < 8.0:
		_on_impact()

func _on_impact() -> void:
	if splash_radius > 0.0 and _td != null:
		_td.apply_aoe_damage(global_position, splash_radius, damage)
	else:
		if is_instance_valid(_target):
			_target.take_damage(damage)
			if slow_factor > 0.0:
				_target.apply_slow(slow_factor, slow_duration)
	queue_free()
