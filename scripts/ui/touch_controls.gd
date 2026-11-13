extends CanvasLayer
## 触屏控制:左侧虚拟摇杆、右侧按键(攻击/翻滚/跳跃/格挡/交互/技能)、视角区域。

var _joystick_center := Vector2.ZERO
var _joystick_active := false
var _joystick_touch_id := -1
var _joystick_bg: Control
var _joystick_knob: Control
var _scale := 1.0

const JOY_RADIUS := 110.0

func _ready() -> void:
	layer = 15
	var main := get_tree().get_first_node_in_group("main_controller")
	if main != null:
		_scale = main.touch_scale()
	_build_joystick()
	_build_buttons()

func _build_joystick() -> void:
	_joystick_bg = Control.new()
	_joystick_bg.custom_minimum_size = Vector2(JOY_RADIUS * 2.0 * _scale, JOY_RADIUS * 2.0 * _scale)
	_joystick_bg.position = Vector2(60, 0)
	_joystick_bg.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	_joystick_bg.position = Vector2(70, -70) - Vector2(0, JOY_RADIUS * 2.0 * _scale - 70)
	_joystick_bg.draw.connect(_draw_joystick)
	add_child(_joystick_bg)
	_joystick_knob = Control.new()
	_joystick_knob.custom_minimum_size = Vector2(90 * _scale, 90 * _scale)
	_joystick_bg.add_child(_joystick_knob)
	_joystick_bg.position = Vector2(80, get_viewport().get_visible_rect().size.y - JOY_RADIUS * 2.0 * _scale - 60)
	_joystick_bg.custom_minimum_size = Vector2(JOY_RADIUS * 2.0 * _scale, JOY_RADIUS * 2.0 * _scale)

func _draw_joystick() -> void:
	var rect := Rect2(Vector2.ZERO, _joystick_bg.size)
	(_joystick_bg as Control).draw_circle(rect.get_center(), JOY_RADIUS * _scale, Color(1, 1, 1, 0.08))
	(_joystick_bg as Control).draw_arc(rect.get_center(), JOY_RADIUS * _scale, 0, TAU, 48, Color(1, 1, 1, 0.25), 2.0)

func _build_buttons() -> void:
	# 右下角:攻击(大)+ 环绕小按钮
	var vp := get_viewport().get_visible_rect().size
	var attack := _make_button("攻击", 110.0 * _scale, Vector2(vp.x - 150.0 * _scale, vp.y - 170.0 * _scale), "attack", Color(0.8, 0.3, 0.2))
	add_child(attack)
	add_child(_make_button("翻滚", 78.0 * _scale, Vector2(vp.x - 260.0 * _scale, vp.y - 120.0 * _scale), "roll", Color(0.3, 0.5, 0.8)))
	add_child(_make_button("跳跃", 66.0 * _scale, Vector2(vp.x - 150.0 * _scale, vp.y - 300.0 * _scale), "jump", Color(0.3, 0.7, 0.5)))
	add_child(_make_button("格挡", 66.0 * _scale, Vector2(vp.x - 60.0 * _scale, vp.y - 210.0 * _scale), "block", Color(0.6, 0.6, 0.3)))
	add_child(_make_button("交谈", 66.0 * _scale, Vector2(vp.x - 250.0 * _scale, vp.y - 250.0 * _scale), "interact", Color(0.7, 0.5, 0.8)))
	add_child(_make_button("烬火", 60.0 * _scale, Vector2(vp.x - 350.0 * _scale, vp.y - 130.0 * _scale), "skill_heal", Color(0.9, 0.5, 0.2)))

func _make_button(text: String, size: float, pos: Vector2, action: String, color: Color) -> Control:
	var btn := Button.new()
	btn.text = text
	btn.add_theme_font_size_override("font_size", int(16 * _scale))
	btn.custom_minimum_size = Vector2(size, size)
	btn.position = pos
	btn.modulate = color
	btn.toggle_mode = false
	btn.button_down.connect(func(): TouchInput.set_button(action, true))
	btn.button_up.connect(func(): TouchInput.set_button(action, false))
	btn.focus_mode = Control.FOCUS_NONE
	return btn

func _input(event: InputEvent) -> void:
	var vp_size := get_viewport().get_visible_rect().size
	if event is InputEventScreenTouch and event.pressed:
		# 左半屏下部 → 摇杆
		if event.position.x < vp_size.x * 0.45 and event.position.y > vp_size.y * 0.35:
			if _joystick_touch_id == -1:
				_joystick_touch_id = event.index
				_joystick_active = true
				_joystick_center = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		if event.index == _joystick_touch_id:
			_joystick_touch_id = -1
			_joystick_active = false
			TouchInput.move_vector = Vector2.ZERO
			if _joystick_knob != null:
				_joystick_knob.position = Vector2(JOY_RADIUS * _scale - 45.0 * _scale, JOY_RADIUS * _scale - 45.0 * _scale)
	elif event is InputEventScreenDrag and event.index == _joystick_touch_id:
		var drag := event as InputEventScreenDrag
		var delta: Vector2 = drag.position - _joystick_center
		var dist: float = delta.length()
		var dir: Vector2 = delta.normalized() if dist > 0 else Vector2.ZERO
		var clamped: Vector2 = dir * minf(dist, JOY_RADIUS * _scale)
		TouchInput.move_vector = Vector2(dir.x, -dir.y) * clampf(dist / (JOY_RADIUS * _scale), 0.0, 1.0)
		if _joystick_knob != null:
			_joystick_knob.position = Vector2(JOY_RADIUS * _scale - 45.0 * _scale, JOY_RADIUS * _scale - 45.0 * _scale) + clamped
