extends CanvasLayer
## 任务日志:主线/支线/已完成分类,步骤进度详情。

var _panel: PanelContainer
var _list: VBoxContainer
var _detail: RichTextLabel

func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	EventBus.quest_started.connect(func(_q): _rebuild())
	EventBus.quest_advanced.connect(func(_q, _s): _rebuild())
	EventBus.quest_completed.connect(func(_q): _rebuild())

func _build() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.08, 0.11, 0.97)
	style.border_color = Color(0.85, 0.55, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 26
	style.content_margin_right = 26
	style.content_margin_top = 20
	style.content_margin_bottom = 20
	_panel.add_theme_stylebox_override("panel", style)
	add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "任务日志"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	vb.add_child(columns)
	_list = VBoxContainer.new()
	_list.custom_minimum_size = Vector2(340, 400)
	columns.add_child(_list)
	_detail = RichTextLabel.new()
	_detail.custom_minimum_size = Vector2(430, 400)
	_detail.bbcode_enabled = true
	_detail.add_theme_font_size_override("normal_font_size", 19)
	columns.add_child(_detail)
	var close := Button.new()
	close.text = "关闭 (J)"
	close.add_theme_font_size_override("font_size", 19)
	close.custom_minimum_size = Vector2(200, 50)
	close.pressed.connect(func(): visible = false)
	vb.add_child(close)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quest_log"):
		visible = not visible
		if visible:
			_rebuild()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for c in _list.get_children():
		c.queue_free()
	var active_ids: Array = QuestManager.active.keys()
	if active_ids.is_empty() and QuestManager.completed.is_empty():
		var empty := Label.new()
		empty.text = "暂无任务"
		empty.add_theme_font_size_override("font_size", 19)
		_list.add_child(empty)
		return
	var title_a := Label.new()
	title_a.text = "—— 进行中 ——"
	title_a.add_theme_font_size_override("font_size", 20)
	title_a.add_theme_color_override("font_color", Color(0.9, 0.8, 0.5))
	_list.add_child(title_a)
	for qid: String in active_ids:
		_add_quest_entry(qid, true)
	var title_c := Label.new()
	title_c.text = "—— 已完成 ——"
	title_c.add_theme_font_size_override("font_size", 20)
	title_c.add_theme_color_override("font_color", Color(0.5, 0.7, 0.5))
	_list.add_child(title_c)
	for qid: String in QuestManager.completed:
		_add_quest_entry(qid, false)

func _add_quest_entry(qid: String, is_active: bool) -> void:
	var quest := GameData.get_quest(qid)
	var btn := Button.new()
	var prefix := ""
	if quest.get("main", false):
		prefix = "★ "
	elif quest.get("hidden", false):
		prefix = "◆ "
	btn.text = prefix + quest.get("title", qid)
	btn.add_theme_font_size_override("font_size", 18)
	btn.custom_minimum_size = Vector2(320, 46)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(func(): _show_detail(qid, is_active))
	_list.add_child(btn)

func _show_detail(qid: String, is_active: bool) -> void:
	var quest := GameData.get_quest(qid)
	var text := "[color=#f0c060]%s[/color]\n\n" % quest.get("title", qid)
	text += quest.get("desc", "") + "\n\n"
	if is_active:
		var steps: Array = quest.get("steps", [])
		var state: Dictionary = QuestManager.active.get(qid, {})
		var current := int(state.get("step", 0))
		for i: int in steps.size():
			var step: Dictionary = steps[i]
			if i < current:
				text += "[color=#7a9a7a]✔ %s[/color]\n" % step.get("desc", "")
			elif i == current:
				var progress := ""
				if step.get("type", "") == "kill":
					progress = "(%d/%d)" % [int(state.get("progress", 0)), int(step.get("count", 1))]
				elif step.get("type", "") == "collect":
					progress = "(%d/%d)" % [int(GameState.inventory.get(step.get("target", ""), 0)), int(step.get("count", 1))]
				text += "[color=#e8d8a0]▸ %s %s[/color]\n" % [step.get("desc", ""), progress]
			else:
				text += "[color=#8a8a8a]· %s[/color]\n" % step.get("desc", "")
	else:
		text += "[color=#7a9a7a]已完成[/color]\n"
	var rewards: Dictionary = quest.get("rewards", {})
	if not rewards.is_empty():
		text += "\n[color=#a0a8b0]奖励:%d 经验" % int(rewards.get("xp", 0))
		if int(rewards.get("gold", 0)) > 0:
			text += ",%d 雪币" % int(rewards.get("gold", 0))
		for item_id: String in rewards.get("items", []):
			text += "," + GameData.get_item(item_id).get("name", item_id)
		text += "[/color]"
	_detail.text = text
