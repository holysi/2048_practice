# scripts/WaveManager.gd
class_name WaveManager
extends Node

const WAVES: Array = [
	# Wave 1 — Basic intro
	{ "groups": [{ "type": 0, "count": 8, "interval": 1.2 }] },
	# Wave 2 — Add armored
	{ "groups": [{ "type": 0, "count": 6, "interval": 1.0 }, { "type": 1, "count": 2, "interval": 2.0 }] },
	# Wave 3 — Fast runners
	{ "groups": [{ "type": 0, "count": 5, "interval": 0.9 }, { "type": 2, "count": 4, "interval": 0.7 }] },
	# Wave 4 — Mixed
	{ "groups": [{ "type": 0, "count": 8, "interval": 0.8 }, { "type": 1, "count": 3, "interval": 1.8 }] },
	# Wave 5 — BOSS wave
	{ "groups": [{ "type": 0, "count": 10, "interval": 0.6 }, { "type": 4, "count": 1, "interval": 0.0 }] },
	# Wave 6 — Flying enemies
	{ "groups": [{ "type": 3, "count": 8, "interval": 0.8 }, { "type": 1, "count": 4, "interval": 1.5 }] },
	# Wave 7 — Swarm
	{ "groups": [{ "type": 2, "count": 15, "interval": 0.5 }] },
	# Wave 8 — Heavy assault
	{ "groups": [{ "type": 1, "count": 6, "interval": 1.2 }, { "type": 3, "count": 6, "interval": 0.7 }] },
	# Wave 9 — All types
	{ "groups": [{ "type": 0, "count": 5, "interval": 0.6 }, { "type": 2, "count": 5, "interval": 0.5 }, { "type": 3, "count": 5, "interval": 0.7 }] },
	# Wave 10 — Final BOSS
	{ "groups": [{ "type": 0, "count": 15, "interval": 0.5 }, { "type": 1, "count": 5, "interval": 1.0 }, { "type": 4, "count": 2, "interval": 0.0 }] },
]

var current_wave: int = 0
var _enemies_alive: int = 0
var _paused: bool = false

signal wave_started(wave_number: int)
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemy_reached_exit
signal enemy_killed(gold_value: int)

var enemy_scene: PackedScene
var enemy_container: Node
var waypoints: Array = []  # Array of Vector2 (world coords)

func start_next_wave() -> void:
	if current_wave >= WAVES.size():
		all_waves_completed.emit()
		return
	_enemies_alive = 0   # Reset for this wave
	var wave_data: Dictionary = WAVES[current_wave]
	current_wave += 1
	wave_started.emit(current_wave)
	_spawn_wave(wave_data)

func _spawn_wave(wave_data: Dictionary) -> void:
	var total := 0
	for group in wave_data["groups"]:
		total += group["count"]
	_enemies_alive = total  # Set exact count, not accumulate

	for group in wave_data["groups"]:
		for i in group["count"]:
			if _paused:
				return   # abandon in-flight coroutine on pause
			_spawn_enemy(group["type"])
			if group["interval"] > 0.0:
				await get_tree().create_timer(group["interval"]).timeout
				if not is_instance_valid(self):
					return

func _spawn_enemy(type_int: int) -> void:
	if not enemy_scene or not enemy_container:
		return
	var e: Enemy = enemy_scene.instantiate()
	e.enemy_type = type_int as Enemy.EnemyType
	e._waypoints = waypoints.duplicate()
	e.died.connect(_on_enemy_died)
	e.reached_exit.connect(_on_enemy_reached_exit)
	enemy_container.add_child(e)
	if waypoints.size() > 0:
		e.global_position = waypoints[0]

func _on_enemy_died(gold: int) -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	enemy_killed.emit(gold)
	_check_wave_complete()

func _on_enemy_reached_exit() -> void:
	_enemies_alive = max(0, _enemies_alive - 1)
	enemy_reached_exit.emit()  # Notify TowerDefense to deduct a life
	_check_wave_complete()

func _check_wave_complete() -> void:
	if _enemies_alive <= 0:
		wave_completed.emit(current_wave)

func reset() -> void:
	current_wave = 0
	_enemies_alive = 0
	_paused = false

func set_paused(v: bool) -> void:
	_paused = v
