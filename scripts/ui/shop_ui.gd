extends CanvasLayer
## 简易商店:购买药剂/材料/装备,由对话动作触发。

const STOCK := [
	{"id": "herb_paste", "price": 12},
	{"id": "vigor_potion", "price": 30},
	{"id": "warm_soup", "price": 18},
	{"id": "cold_iron_ingot", "price": 40},
]

var _panel: PanelContainer

func _ready() -> void:
	layer = 55
	visible = false
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()

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
	vb.add_theme_constant_override("separation", 8)
	_panel.add_child(vb)
	var title := Label.new()
	title.text = "白鸢的杂货"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1.0, 0.78, 0.45))
	vb.add_child(title)
	var gold := Label.new()
	gold.name = "GoldLabel"
	gold.add_theme_font_size_override("font_size", 19)
	vb.add_child(gold)
	for entry: Dictionary in STOCK:
		var item := GameData.get_item(entry["id"])
		var btn := Button.new()
		btn.text = "%s —— %d 雪币 · %s" % [item.get("name", entry["id"]), entry["price"], item.get("desc", "")]
		btn.add_theme_font_size_override("font_size", 18)
		btn.custom_minimum_size = Vector2(520, 52)
		btn.pressed.connect(func(): _buy(entry["id"], int(entry["price"])))
		vb.add_child(btn)
	var close := Button.new()
	close.text = "离开"
	close.add_theme_font_size_override("font_size", 19)
	close.custom_minimum_size = Vector2(520, 52)
	close.pressed.connect(func(): visible = false)
	vb.add_child(close)

func open() -> void:
	visible = true
	AudioManager.play_sfx("ui_open")
	_refresh_gold()

func _refresh_gold() -> void:
	var label: Label = _find_node_by_name(self, "GoldLabel")
	if label != null:
		label.text = "持有雪币:%d" % GameState.gold

func _find_node_by_name(node: Node, node_name: String) -> Node:
	if node.name == node_name:
		return node
	for c in node.get_children():
		var found := _find_node_by_name(c, node_name)
		if found != null:
			return found
	return null

func _buy(item_id: String, price: int) -> void:
	if GameState.gold < price:
		EventBus.notify.emit("购买失败", "雪币不足。")
		AudioManager.play_sfx("ui_click")
		return
	GameState.gold -= price
	GameState.add_item(item_id, 1)
	AudioManager.play_sfx("pickup")
	EventBus.notify.emit("购买成功", "购入 %s。" % GameData.get_item(item_id).get("name", item_id))
	_refresh_gold()
