extends Node
## 触屏输入桥:虚拟摇杆 / 视角拖动 / 虚拟按键 → 统一供玩家与相机读取。
## 桌面与手柄输入仍走 Input 单例,两者在玩家脚本里合并。

var move_vector := Vector2.ZERO     # 左摇杆:移动
var look_delta := Vector2.ZERO      # 右侧拖动:视角,每帧消费
var buttons: Dictionary = {}        # 按钮名 -> 持续状态
var buttons_just: Dictionary = {}   # 按钮名 -> 本帧刚按下

const BUTTONS := ["attack", "roll", "jump", "interact", "sprint", "block", "skill_heal"]

func _ready() -> void:
	for b: String in BUTTONS:
		buttons[b] = false
		buttons_just[b] = false

func set_button(name_id: String, pressed: bool) -> void:
	if pressed and not buttons.get(name_id, false):
		buttons_just[name_id] = true
	buttons[name_id] = pressed

func consume_look() -> Vector2:
	var d := look_delta
	look_delta = Vector2.ZERO
	return d

func end_frame() -> void:
	for b: String in BUTTONS:
		buttons_just[b] = false

func button_pressed(name_id: String) -> bool:
	return buttons.get(name_id, false)

func button_just_pressed(name_id: String) -> bool:
	return buttons_just.get(name_id, false)
