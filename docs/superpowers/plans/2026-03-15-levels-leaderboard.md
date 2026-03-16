# 關卡系統與排行榜 Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在現有 2048 MVP 上加入五個依序解鎖的目標關卡（128/256/512/1024/2048）、計時器、本機 Top 5 排行榜，以及通關勝利畫面。

**Architecture:** 新增 `SaveData.gd`（AutoLoad 單例）管理存檔與關卡常數；新增 `LevelSelect.tscn` 作為關卡選擇與排行榜畫面；`Game.gd` 接收 `target_tile` 並加入計時與通關偵測；`Main.tscn` 改為直接 instance `LevelSelect.tscn`。

**Tech Stack:** Godot 4.x, GDScript, `user://save.json`（JSON 本機存檔）

---

## 檔案結構

| 檔案 | 職責 | 狀態 |
|------|------|------|
| `scripts/SaveData.gd` | AutoLoad 單例：關卡常數、存檔讀寫、解鎖邏輯、排行榜排序 | 新增 |
| `scripts/LevelSelect.gd` | 關卡選擇邏輯：讀取 SaveData、動態生成按鈕、顯示排行榜 | 新增 |
| `scenes/LevelSelect.tscn` | 關卡選擇畫面節點樹 | 新增 |
| `scripts/Game.gd` | 加入 target_tile、計時、win 偵測、_show_win()、修改 restart() | 修改 |
| `scenes/Main.tscn` | 改為 instance LevelSelect.tscn | 修改 |
| `project.godot` | 新增 SaveData AutoLoad 設定 | 修改 |

---

## Chunk 1: SaveData AutoLoad

### Task 1: 建立 SaveData.gd 並設為 AutoLoad

**Files:**
- Create: `scripts/SaveData.gd`
- Modify: `project.godot`

- [ ] **Step 1: 建立 `scripts/SaveData.gd`**

  ```gdscript
  # scripts/SaveData.gd
  extends Node

  const SAVE_PATH = "user://save.json"
  const MAX_RECORDS = 5

  const LEVELS = [
	  { "target": 128,  "name": "Lv.1 — 128" },
	  { "target": 256,  "name": "Lv.2 — 256" },
	  { "target": 512,  "name": "Lv.3 — 512" },
	  { "target": 1024, "name": "Lv.4 — 1024" },
	  { "target": 2048, "name": "Lv.5 — 2048" },
  ]

  var current_level_index: int = 0  # 場景切換用，LevelSelect 寫入，Game 讀取

  var _data: Dictionary = {}

  func _ready() -> void:
	  _load()

  func get_unlocked() -> int:
	  return _data.get("unlocked_levels", 1)

  func get_records(target: int) -> Array:
	  return _data["records"].get(str(target), [])

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
	  f.store_string(JSON.stringify(_data))
	  f.close()

  func _default_data() -> Dictionary:
	  return {
		  "unlocked_levels": 1,
		  "records": { "128": [], "256": [], "512": [], "1024": [], "2048": [] }
	  }
  ```

- [ ] **Step 2: 在 `project.godot` 加入 AutoLoad 設定**

  在 `project.godot` 的 `[application]` 區段**之後**加入：

  ```ini
  [autoload]

  SaveData="*res://scripts/SaveData.gd"
  ```

  `*` 前綴表示 Godot 會自動實例化並加入 SceneTree 根節點。

- [ ] **Step 3: 在 Godot 編輯器中驗證 AutoLoad 已載入**

  - 開啟 Godot 編輯器（重新掃描專案）
  - 前往 Project → Project Settings → Autoload
  - 確認列表中出現 `SaveData`，路徑為 `res://scripts/SaveData.gd`，Singleton 欄已勾選

- [ ] **Step 4: 手動驗證 SaveData 邏輯**

  開啟 Godot 的 Script 面板，執行以下片段驗證行為（或直接在 _ready 中臨時加入後執行遊戲）：

  ```gdscript
  # 驗證預期行為（在任何場景的 _ready 臨時加入，驗證後刪除）

  # 基本預設值
  print(SaveData.get_unlocked())         # 期望：1
  print(SaveData.get_records(128))       # 期望：[]

  # 排序：高分在前
  SaveData.submit_record(128, 3200, 47.3)
  SaveData.submit_record(128, 5000, 60.0)
  var recs = SaveData.get_records(128)
  print(recs[0]["score"])                # 期望：5000
  print(recs[1]["score"])                # 期望：3200

  # 同分時時間較短排前
  SaveData.submit_record(128, 5000, 40.0)
  recs = SaveData.get_records(128)
  print(recs[0]["time"])                 # 期望：40.0（較短時間排前）
  print(recs[1]["time"])                 # 期望：60.0

  # MAX_RECORDS 上限（最多 5 筆）
  SaveData.submit_record(128, 100, 10.0)
  SaveData.submit_record(128, 200, 10.0)
  SaveData.submit_record(128, 300, 10.0)
  recs = SaveData.get_records(128)
  print(recs.size())                     # 期望：5（不超過 MAX_RECORDS）

  # unlock_next 解鎖邏輯
  SaveData.unlock_next(0)                # 通關 index 0 → 需解鎖到 2
  print(SaveData.get_unlocked())         # 期望：2
  SaveData.unlock_next(4)                # 最後一關，上限 5
  print(SaveData.get_unlocked())         # 期望：5（不超過 LEVELS.size()）
  ```

