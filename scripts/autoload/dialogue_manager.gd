extends Node
## 对话系统:JSON 驱动的对话树,支持条件、选项、动作(开任务/给物品/设旗标)。

var _ui: CanvasLayer = null
var _name_label: Label
var _text_label: RichTextLabel
var _choices_box: VBoxContainer
var _hint_label: Label
var _current_node: Dictionary = {}
var _current_id := ""
var _pending_actions: Array = []
var _active := false

func _ready() -> void:
	_build_ui()
	process_mode = Node.PROCESS_MODE_ALWAYS

func is_active() -> bool:
	return _active

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.layer = 40
	_ui.visible = false
	add_child(_ui)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	_ui.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	panel.anchor_top = 0.62
	panel.anchor_bottom = 1.0
	panel.offset_top = 12
	panel.offset_bottom = -12
	panel.offset_left = 24
	panel.offset_right = -24
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.1, 0.94)
	style.border_color = Color(0.85, 0.55, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	_name_label = Label.new()
	_name_label.name = "NameLabel"
	_name_label.add_theme_font_size_override("font_size", 24)
	_name_label.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(_name_label)
	_text_label = RichTextLabel.new()
	_text_label.name = "TextLabel"
	_text_label.bbcode_enabled = false
	_text_label.fit_content = true
	_text_label.add_theme_font_size_override("font_size", 21)
	_text_label.custom_minimum_size = Vector2(0, 90)
	vb.add_child(_text_label)
	_choices_box = VBoxContainer.new()
	_choices_box.name = "ChoicesBox"
	_choices_box.add_theme_constant_override("separation", 6)
	vb.add_child(_choices_box)
	_hint_label = Label.new()
	_hint_label.name = "HintLabel"
	_hint_label.text = "点击任意处继续 ▸"
	_hint_label.add_theme_font_size_override("font_size", 15)
	_hint_label.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	_hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	vb.add_child(_hint_label)

func start(dialogue_id: String) -> void:
	if _active:
		return
	_active = true
	_ui.visible = true
	_show_node(dialogue_id)

func stop() -> void:
	_active = false
	_ui.visible = false

func _show_node(node_id: String) -> void:
	_current_id = node_id
	_current_node = GameData.get_dialogue_node(node_id)
	if _current_node.is_empty():
		push_error("DialogueManager: 缺少对话节点 " + node_id)
		stop()
		return
	_name_label.text = _current_node.get("speaker", "")
	_text_label.text = _current_node.get("text", "")
	var npc_id: String = _current_node.get("npc", "")
	if not npc_id.is_empty():
		EventBus.npc_talked.emit(npc_id, node_id)
	for c in _choices_box.get_children():
		c.queue_free()
	var choices: Array = _current_node.get("choices", [])
	_hint_label.visible = choices.is_empty()
	for i: int in choices.size():
		var choice: Dictionary = choices[i]
		if not _conditions_ok(choice.get("if", {})):
			continue
		var btn := Button.new()
		btn.text = choice.get("text", "……")
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(0, 52)
		btn.pressed.connect(func(): _choose(choice))
		_choices_box.add_child(btn)

func _conditions_ok(cond: Dictionary) -> bool:
	for key: String in cond:
		var value: Variant = cond[key]
		match key:
			"flag":
				if GameState.get_flag(value, false) != true:
					return false
			"not_flag":
				if GameState.get_flag(value, false) == true:
					return false
			"quest_active":
				if not QuestManager.is_active(value):
					return false
			"quest_completed":
				if not QuestManager.is_completed(value):
					return false
			"quest_not_completed":
				if QuestManager.is_completed(value):
					return false
			"has_item":
				if not GameState.has_item(value):
					return false
			"affinity_gte":
				var parts: PackedStringArray = String(value).split("|")
				if int(GameState.affinity.get(parts[0], 0)) < int(parts[1]):
					return false
	return true

func _choose(choice: Dictionary) -> void:
	AudioManager.play_sfx("ui_click")
	_run_actions(choice.get("do", []))
	var next: String = choice.get("next", "")
	if next.is_empty() or next == "end":
		stop()
		return
	_show_node(next)

func _run_actions(actions: Array) -> void:
	for action: Dictionary in actions:
		var type: String = action.get("type", "")
		match type:
			"set_flag":
				GameState.set_flag(action.get("key", ""), action.get("value", true))
			"add_flag":  # 数值旗标
				var k: String = action.get("key", "")
				GameState.set_flag(k, int(GameState.get_flag(k, 0)) + int(action.get("value", 1)))
			"start_quest":
				QuestManager.start_quest(action.get("quest", ""))
			"complete_quest_step_flag":
				GameState.set_flag(action.get("key", ""), true)
			"give_item":
				GameState.add_item(action.get("item", ""), int(action.get("count", 1)))
			"remove_item":
				GameState.remove_item(action.get("item", ""), int(action.get("count", 1)))
			"add_gold":
				GameState.gold += int(action.get("amount", 0))
			"add_affinity":
				GameState.add_affinity(action.get("npc", ""), int(action.get("amount", 1)))
			"add_xp":
				GameState.add_xp(int(action.get("amount", 0)))
			"heal":
				GameState.heal(float(action.get("amount", 0)))
			"notify":
				EventBus.notify.emit(action.get("title", ""), action.get("body", ""))
			"shop":
				var main := get_tree().get_first_node_in_group("main_controller")
				if main != null:
					main.call("open_shop", action.get("shop", "default"))
			"cutscene":
				var main := get_tree().get_first_node_in_group("main_controller")
				if main != null:
					main.call("play_cutscene", action.get("id", ""))
			"ending":
				EventBus.ending_reached.emit(action.get("id", ""))

func _unhandled_input(event: InputEvent) -> void:
	if not _active:
		return
	if event is InputEventMouseButton and event.pressed and not _has_visible_choices():
		_advance()
	elif event is InputEventScreenTouch and event.pressed and not _has_visible_choices():
		_advance()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_SPACE and not _has_visible_choices():
		_advance()

func _has_visible_choices() -> bool:
	for c in _choices_box.get_children():
		if is_instance_valid(c) and c.visible:
			return true
	return false

func _advance() -> void:
	var next: String = _current_node.get("next", "")
	var actions: Array = _current_node.get("do", [])
	_run_actions(actions)
	if next.is_empty() or next == "end":
		stop()
		return
	_show_node(next)
