extends CanvasLayer
## 背包:网格物品栏、使用/装备/丢弃、装备槽与属性总览。

var _panel: PanelContainer
var _grid: GridContainer
var _detail: RichTextLabel
var _use_btn: Button
var _equip_btn: Button
var _drop_btn: Button
var _selected_id := ""
var _stats_label: Label

func _ready() -> void:
	layer = 50
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	GameState.inventory_changed.connect(func(): _rebuild() if visible else null)

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
	title.text = "背包"
	title.add_theme_font_size_override("font_size", 30)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(title)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 20)
	vb.add_child(columns)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 8)
	columns.add_child(left)
	_grid = GridContainer.new()
	_grid.columns = 6
	_grid.add_theme_constant_override("h_separation", 8)
	_grid.add_theme_constant_override("v_separation", 8)
	left.add_child(_grid)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 17)
	_stats_label.add_theme_color_override("font_color", Color(0.8, 0.85, 0.9))
	left.add_child(_stats_label)
	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(380, 0)
	right.add_theme_constant_override("separation", 8)
	columns.add_child(right)
	_detail = RichTextLabel.new()
	_detail.custom_minimum_size = Vector2(380, 300)
	_detail.bbcode_enabled = true
	_detail.add_theme_font_size_override("normal_font_size", 18)
	right.add_child(_detail)
	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 10)
	right.add_child(btn_row)
	_use_btn = _action_button("使用")
	btn_row.add_child(_use_btn)
	_equip_btn = _action_button("装备")
	btn_row.add_child(_equip_btn)
	_drop_btn = _action_button("丢弃")
	btn_row.add_child(_drop_btn)
	var close := Button.new()
	close.text = "关闭 (I)"
	close.add_theme_font_size_override("font_size", 19)
	close.custom_minimum_size = Vector2(200, 50)
	close.pressed.connect(func(): visible = false)
	vb.add_child(close)
	_use_btn.pressed.connect(_use_selected)
	_equip_btn.pressed.connect(_equip_selected)
	_drop_btn.pressed.connect(_drop_selected)

func _action_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 19)
	b.custom_minimum_size = Vector2(110, 50)
	b.disabled = true
	return b

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("inventory"):
		visible = not visible
		if visible:
			_rebuild()
		get_viewport().set_input_as_handled()

func _rebuild() -> void:
	for c in _grid.get_children():
		c.queue_free()
	var item_ids: Array = GameState.inventory.keys()
	item_ids.sort()
	for item_id: String in item_ids:
		var item := GameData.get_item(item_id)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 84)
		var color := Color(0.5, 0.5, 0.5)
		var raw_color: Variant = item.get("color", null)
		if raw_color is Array and (raw_color as Array).size() >= 3:
			var ca: Array = raw_color
			color = Color(float(ca[0]), float(ca[1]), float(ca[2]))
		var type_name := _type_name(item.get("type", ""))
		btn.text = "%s\n%s ×%d" % [item.get("name", item_id), type_name, int(GameState.inventory[item_id])]
		btn.add_theme_font_size_override("font_size", 14)
		btn.modulate = color.lerp(Color.WHITE, 0.55)
		btn.pressed.connect(func():
			_selected_id = item_id
			_show_detail(item_id))
		_grid.add_child(btn)
	_update_stats()
	if not _selected_id.is_empty():
		_show_detail(_selected_id)

func _type_name(t: String) -> String:
	return {"weapon": "武器", "armor": "护甲", "consumable": "消耗品", "material": "材料", "quest": "任务"}.get(t, t)

func _update_stats() -> void:
	var weapon := GameData.get_item(GameState.equipped_weapon)
	var armor := GameData.get_item(GameState.equipped_armor)
	_stats_label.text = "装备: %s(攻 %d)/ %s(防 %d)\n攻击力 %d · 防御 %d · 金币 %d" % [
		weapon.get("name", "-"), int(weapon.get("attack", 0)),
		armor.get("name", "-"), int(armor.get("defense", 0)),
		int(GameState.attack_power()), int(GameState.defense_power()), GameState.gold]

func _show_detail(item_id: String) -> void:
	var item := GameData.get_item(item_id)
	var text := "[color=#f0c060]%s[/color]\n[color=#a0a8b0]%s[/color]\n\n" % [item.get("name", ""), _type_name(item.get("type", ""))]
	text += item.get("desc", "") + "\n\n"
	if item.get("type", "") == "weapon":
		text += "攻击力:%d" % int(item.get("attack", 0))
	elif item.get("type", "") == "armor":
		text += "防御:%d" % int(item.get("defense", 0))
	elif item.get("type", "") == "consumable":
		text += "效果:%s" % item.get("effect_desc", "")
	_detail.text = text
	_use_btn.disabled = item.get("type", "") != "consumable"
	_equip_btn.disabled = not (item.get("type", "") in ["weapon", "armor"])
	_drop_btn.disabled = item.get("type", "") == "quest"

func _use_selected() -> void:
	if _selected_id.is_empty():
		return
	var item := GameData.get_item(_selected_id)
	if item.get("type", "") != "consumable":
		return
	var effect: String = item.get("effect", "")
	if effect.begins_with("heal"):
		var amount := float(item.get("amount", 20))
		GameState.heal(amount)
		AudioManager.play_sfx("drink")
		EventBus.notify.emit("使用物品", "%s:恢复 %d 生命。" % [item.get("name", ""), int(amount)])
	elif effect == "stamina":
		GameState.stamina = GameState.max_stamina
		AudioManager.play_sfx("drink")
		EventBus.notify.emit("使用物品", "%s:体力完全恢复。" % item.get("name", ""))
	elif effect == "warm":
		GameState.heal(float(item.get("amount", 10)))
		GameState.stamina = GameState.max_stamina
		AudioManager.play_sfx("drink")
		EventBus.notify.emit("使用物品", "%s:暖意涌上心头。" % item.get("name", ""))
	GameState.remove_item(_selected_id, 1)
	_rebuild()

func _equip_selected() -> void:
	if _selected_id.is_empty():
		return
	var item := GameData.get_item(_selected_id)
	match item.get("type", ""):
		"weapon":
			GameState.equipped_weapon = _selected_id
			AudioManager.play_sfx("ui_click")
			EventBus.notify.emit("装备", "已装备 %s。" % item.get("name", ""))
		"armor":
			GameState.equipped_armor = _selected_id
			AudioManager.play_sfx("ui_click")
			EventBus.notify.emit("装备", "已装备 %s。" % item.get("name", ""))
	_rebuild()

func _drop_selected() -> void:
	if _selected_id.is_empty():
		return
	var item := GameData.get_item(_selected_id)
	if item.get("type", "") == "quest":
		return
	GameState.remove_item(_selected_id, 1)
	EventBus.notify.emit("丢弃", "丢掉了 %s。" % item.get("name", ""))
	_rebuild()
