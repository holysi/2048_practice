# 關卡系統與排行榜設計文件

**日期：** 2026-03-15
**引擎：** Godot 4
**基於：** 2048 MVP（`2026-03-14-2048-game-design.md`）

---

## 概述

在現有 2048 MVP 基礎上，加入五個難度關卡（目標磁磚：128 / 256 / 512 / 1024 / 2048），依序解鎖，並為每個關卡維護本機 Top 5 排行榜（以分數為主排序，通關時間為副排序）。

---

## 關卡定義

```gdscript
const LEVELS = [
    { "target": 128,  "name": "Lv.1 — 128" },
    { "target": 256,  "name": "Lv.2 — 256" },
    { "target": 512,  "name": "Lv.3 — 512" },
    { "target": 1024, "name": "Lv.4 — 1024" },
    { "target": 2048, "name": "Lv.5 — 2048" },
]
```

- 初始僅解鎖 Lv.1（128）
- 通關某關後，解鎖下一關
- 關卡定義為常數，不寫入存檔
- `LEVELS` 常數定義在 `SaveData.gd`，`Game.gd` 與 `LevelSelect.gd` 均透過 `SaveData.LEVELS` 存取

---

## 架構：方案 B（LevelSelect + SaveData AutoLoad）

### 新增 / 修改檔案

```
res://
├── scenes/
│   ├── Main.tscn          # 修改：啟動後切換至 LevelSelect.tscn
│   ├── LevelSelect.tscn   # 新增：關卡選擇 + 排行榜畫面
│   ├── Game.tscn          # 小幅修改（支援 target_tile、計時）
│   └── Tile.tscn          # 不變
├── scripts/
│   ├── SaveData.gd        # 新增：AutoLoad 單例，管理存檔
│   ├── LevelSelect.gd     # 新增：關卡選擇邏輯
│   ├── Game.gd            # 修改：加 target_tile、計時、通關偵測
│   ├── Tile.gd            # 不變
│   └── TileTheme.gd       # 不變
```

### 場景流程

```
Main.tscn → LevelSelect.tscn → Game.tscn（帶 target_tile）
                ↑                    │
                └────────────────────┘
             勝利/失敗後可返回選關或重玩
```

---

## 資料模型

### 存檔格式（`user://save.json`）

```json
{
  "unlocked_levels": 1,
  "records": {
    "128":  [{ "score": 3200, "time": 47.3 }, ...],
    "256":  [],
    "512":  [],
    "1024": [],
    "2048": []
  }
}
```

- `unlocked_levels`：目前已解鎖的關卡數量（1～5），初始為 1
- `records[target]`：該關 Top 5，依 score 降序排列，score 相同則 time 升序
- 每關最多保留 5 筆，通關後插入新紀錄並裁切超出部分

---

## SaveData.gd（AutoLoad 單例）

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
    # current_index 為 0-based，unlocked_levels 為已解鎖關數（1-based）
    # 通關 index 0 → unlocked_levels 應至少為 2
    var needed = current_index + 2
    var capped = min(needed, LEVELS.size())  # 不超過總關卡數
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

---

## LevelSelect.tscn 節點樹

```
LevelSelect (Control)
├── Title (Label)                    # "選擇關卡"
├── LevelList (VBoxContainer)        # 5 個關卡按鈕
│   └── [LevelButton × 5]           # 解鎖 → 可點；未解鎖 → disabled + "🔒"
└── LeaderboardPanel (VBoxContainer) # 點選關卡後顯示排行
    ├── LevelTitle (Label)           # "Lv.1 — 128  排行榜"
    └── RecordList (VBoxContainer)   # 最多 5 筆：#1  3200分  47.3秒
```

**LevelSelect.gd 邏輯：**
- `_ready()`：讀取 `SaveData`，依 `unlocked_levels` 設定各按鈕 enabled/disabled
- 點選關卡按鈕 → 更新右側排行榜
- 點選開始 → 設定 `SaveData.current_level_index` → `change_scene_to_file("res://scenes/Game.tscn")`

