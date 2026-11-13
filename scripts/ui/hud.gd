extends CanvasLayer
## HUD:血量/体力/经验条、时间天气、任务追踪、交互提示、通知、伤害反馈。

var _hp_bar: ProgressBar
var _stamina_bar: ProgressBar
var _xp_bar: ProgressBar
var _level_label: Label
var _clock_label: Label
var _gold_label: Label
var _quest_label: Label
var _prompt_label: Label
var _toast_box: VBoxContainer
var _vignette: ColorRect
var _main := Node.new()

func _ready() -> void:
	layer = 10
	_build()
	EventBus.player_damaged.connect(_on_damaged)
	EventBus.level_up.connect(func(_l): _refresh())
	EventBus.quest_advanced.connect(func(_q, _s): _refresh())
	EventBus.quest_started.connect(func(_q): _refresh())
	EventBus.quest_completed.connect(func(_q): _refresh())
	EventBus.notify.connect(func(title, body): toast(title, body))
	GameState.inventory_changed.connect(func(): _refresh())

func _build() -> void:
	# 左上:状态条
	var status := VBoxContainer.new()
	status.position = Vector2(24, 20)
	status.add_theme_constant_override("separation", 6)
	add_child(status)
	_level_label = Label.new()
	_level_label.text = "等级 1 · 洛尘"
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(1, 0.9, 0.7))
	status.add_child(_level_label)
	_hp_bar = _make_bar(Color(0.75, 0.2, 0.15), Vector2(300, 20))
	status.add_child(_hp_bar)
	_stamina_bar = _make_bar(Color(0.2, 0.6, 0.75), Vector2(240, 14))
	status.add_child(_stamina_bar)
	_xp_bar = _make_bar(Color(0.8, 0.65, 0.2), Vector2(240, 8))
	status.add_child(_xp_bar)
	# 右上:时间 / 天气 / 金币
	var info := HBoxContainer.new()
	info.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	info.position = Vector2(-420, 20)
	info.add_theme_constant_override("separation", 18)
	add_child(info)
	_clock_label = Label.new()
	_clock_label.add_theme_font_size_override("font_size", 20)
	info.add_child(_clock_label)
	var weather_icon := Label.new()
	weather_icon.name = "WeatherLabel"
	weather_icon.add_theme_font_size_override("font_size", 20)
	info.add_child(weather_icon)
	_gold_label = Label.new()
	_gold_label.add_theme_font_size_override("font_size", 20)
	_gold_label.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	info.add_child(_gold_label)
	# 任务追踪(左侧中部)
	_quest_label = Label.new()
	_quest_label.position = Vector2(24, 130)
	_quest_label.add_theme_font_size_override("font_size", 17)
	_quest_label.add_theme_color_override("font_color", Color(0.92, 0.88, 0.75))
	_quest_label.custom_minimum_size = Vector2(360, 0)
	_quest_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(_quest_label)
	# 交互提示(底部中央)
	_prompt_label = Label.new()
	_prompt_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_prompt_label.position = Vector2(-100, -170)
	_prompt_label.add_theme_font_size_override("font_size", 20)
	_prompt_label.add_theme_color_override("font_color", Color(1, 0.95, 0.8))
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.visible = false
	add_child(_prompt_label)
	# 通知栈(右侧)
	_toast_box = VBoxContainer.new()
	_toast_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_toast_box.position = Vector2(-360, 90)
	_toast_box.add_theme_constant_override("separation", 8)
	add_child(_toast_box)
	# 伤害红晕
	_vignette = ColorRect.new()
	_vignette.color = Color(0.7, 0, 0, 0)
	_vignette.set_anchors_preset(Control.PRESET_FULL_RECT)
	_vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_vignette)
	# 右上快捷按钮(触屏时也可用)
	var btn_box := HBoxContainer.new()
	btn_box.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	btn_box.position = Vector2(-380, 56)
	btn_box.add_theme_constant_override("separation", 8)
	add_child(btn_box)
	_add_quick_button(btn_box, "任务", KEY_J)
	_add_quick_button(btn_box, "背包", KEY_I)
	_add_quick_button(btn_box, "技能", KEY_K)