- [ ] **Step 5: 確認 user://save.json 已建立**

  執行遊戲後，在 Windows 檔案總管前往：
  `%APPDATA%\Godot\app_userdata\2048\`
  確認 `save.json` 存在且內容格式正確。

- [ ] **Step 6: Commit**

  ```bash
  git add scripts/SaveData.gd project.godot
  git commit -m "feat: add SaveData AutoLoad with level definitions and local leaderboard"
  ```

---

## Chunk 2: LevelSelect 場景

### Task 2: 建立 LevelSelect.gd 腳本

**Files:**
- Create: `scripts/LevelSelect.gd`

- [ ] **Step 1: 建立 `scripts/LevelSelect.gd`**

  兩步驟 UX：點選關卡按鈕 → 更新排行榜並記住選中關卡；點「開始」按鈕 → 切換場景。

  ```gdscript
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
		  child.queue_free()
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
  ```

### Task 3: 在 Godot 編輯器建立 LevelSelect.tscn

**Files:**
- Create: `scenes/LevelSelect.tscn`

- [ ] **Step 1: 建立場景根節點**

  - Scene → New Scene
  - 選擇根節點類型：`Control`，命名為 `LevelSelect`
  - 儲存為 `scenes/LevelSelect.tscn`

- [ ] **Step 2: 設定 LevelSelect 節點**

  選取 `LevelSelect`（根 Control）：
  - Inspector → Layout → Anchors Preset：`Full Rect`（填滿整個視窗）

- [ ] **Step 3: 加入 Title Label**

  在 `LevelSelect` 下加入子節點 `Label`，命名為 `Title`：
  - `text` = `選擇關卡`
  - Layout → Anchors Preset：`Top Wide`
  - 在 Inspector 設定 `horizontal_alignment` = Center

- [ ] **Step 4: 加入 LevelList VBoxContainer**

  在 `LevelSelect` 下加入子節點 `VBoxContainer`，命名為 `LevelList`：
  - 用 Inspector → Layout 手動設定位置（左半邊，例如左 10%、上 15%、右 50%、下 90%），或直接在視口拖曳

- [ ] **Step 5: 加入 LeaderboardPanel VBoxContainer**

  在 `LevelSelect` 下加入子節點 `VBoxContainer`，命名為 `LeaderboardPanel`：
  - 位置設在右半邊（例如左 52%、上 15%、右 95%、下 90%）

- [ ] **Step 6: 在 LeaderboardPanel 下加入子節點**

  - 子節點 `Label`，命名為 `LevelTitle`，text 預設留空
  - 子節點 `VBoxContainer`，命名為 `RecordList`
  - 子節點 `Button`，命名為 `StartButton`，text = `開始`

- [ ] **Step 7: Attach LevelSelect.gd 腳本**

  選取 `LevelSelect` 根節點 → 右鍵 → Attach Script → 選擇 `scripts/LevelSelect.gd`

- [ ] **Step 8: 驗證節點路徑與 @onready 一致**

  `LevelSelect.gd` 中的四個 `@onready` 路徑：
  - `$LevelList` → 對應 `LevelSelect/LevelList`
  - `$LeaderboardPanel/LevelTitle` → 對應 `LevelSelect/LeaderboardPanel/LevelTitle`
  - `$LeaderboardPanel/RecordList` → 對應 `LevelSelect/LeaderboardPanel/RecordList`
  - `$LeaderboardPanel/StartButton` → 對應 `LevelSelect/LeaderboardPanel/StartButton`

  在 Scene 面板確認這些路徑存在且名稱一致。

- [ ] **Step 9: Commit**

  ```bash
  git add scripts/LevelSelect.gd scenes/LevelSelect.tscn
  git commit -m "feat: add LevelSelect scene with leaderboard display"
  ```

---

## Chunk 3: Game.gd 修改

### Task 4: 加入關卡變數與計時器

**Files:**
- Modify: `scripts/Game.gd`

- [ ] **Step 1: 在 `Game.gd` 頂部加入新變數**

  在現有 `const BOARD_SIZE = 4` 之後加入：

  ```gdscript
  var target_tile: int = 2048
  var level_index: int = 4
  var elapsed_time: float = 0.0
  var _timer_running: bool = false
  var _win_shown: bool = false
  ```

- [ ] **Step 2: 修改 `_ready()` 從 SaveData 讀取關卡**

  將現有 `_ready()` 開頭修改為：

  ```gdscript
  func _ready() -> void:
	  level_index = SaveData.current_level_index
	  target_tile = SaveData.LEVELS[level_index]["target"]
	  _timer_running = true
	  _init_board()
	  _create_tile_nodes()
	  spawn_tile()
	  spawn_tile()
	  await get_tree().process_frame
	  _update_display()
  ```

- [ ] **Step 3: 新增 `_process(delta)`**

  在 `_ready()` 之後加入：

  ```gdscript
  func _process(delta: float) -> void:
	  if _timer_running:
		  elapsed_time += delta
  ```

- [ ] **Step 4: 修改 `_try_move()` 加入 win guard 與 win 偵測**

  將現有 `_try_move()` 替換為：

  ```gdscript
  func _try_move(direction: String) -> void:
	  if _win_shown:
		  return
	  if move(direction):
		  _update_display()
		  if _check_win():
			  _show_win()
		  elif is_game_over():
			  _show_game_over()
  ```

- [ ] **Step 5: 新增 `_check_win()`**

  ```gdscript
  func _check_win() -> bool:
	  for row in BOARD_SIZE:
		  for col in BOARD_SIZE:
			  if board[row][col] >= target_tile:
				  return true
	  return false
  ```

- [ ] **Step 6: 新增 `_show_win()`**

  ```gdscript
  func _show_win() -> void:
	  _timer_running = false
	  _win_shown = true
	  SaveData.submit_record(target_tile, score, elapsed_time)
	  SaveData.unlock_next(level_index)

	  var overlay = ColorRect.new()
	  overlay.name = "WinOverlay"
	  overlay.color = Color(0, 0, 0, 0.7)
	  overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

	  var label = Label.new()
	  label.name = "WinLabel"
	  label.text = "🎉 通關！\n分數：%d　時間：%.1f 秒" % [score, elapsed_time]
	  label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	  label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	  label.set_anchors_preset(Control.PRESET_FULL_RECT)
	  label.add_theme_color_override("font_color", Color.WHITE)
	  label.add_theme_font_size_override("font_size", 32)

	  var btn_replay = Button.new()
	  btn_replay.text = "再玩一次"
	  btn_replay.pressed.connect(_on_win_replay)

	  var btn_next = Button.new()
	  btn_next.text = "下一關"
	  btn_next.disabled = (level_index >= SaveData.LEVELS.size() - 1)
	  btn_next.pressed.connect(_on_win_next)

	  var btn_select = Button.new()
	  btn_select.text = "返回選關"
	  btn_select.pressed.connect(_on_win_select)

	  var hbox = HBoxContainer.new()
	  hbox.name = "WinButtons"
	  hbox.alignment = BoxContainer.ALIGNMENT_CENTER
	  hbox.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	  hbox.add_child(btn_replay)
	  hbox.add_child(btn_next)
	  hbox.add_child(btn_select)

	  $UI.add_child(overlay)
	  $UI.add_child(label)
	  $UI.add_child(hbox)

  func _on_win_replay() -> void:
	  get_tree().change_scene_to_file("res://scenes/Game.tscn")

  func _on_win_next() -> void:
	  SaveData.current_level_index = level_index + 1
	  get_tree().change_scene_to_file("res://scenes/Game.tscn")

  func _on_win_select() -> void:
	  get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
  ```

- [ ] **Step 7: 在 `_on_undo_pressed()` 加入 win guard**

  將現有 `_on_undo_pressed()` 替換為：

  ```gdscript
  func _on_undo_pressed() -> void:
	  if _win_shown:
		  return
	  if undo():
		  _update_display()
  ```

  這避免通關後玩家按 Undo 撤銷掉勝利磁磚，造成勝利覆蓋層殘留但棋盤已回退的狀態不一致。

- [ ] **Step 8: 修改 `restart()` 重設計時狀態**

  將現有 `restart()` 替換為：

  ```gdscript
  func restart() -> void:
	  history.clear()
	  score = 0
	  elapsed_time = 0.0
	  _timer_running = true
	  _win_shown = false
	  _init_board()
	  spawn_tile()
	  spawn_tile()
  ```

- [ ] **Step 9: 修改 `_on_restart_pressed()` 清除勝利覆蓋層**

  將現有 `_on_restart_pressed()` 替換為：

  ```gdscript
  func _on_restart_pressed() -> void:
	  for node_name in ["GameOverOverlay", "GameOverLabel", "WinOverlay", "WinLabel", "WinButtons"]:
		  var node = $UI.get_node_or_null(node_name)
		  if node:
			  node.queue_free()
	  restart()
	  _update_display()
  ```

- [ ] **Step 10: Commit**

  ```bash
  git add scripts/Game.gd
  git commit -m "feat: add level system, timer, and win detection to Game.gd"
  ```

---

## Chunk 4: Main.tscn 更新與整合驗收

### Task 5: 修改 Main.tscn 指向 LevelSelect

**Files:**
- Modify: `scenes/Main.tscn`

- [ ] **Step 1: 在 Godot 編輯器開啟 Main.tscn**

  目前 `Main.tscn` 直接 instance `Game.tscn`。需改為 instance `LevelSelect.tscn`。

- [ ] **Step 2: 移除 Game instance，加入 LevelSelect instance**

  - 在 Scene 面板選取並刪除 `Game` 節點
  - 右鍵 `Main` 根節點 → Instance Child Scene → 選 `scenes/LevelSelect.tscn`

  或直接編輯 `scenes/Main.tscn` 檔案內容：

  ```
  [gd_scene load_steps=2 format=3 uid="uid://main2048scene1"]

  [ext_resource type="PackedScene" path="res://scenes/LevelSelect.tscn" id="1_levelselect"]

  [node name="Main" type="Node"]

  [node name="LevelSelect" parent="." instance=ExtResource("1_levelselect")]
  ```

- [ ] **Step 3: 儲存並驗證**

  儲存 `Main.tscn`。執行遊戲（F5），確認啟動畫面為關卡選擇畫面，而非直接進入遊戲。

- [ ] **Step 4: Commit**

  ```bash
  git add scenes/Main.tscn
  git commit -m "feat: set LevelSelect as entry point in Main.tscn"
  ```

### Task 6: 整合驗收

- [ ] **Step 1: 驗收 — 初始解鎖狀態**

  首次執行（或刪除 `save.json` 後）：
  - 關卡選擇畫面應顯示 Lv.1 可點、Lv.2～Lv.5 顯示 🔒 且 disabled

- [ ] **Step 2: 驗收 — Lv.1 通關解鎖 Lv.2**

  進入 Lv.1（目標磁磚 128）：
  - 合出 128 磁磚 → 出現勝利覆蓋層，顯示分數與時間
  - 點「返回選關」→ Lv.2 已解鎖（不再顯示 🔒）

- [ ] **Step 3: 驗收 — 排行榜記錄**

  再次進入 Lv.1 通關 → 返回選關 → 點 Lv.1 應顯示排行榜，按分數降序列出最多 5 筆

- [ ] **Step 4: 驗收 — 再玩一次**

  勝利畫面點「再玩一次」→ 重新載入 Game.tscn，同一關卡，計時歸零

- [ ] **Step 5: 驗收 — 下一關**

  Lv.1 通關後，點「下一關」→ 進入 Lv.2（目標 256）

- [ ] **Step 6: 驗收 — 最後一關「下一關」disabled**

  Lv.5（目標 2048）通關後，「下一關」按鈕應為 disabled

- [ ] **Step 7: 驗收 — Game Over 不觸發通關**

  棋盤填滿無合法移動 → 顯示「遊戲結束」覆蓋層，不出現勝利畫面，不記錄排行

- [ ] **Step 8: 驗收 — 存檔持久性**

  通關並記錄排行後，關閉 Godot 再重開 → 排行榜與解鎖狀態應保留

- [ ] **Step 9: 驗收 — Undo 在通關後無效**

  通關後出現勝利覆蓋層，按鍵盤 Z（或 Undo 按鈕）→ 棋盤不應回退，勝利覆蓋層應保持完整

- [ ] **Step 10: 驗收 — Restart 按鈕重設計時**

  Game Over 後點「重新開始」→ 計時歸零，棋盤清空，無殘留覆蓋層

- [ ] **Step 11: 最終 Commit**

  ```bash
  git add -A
  git commit -m "feat: complete level system and leaderboard integration"
  ```