---

## Game.gd 修改

### 新增變數

```gdscript
var target_tile: int = 2048
var level_index: int = 4
var elapsed_time: float = 0.0
var _timer_running: bool = false
var _win_shown: bool = false   # 通關後封鎖輸入用
```

### 修改 `_ready()`

```gdscript
func _ready() -> void:
    level_index = SaveData.current_level_index
    target_tile = SaveData.LEVELS[level_index]["target"]
    _timer_running = true
    # ... 原有初始化邏輯
```

### 新增 `_process(delta)`

```gdscript
func _process(delta: float) -> void:
    if _timer_running:
        elapsed_time += delta
```

### 修改 `_try_move()`

```gdscript
func _try_move(direction: String) -> void:
    if _win_shown:   # 通關後封鎖所有移動輸入
        return
    if move(direction):
        _update_display()
        if _check_win():
            _show_win()
        elif is_game_over():
            _show_game_over()

func _check_win() -> bool:
    for row in BOARD_SIZE:
        for col in BOARD_SIZE:
            if board[row][col] >= target_tile:
                return true
    return false
```

### 新增 `_show_win()`

```gdscript
func _show_win() -> void:
    _timer_running = false
    _win_shown = true
    SaveData.submit_record(target_tile, score, elapsed_time)
    SaveData.unlock_next(level_index)

    # 覆蓋層
    var overlay = ColorRect.new()
    overlay.name = "WinOverlay"
    overlay.color = Color(0, 0, 0, 0.7)
    overlay.set_anchors_preset(Control.PRESET_FULL_RECT)

    var label = Label.new()
    label.text = "🎉 通關！\n分數：%d　時間：%.1f 秒" % [score, elapsed_time]
    label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    label.set_anchors_preset(Control.PRESET_FULL_RECT)
    label.add_theme_color_override("font_color", Color.WHITE)
    label.add_theme_font_size_override("font_size", 32)
    label.name = "WinLabel"

    # 三個按鈕（動態建立，錨定至畫面下方中央）
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
```

### 勝利按鈕回呼

勝利後的三個按鈕全部透過 `change_scene_to_file` 切換場景，不在原場景內重設狀態，避免與現有 restart 邏輯衝突：

```gdscript
func _on_win_replay() -> void:
    get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_win_next() -> void:
    SaveData.current_level_index = level_index + 1
    get_tree().change_scene_to_file("res://scenes/Game.tscn")

func _on_win_select() -> void:
    get_tree().change_scene_to_file("res://scenes/LevelSelect.tscn")
```

### 修改 `restart()`（重新開始時同步重設計時）

現有 `_on_restart_pressed()` 用於 Game Over 後重玩。需同步重設計時狀態：

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

`_on_restart_pressed()` 同時也需清除勝利覆蓋層節點（`WinOverlay`、`WinLabel`、`WinButtons`），與清除 GameOver 覆蓋層的方式一致。

---

## 通關條件注意事項

- 通關判斷：棋盤上**任一磁磚 ≥ target_tile** 即視為通關
- 通關後停止接受輸入（不再觸發 `_try_move`）
- Game Over 仍維持原邏輯（無合法移動），Game Over 不記錄排行

---

## 驗收清單

- [ ] 初始只有 Lv.1 可點，其他顯示 🔒
- [ ] 通關 Lv.1 後，Lv.2 解鎖
- [ ] 排行榜依分數降序排列，分數相同則時間升序
- [ ] 每關最多保留 5 筆
- [ ] 勝利畫面顯示分數與時間，三個按鈕正常運作
- [ ] 最後一關（2048）通關後「下一關」按鈕 disabled
- [ ] 存檔在重啟遊戲後仍保留
- [ ] Game Over 不觸發通關流程