func _add_quick_button(parent: Control, text: String, key: Key) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 16)
	btn.custom_minimum_size = Vector2(64, 40)
	btn.pressed.connect(func():
		var ev := InputEventKey.new()
		ev.physical_keycode = key
		ev.pressed = true
		Input.parse_input_event(ev))
	parent.add_child(btn)

func _make_bar(color: Color, size: Vector2) -> ProgressBar:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = size
	bar.show_percentage = false
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0, 0, 0, 0.55)
	bg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("background", bg)
	var fg := StyleBoxFlat.new()
	fg.bg_color = color
	fg.set_corner_radius_all(4)
	bar.add_theme_stylebox_override("fill", fg)
	return bar

func set_interact_prompt(text: String) -> void:
	_prompt_label.text = text
	_prompt_label.visible = not text.is_empty()

func toast(title: String, body: String) -> void:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	style.border_color = Color(0.85, 0.55, 0.25, 0.8)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	var t := Label.new()
	t.text = title
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", Color(1, 0.85, 0.55))
	vb.add_child(t)
	var b := Label.new()
	b.text = body
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	b.custom_minimum_size = Vector2(320, 0)
	vb.add_child(b)
	_toast_box.add_child(panel)
	var tween := panel.create_tween()
	tween.tween_interval(3.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.6)
	tween.tween_callback(panel.queue_free)

func _on_damaged(amount: float) -> void:
	_refresh()
	if amount <= 0.0:
		return
	_vignette.color = Color(0.7, 0.05, 0.05, 0.35)
	var tween := _vignette.create_tween()
	tween.tween_property(_vignette, "color:a", 0.0, 0.5)

func _process(_delta: float) -> void:
	_hp_bar.max_value = GameState.max_hp
	_hp_bar.value = GameState.hp
	_stamina_bar.max_value = GameState.max_stamina
	_stamina_bar.value = GameState.stamina
	_xp_bar.max_value = GameState.xp_to_next()
	_xp_bar.value = GameState.xp
	_gold_label.text = "雪币 %d" % GameState.gold
	var world := _world()
	if world != null and world.day_night != null:
		var hour := int(world.day_night.time_hours)
		var minute := int((world.day_night.time_hours - hour) * 60)
		_clock_label.text = "%02d:%02d" % [hour, minute]
		var wl: Label = get_node_or_null("WeatherLabel")
		if wl == null:
			for c in get_children():
				if c.name == "WeatherLabel":
					wl = c
		if wl != null:
			var names := {"clear": "晴", "snow": "雪", "fog": "雾", "blizzard": "暴雪"}
			wl.text = names.get(world.weather.current_id, "")
	# 任务追踪
	_refresh_quest_tracker()

func _refresh() -> void:
	_level_label.text = "等级 %d · %s" % [GameState.level, GameState.player_name]

func _refresh_quest_tracker() -> void:
	var text := ""
	if not QuestManager.active.is_empty():
		var quest_id: String = QuestManager.active.keys()[0]
		var quest := GameData.get_quest(quest_id)
		var step := QuestManager.current_step(quest_id)
		var progress := ""
		if step.get("type", "") == "kill":
			var st: Dictionary = QuestManager.active[quest_id]
			progress = " (%d/%d)" % [int(st.get("progress", 0)), int(step.get("count", 1))]
		elif step.get("type", "") == "collect":
			progress = " (%d/%d)" % [int(GameState.inventory.get(step.get("target", ""), 0)), int(step.get("count", 1))]
		text = "【%s】\n%s%s" % [quest.get("title", ""), step.get("desc", ""), progress]
	_quest_label.text = text

func _world() -> Node:
	for n in get_tree().get_nodes_in_group("world"):
		return n
	return null
