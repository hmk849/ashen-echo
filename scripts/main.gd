extends Node
## 主入口:主菜单 → 构建世界 → 游戏循环;负责全局暂停与界面切换。

var _menu: CanvasLayer = null
var _hud: CanvasLayer = null
var _world: Node3D = null
var _in_game := false
var _settings := ConfigFile.new()
const SETTINGS_PATH := "user://settings.cfg"

func _ready() -> void:
	add_to_group("main_controller")
	# 中文字体:设为全局默认字体与回退字体
	var font: FontFile = load("res://assets/fonts/NotoSansSC_subset.ttf")
	if font != null:
		ThemeDB.get_default_theme().default_font = font
		ThemeDB.get_default_theme().default_font_size = 20
		ThemeDB.fallback_font = font
		ThemeDB.fallback_font_size = 20
	get_viewport().set_scaling_3d_mode(Viewport.SCALING_3D_MODE_BILINEAR)
	if OS.get_environment("ASHEN_TEST") != "":
		var tester := preload("res://test/integration_test.gd").new()
		add_child(tester)
		tester.run()
		return
	_load_settings()
	_apply_settings()
	_build_main_menu()
	AudioManager.play_music("menu")
	AudioManager.play_ambient("wind")

func _process(delta: float) -> void:
	if _in_game:
		GameState.play_seconds += int(delta)
		TouchInput.end_frame()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") and _in_game:
		get_tree().paused = not get_tree().paused
		if get_tree().paused:
			_show_pause_menu()

# ================================================================ 主菜单
func _build_main_menu() -> void:
	_menu = CanvasLayer.new()
	_menu.layer = 30
	add_child(_menu)
	var bg := TextureRect.new()
	bg.name = "Background"
	var art: Texture2D = load("res://assets/ui/title_bg.png")
	bg.texture = art
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.25)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_menu.add_child(dim)
	var title := Label.new()
	title.text = "烬 峰 回 响"
	title.add_theme_font_size_override("font_size", 84)
	title.add_theme_color_override("font_color", Color(1.0, 0.82, 0.55))
	title.add_theme_color_override("font_outline_color", Color(0.1, 0.08, 0.05))
	title.add_theme_constant_override("outline_size", 10)
	title.position = Vector2(60, 60)
	_menu.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "霜烬大陆 · 守烬人的最后一冬"
	subtitle.add_theme_font_size_override("font_size", 24)
	subtitle.add_theme_color_override("font_color", Color(0.85, 0.87, 0.9))
	subtitle.position = Vector2(66, 160)
	_menu.add_child(subtitle)
	var version := Label.new()
	version.text = "v1.0 · 单机版"
	version.add_theme_font_size_override("font_size", 15)
	version.add_theme_color_override("font_color", Color(0.6, 0.62, 0.65))
	version.position = Vector2(66, 196)
	_menu.add_child(version)

	var vb := VBoxContainer.new()
	vb.name = "MenuButtons"
	vb.set_anchors_preset(Control.PRESET_CENTER_RIGHT)
	vb.position = Vector2(-320, -160)
	vb.add_theme_constant_override("separation", 14)
	_menu.add_child(vb)
	var has_save := not SaveManager.slot_info("auto").is_empty() or not SaveManager.slot_info("1").is_empty()
	_add_menu_button(vb, "继续旅程", func(): _continue_game(), has_save)
	_add_menu_button(vb, "新的旅程", func(): _new_game())
	_add_menu_button(vb, "读取存档", func(): _open_load_menu())
	_add_menu_button(vb, "设置", func(): _open_settings())
	var quit := _add_menu_button(vb, "离开", func(): get_tree().quit())
	quit.visible = OS.get_name() != "iOS"

func _add_menu_button(parent: Control, text: String, handler: Callable, enabled := true) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(280, 64)
	btn.add_theme_font_size_override("font_size", 26)
	btn.disabled = not enabled
	btn.pressed.connect(handler)
	parent.add_child(btn)
	return btn

func _clear_menu() -> void:
	if is_instance_valid(_menu):
		_menu.queue_free()
		_menu = null

# ================================================================ 游戏流程
func _new_game() -> void:
	AudioManager.play_sfx("ui_click")
	GameState.reset_for_new_game()
	QuestManager.from_dict({"active": {}, "completed": []})
	_start_world(null)

