# scripts/SaveData.gd
extends Node

const SAVE_PATH = "user://save.json"
const MAX_RECORDS = 5

const LEVELS = [
	{
		"target": 128, "name": "Lv.1 — 128",
		"spawn_pool": [2, 4], "spawn_weights": [90, 10],
	},
	{
		"target": 256, "name": "Lv.2 — 256",
		"spawn_pool": [2, 4], "spawn_weights": [90, 10],
	},
	{
		"target": 512, "name": "Lv.3 — 512",
		"spawn_pool": [2, 4, 8, 16], "spawn_weights": [50, 25, 15, 10],
	},
	{
		"target": 1024, "name": "Lv.4 — 1024",
		"spawn_pool": [2, 4, 8, 16, 32], "spawn_weights": [50, 25, 12, 8, 5],
	},
	{
		"target": 2048, "name": "Lv.5 — 2048",
		"spawn_pool": [2, 4, 8, 16, 32, 64], "spawn_weights": [45, 25, 12, 8, 6, 4],
	},
]

var current_level_index: int = 0  # 場景切換用，LevelSelect 寫入，Game 讀取

var _data: Dictionary = {}

func _ready() -> void:
	_load()

func get_unlocked() -> int:
	return _data.get("unlocked_levels", 1)

func get_records(target: int) -> Array:
	return _data.get("records", {}).get(str(target), [])

func submit_record(target: int, score: int, time: float) -> void:
	var key = str(target)
	var list: Array = _data["records"].get(key, [])
	list.append({ "score": score, "time": time })
	list.sort_custom(func(a, b):
		if a["score"] != b["score"]:
			return a["score"] > b["score"]
		return a["time"] < b["time"]
	)
	if list.size() > MAX_RECORDS:
		list.resize(MAX_RECORDS)
	_data["records"][key] = list
	_save()

func unlock_next(current_index: int) -> void:
	var needed = current_index + 2
	var capped = min(needed, LEVELS.size())
	if capped > _data.get("unlocked_levels", 1):
		_data["unlocked_levels"] = capped
		_save()

func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		_data = _default_data()
		return
	var f = FileAccess.open(SAVE_PATH, FileAccess.READ)
	var text = f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(text)
	if parsed == null or not parsed is Dictionary:
		_data = _default_data()
		return
	# 確保 records 鍵存在（防止舊版存檔或手動修改導致 key 缺失）
	if not parsed.has("records") or not parsed["records"] is Dictionary:
		_data = _default_data()
		return
	_data = parsed

func _save() -> void:
	var f = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("SaveData: failed to open save file for writing")
		return
	f.store_string(JSON.stringify(_data))
	f.close()

func _default_data() -> Dictionary:
	return {
		"unlocked_levels": 1,
		"records": { "128": [], "256": [], "512": [], "1024": [], "2048": [] }
	}
