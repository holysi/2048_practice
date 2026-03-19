extends Control

enum InputMode { NORMAL, BOMB_AOE_PENDING }
var input_mode: InputMode = InputMode.NORMAL

@onready var right_panel: Control = $RightPanel

func _ready() -> void:
	pass

func begin_bomb_aoe_mode() -> void:
	input_mode = InputMode.BOMB_AOE_PENDING
	# TD scene will add aoe cursor when connected

func cancel_bomb_aoe_mode() -> void:
	input_mode = InputMode.NORMAL

func _input(event: InputEvent) -> void:
	if input_mode != InputMode.BOMB_AOE_PENDING:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var click_pos := event.position
		if right_panel.get_global_rect().has_point(click_pos):
			get_viewport().set_input_as_handled()
			cancel_bomb_aoe_mode()
			# TD scene connection will handle the actual AOE — Phase 6