func _continue_game() -> void:
	AudioManager.play_sfx("ui_click")
	for slot: String in ["auto", "1", "2", "3"]:
		if not SaveManager.slot_info(slot).is_empty():
			_start_world(slot)
			return
	_new_game()

func _start_world(load_slot: Variant) -> void:
	_clear_menu()
	AudioManager.stop_music(1.5)
	_world = preload("res://scripts/world/world.gd").new()
	_world.name = "World"
	add_child(_world)
	SaveManager.register_world(_world)
	if load_slot != null and not String(load_slot).is_empty():
		SaveManager.load_from_slot(String(load_slot))
	else:
		QuestManager.start_quest("m1_intro")
		play_cutscene("intro")
	_in_game = true

func _open_load_menu() -> void:
	AudioManager.play_sfx("ui_open")
	var menu := _make_popup_panel("读取存档")
	var vb: VBoxContainer = menu.get_meta("content")
	for slot: String in ["auto", "1", "2", "3"]:
		var info := SaveManager.slot_info(slot)
		var btn := Button.new()
		if info.is_empty():
			btn.text = "槽位 %s —— 空" % ("自动" if slot == "auto" else slot)
			btn.disabled = true
		else:
			btn.text = "槽位 %s · %s · %d级 · %s" % [
				"自动" if slot == "auto" else slot,
				info.get("timestamp", ""),
				int(info.get("level", 1)),
				SaveManager.format_play_time(int(info.get("play_seconds", 0)))]
			btn.pressed.connect(func():
				_close_popup()
				if _in_game:
					SaveManager.load_from_slot(slot)
					EventBus.notify.emit("读档完成", "已回到 %s。" % info.get("chapter", ""))
				else:
					_start_world(slot))
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(560, 56)
		vb.add_child(btn)
	var back := Button.new()
	back.text = "返回"
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size = Vector2(560, 56)
	back.pressed.connect(func(): _close_popup())
	vb.add_child(back)

func _open_settings() -> void:
	AudioManager.play_sfx("ui_open")
	var menu := _make_popup_panel("设置")
	var vb: VBoxContainer = menu.get_meta("content")
	# 画质档位
	var quality_row := HBoxContainer.new()
	vb.add_child(_label("画质档位"))
	vb.add_child(quality_row)
	for q: String in ["低", "中", "高"]:
		var qb := Button.new()
		qb.text = q
		qb.toggle_mode = true
		qb.button_pressed = _settings.get_value("graphics", "quality", "中") == q
		qb.pressed.connect(func():
			_settings.set_value("graphics", "quality", q)
			_save_and_apply_settings()
			_open_settings_refresh())
		quality_row.add_child(qb)
	# 灵敏度
	var sens := _add_slider(vb, "视角灵敏度", 0.2, 3.0, _settings.get_value("camera", "sensitivity", 1.0),
		func(v): _settings.set_value("camera", "sensitivity", v))
	sens.step = 0.1
	# 视野
	_add_slider(vb, "视野 (FOV)", 60, 100, _settings.get_value("camera", "fov", 70.0),
		func(v): _settings.set_value("camera", "fov", v))
	# 反转Y轴
	var invert := CheckButton.new()
	invert.text = "反转视角 Y 轴"
	invert.button_pressed = _settings.get_value("camera", "invert_y", false)
	invert.toggled.connect(func(v): _settings.set_value("camera", "invert_y", v))
	vb.add_child(invert)
	# 触屏按钮大小
	_add_slider(vb, "虚拟按键大小", 0.6, 1.6, _settings.get_value("touch", "scale", 1.0),
		func(v): _settings.set_value("touch", "scale", v))
	# 音量
	_add_slider(vb, "主音量", 0.0, 1.0, _settings.get_value("audio", "master", 0.9),
		func(v):
			_settings.set_value("audio", "master", v)
			AudioManager.set_bus_volume("Master", v))
	_add_slider(vb, "音乐音量", 0.0, 1.0, _settings.get_value("audio", "music", 0.8),
		func(v):
			_settings.set_value("audio", "music", v)
			AudioManager.set_bus_volume("Music", v))
	_add_slider(vb, "音效音量", 0.0, 1.0, _settings.get_value("audio", "sfx", 1.0),
		func(v):
			_settings.set_value("audio", "sfx", v)
			AudioManager.set_bus_volume("SFX", v))
	var close := Button.new()
	close.text = "保存并返回"
	close.add_theme_font_size_override("font_size", 20)
	close.custom_minimum_size = Vector2(560, 56)
	close.pressed.connect(func():
		_save_and_apply_settings()
		_close_popup())
	vb.add_child(close)

