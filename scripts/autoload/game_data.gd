extends Node
## 静态数据加载器:物品 / 任务 / NPC / 对话 / 敌人 / 地点。
## 同时负责在启动时注册输入动作(键盘 + 手柄),保证跨平台可用。

const DATA_DIR := "res://data"

var items: Dictionary = {}
var quests: Dictionary = {}
var npcs: Dictionary = {}
var dialogue: Dictionary = {}
var enemies: Dictionary = {}
var locations: Dictionary = {}

func _ready() -> void:
	_register_input_actions()
	items = _load_json("items.json")
	quests = _load_json("quests.json")
	npcs = _load_json("npcs.json")
	dialogue = _load_json("dialogue.json")
	enemies = _load_json("enemies.json")
	locations = _load_json("locations.json")

func _load_json(file_name: String) -> Dictionary:
	var path := DATA_DIR + "/" + file_name
	if not FileAccess.file_exists(path):
		push_error("GameData: 缺少数据文件 " + path)
		return {}
	var text := FileAccess.get_file_as_string(path)
	var parsed = JSON.parse_string(text)
	if parsed is Dictionary:
		return parsed
	push_error("GameData: JSON 解析失败 " + path)
	return {}

func get_item(id: String) -> Dictionary:
	return items.get(id, {})

func get_quest(id: String) -> Dictionary:
	return quests.get(id, {})

func get_npc(id: String) -> Dictionary:
	return npcs.get(id, {})

func get_enemy(id: String) -> Dictionary:
	return enemies.get(id, {})

func get_location(id: String) -> Dictionary:
	return locations.get(id, {})

func get_dialogue_node(node_id: String) -> Dictionary:
	return dialogue.get("nodes", {}).get(node_id, {})

# ---------------------------------------------------------------- 输入注册
func _register_input_actions() -> void:
	var key_actions := {
		"move_left": [KEY_A], "move_right": [KEY_D],
		"move_forward": [KEY_W], "move_back": [KEY_S],
		"jump": [KEY_SPACE], "sprint": [KEY_SHIFT],
		"attack": [MOUSE_BUTTON_LEFT], "block": [MOUSE_BUTTON_RIGHT],
		"roll": [KEY_CTRL], "interact": [KEY_E],
		"toggle_view": [KEY_V], "pause": [KEY_ESCAPE],
		"inventory": [KEY_I], "quest_log": [KEY_J],
		"skill_tree": [KEY_K], "toggle_map": [KEY_M], "heal_skill": [KEY_F],
	}
	for action: String in key_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for code: int in key_actions[action]:
			if code >= MOUSE_BUTTON_LEFT and code <= MOUSE_BUTTON_MIDDLE:
				var ev := InputEventMouseButton.new()
				ev.button_index = code as MouseButton
				InputMap.action_add_event(action, ev)
			else:
				var kev := InputEventKey.new()
				kev.physical_keycode = code as Key
				InputMap.action_add_event(action, kev)
	# 手柄映射(Xbox 布局,兼容 iOS 官方支持的手柄)
	var joy_actions := {
		"attack": [JOY_BUTTON_X], "block": [JOY_BUTTON_B],
		"roll": [JOY_BUTTON_A], "jump": [JOY_BUTTON_A],
		"sprint": [JOY_BUTTON_LEFT_SHOULDER],
		"interact": [JOY_BUTTON_Y], "pause": [JOY_BUTTON_START],
		"toggle_view": [JOY_BUTTON_RIGHT_SHOULDER],
		"inventory": [JOY_BUTTON_LEFT_STICK], "quest_log": [JOY_BUTTON_RIGHT_STICK],
	}
	for action: String in joy_actions:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for btn: int in joy_actions[action]:
			var bev := InputEventJoypadButton.new()
			bev.button_index = btn as JoyButton
			InputMap.action_add_event(action, bev)
	# 摇杆移动
	if not InputMap.has_action("move_left"):
		InputMap.add_action("move_left")
	# 双摇杆轴
	var axes := {
		"axis_left_x": [JOY_AXIS_LEFT_X],
		"axis_left_y": [JOY_AXIS_LEFT_Y],
		"axis_right_x": [JOY_AXIS_RIGHT_X],
		"axis_right_y": [JOY_AXIS_RIGHT_Y],
	}
	for action: String in axes:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for ax: int in axes[action]:
			var aev := InputEventJoypadMotion.new()
			aev.axis = ax as JoyAxis
			aev.axis_value = 1.0
			InputMap.action_add_event(action, aev)
	# d-pad
	var dpad := {
		"dpad_left": [JOY_BUTTON_DPAD_LEFT], "dpad_right": [JOY_BUTTON_DPAD_RIGHT],
		"dpad_up": [JOY_BUTTON_DPAD_UP], "dpad_down": [JOY_BUTTON_DPAD_DOWN],
	}
	for action: String in dpad:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for btn: int in dpad[action]:
			var bev := InputEventJoypadButton.new()
			bev.button_index = btn as JoyButton
			InputMap.action_add_event(action, bev)
