# scripts/LevelSelect.gd
extends Control

@onready var level_list: VBoxContainer = $LevelList
@onready var level_title: Label = $LeaderboardPanel/LevelTitle
@onready var record_list: VBoxContainer = $LeaderboardPanel/RecordList
@onready var start_button: Button = $LeaderboardPanel/StartButton

var _selected_index: int = 0

func _ready() -> void:
	_build_level_buttons()
	start_button.pressed.connect(_on_start_pressed)
	_show_leaderboard(0)

func _build_level_buttons() -> void:
	var unlocked = SaveData.get_unlocked()
	for i in SaveData.LEVELS.size():
		var level = SaveData.LEVELS[i]
		var btn = Button.new()
		if i < unlocked:
			btn.text = level["name"]
		else:
			btn.text = level["name"] + "  🔒"
			btn.disabled = true
		var idx = i  # 捕獲迴圈變數
		btn.pressed.connect(func(): _on_level_pressed(idx))
		level_list.add_child(btn)

func _on_level_pressed(index: int) -> void:
	_selected_index = index
	_show_leaderboard(index)

func _on_start_pressed() -> void:
	SaveData.current_level_index = _selected_index
	get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _show_leaderboard(index: int) -> void:
	var level = SaveData.LEVELS[index]
	level_title.text = level["name"] + "  排行榜"
	for child in record_list.get_children():
		child.free()
	var records = SaveData.get_records(level["target"])
	if records.is_empty():
		var empty_label = Label.new()
		empty_label.text = "尚無紀錄"
		record_list.add_child(empty_label)
		return
	for i in records.size():
		var r = records[i]
		var row = Label.new()
		row.text = "#%d　%d 分　%.1f 秒" % [i + 1, r["score"], r["time"]]
		record_list.add_child(row)
