extends CanvasLayer
## 技能树:战斗 / 生存 / 守烬 三系,消耗技能点解锁,即时生效。

var _root: Control
var _panel: PanelContainer
var _points_label: Label
var _selected_skill := ""

func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

func _build() -> void:
	if _root != null:
		_root.queue_free()
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)
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
	_root.add_child(_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "技能树"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(title)
	_points_label = Label.new()
	_points_label.add_theme_font_size_override("font_size", 21)
	_points_label.add_theme_color_override("font_color", Color(0.9, 0.85, 0.6))
	vb.add_child(_points_label)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 24)
	vb.add_child(columns)
	for branch_id: String in ["combat", "survival", "ember"]:
		var branch: Dictionary = GameState.SKILL_TREE[branch_id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		columns.add_child(col)
		var bt := Label.new()
		bt.text = "【%s】" % branch["name"]
		bt.add_theme_font_size_override("font_size", 22)
		bt.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
		col.add_child(bt)
		for skill_id: String in branch["skills"]:
			var def: Dictionary = branch["skills"][skill_id]
			col.add_child(_make_skill_button(skill_id, def))
	var close := Button.new()
	close.text = "关闭 (K)"
	close.add_theme_font_size_override("font_size", 19)
	close.custom_minimum_size = Vector2(200, 50)
	close.pressed.connect(func(): visible = false)
	vb.add_child(close)

func _make_skill_button(skill_id: String, def: Dictionary) -> Button:
	var btn := Button.new()
	var learned := GameState.has_skill(skill_id)
	var cost := int(def.get("cost", 1))
	var req: String = def.get("requires", "")
	var req_ok := req.is_empty() or GameState.has_skill(req)
	btn.text = "%s\n%s" % [def.get("name", ""), def.get("desc", "")]
	btn.add_theme_font_size_override("font_size", 15)
	btn.custom_minimum_size = Vector2(300, 84)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if learned:
		btn.modulate = Color(0.5, 0.9, 0.5)
		btn.text += "\n[已习得]"
	elif not req_ok:
		btn.modulate = Color(0.45, 0.45, 0.45)
		btn.text += "\n[需前置]"
	elif GameState.skill_points < cost:
		btn.modulate = Color(0.7, 0.7, 0.75)
		btn.text += "\n[点数不足 %d]" % cost
	else:
		btn.text += "\n[消耗 %d 点]" % cost
	btn.pressed.connect(func(): _try_learn(skill_id))
	return btn

func _try_learn(skill_id: String) -> void:
	if GameState.learn_skill(skill_id):
		AudioManager.play_sfx("levelup")
		EventBus.notify.emit("技能习得", GameState._find_skill(skill_id).get("name", skill_id))
		_rebuild()
	else:
		AudioManager.play_sfx("ui_click")

func _rebuild() -> void:
	_points_label.text = "可用技能点:%d(等级 %d)" % [GameState.skill_points, GameState.level]
	_build()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_tree"):
		visible = not visible
		if visible:
			_rebuild()
		get_viewport().set_input_as_handled()