func _open_settings_refresh() -> void:
	_save_and_apply_settings()
	_close_popup()
	_open_settings()

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 19)
	l.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	return l

func _add_slider(parent: Control, label_text: String, min_v: float, max_v: float, value: float, setter: Callable) -> HSlider:
	parent.add_child(_label(label_text))
	var row := HBoxContainer.new()
	parent.add_child(row)
	var val_label := Label.new()
	val_label.text = "%.1f" % value
	val_label.custom_minimum_size = Vector2(60, 0)
	var slider := HSlider.new()
	slider.min_value = min_v
	slider.max_value = max_v
	slider.value = value
	slider.custom_minimum_size = Vector2(440, 40)
	slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	slider.value_changed.connect(func(v):
		val_label.text = "%.1f" % v
		setter.call(v))
	row.add_child(slider)
	row.add_child(val_label)
	return slider

# ================================================================ 暂停菜单
func _show_pause_menu() -> void:
	var menu := _make_popup_panel("暂停")
	var vb: VBoxContainer = menu.get_meta("content")
	_add_pause_button(vb, "继续游戏", func(): _close_popup(); get_tree().paused = false)
	_add_pause_button(vb, "保存进度", func(): _open_save_menu())
	_add_pause_button(vb, "读取存档", func(): _open_load_menu())
	_add_pause_button(vb, "设置", func(): _open_settings())
	_add_pause_button(vb, "回到主菜单", func(): _back_to_menu())

func _open_save_menu() -> void:
	_close_popup()
	get_tree().paused = true
	var menu := _make_popup_panel("保存进度")
	var vb: VBoxContainer = menu.get_meta("content")
	for slot: String in ["1", "2", "3"]:
		var info := SaveManager.slot_info(slot)
		var btn := Button.new()
		btn.text = ("槽位 %s —— 空" % slot) if info.is_empty() else ("槽位 %s · %s(覆盖)" % [slot, info.get("timestamp", "")])
		btn.add_theme_font_size_override("font_size", 20)
		btn.custom_minimum_size = Vector2(560, 56)
		btn.pressed.connect(func():
			SaveManager.save_to_slot(slot)
			_close_popup()
			get_tree().paused = false)
		vb.add_child(btn)
	var back := Button.new()
	back.text = "返回"
	back.add_theme_font_size_override("font_size", 20)
	back.custom_minimum_size = Vector2(560, 56)
	back.pressed.connect(func(): _close_popup(); get_tree().paused = false)
	vb.add_child(back)

func _add_pause_button(parent: Control, text: String, handler: Callable) -> void:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", 22)
	btn.custom_minimum_size = Vector2(560, 60)
	btn.pressed.connect(handler)
	parent.add_child(btn)

func _back_to_menu() -> void:
	get_tree().paused = false
	SaveManager.autosave()
	_close_popup()
	_in_game = false
	if is_instance_valid(_world):
		_world.queue_free()
		_world = null
	SaveManager.register_world(null)
	_build_main_menu()
	AudioManager.play_music("menu")
	AudioManager.stop_ambient()

# ================================================================ 通用弹窗
func _make_popup_panel(title_text: String) -> PanelContainer:
	var overlay := CanvasLayer.new()
	overlay.layer = 60
	overlay.name = "PopupLayer"
	add_child(overlay)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(dim)
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.09, 0.12, 0.97)
	style.border_color = Color(0.85, 0.55, 0.25, 0.9)
	style.set_border_width_all(2)
	style.set_corner_radius_all(12)
	style.content_margin_left = 28
	style.content_margin_right = 28
	style.content_margin_top = 22
	style.content_margin_bottom = 22
	panel.add_theme_stylebox_override("panel", style)
	overlay.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var title := Label.new()
	title.text = title_text
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(title)
	panel.set_meta("content", vb)
	panel.set_meta("layer", overlay)
	return panel

func _close_popup() -> void:
	var overlay := get_node_or_null("PopupLayer")
	if overlay != null:
		overlay.queue_free()

# ================================================================ 设置
func _load_settings() -> void:
	var err := _settings.load(SETTINGS_PATH)
	if err != OK:
		_settings.set_value("graphics", "quality", "中")
		_settings.set_value("camera", "sensitivity", 1.0)
		_settings.set_value("camera", "fov", 70.0)
		_settings.set_value("camera", "invert_y", false)
		_settings.set_value("touch", "scale", 1.0)
		_settings.set_value("audio", "master", 0.9)
		_settings.set_value("audio", "music", 0.8)
		_settings.set_value("audio", "sfx", 1.0)

func _save_and_apply_settings() -> void:
	_settings.save(SETTINGS_PATH)
	_apply_settings()

func _apply_settings() -> void:
	var master := float(_settings.get_value("audio", "master", 0.9))
	var music := float(_settings.get_value("audio", "music", 0.8))
	var sfx := float(_settings.get_value("audio", "sfx", 1.0))
	AudioManager.set_bus_volume("Master", master)
	AudioManager.set_bus_volume("Music", music)
	AudioManager.set_bus_volume("SFX", sfx)
	var quality: String = _settings.get_value("graphics", "quality", "中")
	var window := get_viewport()
	match quality:
		"低":
			window.scaling_3d_scale = 0.6
		"中":
			window.scaling_3d_scale = 0.8
		"高":
			window.scaling_3d_scale = 1.0
	if _world != null:
		_world.apply_quality(quality)

func camera_sensitivity() -> float:
	return float(_settings.get_value("camera", "sensitivity", 1.0))

func camera_fov() -> float:
	return float(_settings.get_value("camera", "fov", 70.0))

func camera_invert_y() -> bool:
	return bool(_settings.get_value("camera", "invert_y", false))

func touch_scale() -> float:
	return float(_settings.get_value("touch", "scale", 1.0))

# ================================================================ 过场与结局
func play_cutscene(id: String) -> void:
	var cs := preload("res://scripts/cutscene/cutscene_player.gd").new()
	cs.cutscene_id = id
	add_child(cs)

func open_shop(_shop_id: String) -> void:
	if _world != null:
		_world.open_shop()

func on_ending(ending_id: String) -> void:
	GameState.ending_id = ending_id
	get_tree().paused = false
	AudioManager.stop_music(3.0)
	var ending := CanvasLayer.new()
	ending.layer = 80
	add_child(ending)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.88)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	ending.add_child(dim)
	var titles := {
		"continue_flame": ["结局一 · 续焰", "灯塔重燃,炉边镇得享十年暖冬。\n但眠霜巨龙的火光,正一点点黯淡下去。\n你在烬峰之巅明白:有些温暖,是向未来借来的。"],
		"release_dragon": ["结局二 · 释龙", "灯塔熄灭的那个冬天,夺走了十九位镇民。\n第五年春天,第一株绿芽钻出残雪。\n眠霜睁开了眼睛。世界记得你的名字,也记得你的代价。"],
		"ember_legacy": ["结局三 · 薪传(隐藏)", "守烬人之血成为媒介,龙火与人火共生共燃。\n炉边镇的钟声与龙的低鸣,在同一片黎明里回响。\n老窑说:火焰从来不属于一个人,它属于传递它的人。"],
	}
	var t: Array = titles.get(ending_id, ["结局 · 未知", "……"])
	var title := Label.new()
	title.text = t[0]
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", Color(1.0, 0.8, 0.5))
	title.set_anchors_preset(Control.PRESET_CENTER_TOP)
	title.position = Vector2(0, 140)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.add_child(title)
	var body := Label.new()
	body.text = t[1]
	body.add_theme_font_size_override("font_size", 24)
	body.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95))
	body.set_anchors_preset(Control.PRESET_CENTER)
	body.grow_horizontal = Control.GROW_DIRECTION_BOTH
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.add_child(body)
	var stats := Label.new()
	stats.text = "等级 %d · 游玩时长 %s · 完成任务 %d" % [
		GameState.level, SaveManager.format_play_time(GameState.play_seconds), QuestManager.completed.size()]
	stats.add_theme_font_size_override("font_size", 20)
	stats.add_theme_color_override("font_color", Color(0.7, 0.72, 0.75))
	stats.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	stats.position = Vector2(0, -160)
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ending.add_child(stats)
	var back := Button.new()
	back.text = "回到主菜单"
	back.add_theme_font_size_override("font_size", 24)
	back.custom_minimum_size = Vector2(280, 64)
	back.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	back.position = Vector2(-140, -80)
	back.pressed.connect(func():
		ending.queue_free()
		_back_to_menu())
	ending.add_child(back)
	AudioManager.play_music("ending")
