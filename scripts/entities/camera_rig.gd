extends Node3D
## 相机系统:第三人称弹簧臂 + 第一人称;鼠标/触屏/手柄视角输入;战斗时自动回正。

var pitch := -0.25
var yaw := 0.0
var _spring: SpringArm3D
var _camera: Camera3D
var _sensitivity := 1.0
var _touch_active_id := -1
var _touch_last_pos := Vector2.ZERO

func _ready() -> void:
	var main := get_tree().get_first_node_in_group("main_controller")
	_camera = Camera3D.new()
	_camera.fov = 70.0
	_camera.near = 0.1
	_camera.far = 400.0
	if main != null:
		_sensitivity = main.camera_sensitivity()
		_camera.fov = main.camera_fov()
	_spring = SpringArm3D.new()
	_spring.spring_length = 4.2
	_spring.collision_mask = 1
	_spring.add_child(_camera)
	add_child(_spring)
	position = Vector3(0, 1.55, 0)
	_camera.make_current()
	apply_first_person(false)

func apply_first_person(fp: bool) -> void:
	if fp:
		_spring.spring_length = 0.25
		_camera.position = Vector3(0, 0.12, 0)
	else:
		_spring.spring_length = 4.2
		_camera.position = Vector3(0, 0.3, 0)

func set_first_person(fp: bool) -> void:
	apply_first_person(fp)

func _unhandled_input(event: InputEvent) -> void:
	# 鼠标移动(桌面)
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_rotate(event.relative * 0.003 * _sensitivity)
	# 触屏:屏幕右侧 40% 区域拖动控制视角
	if event is InputEventScreenTouch and event.pressed:
		var vp := get_viewport().get_visible_rect()
		if event.position.x > vp.size.x * 0.55:
			_touch_active_id = event.index
			_touch_last_pos = event.position
	elif event is InputEventScreenTouch and not event.pressed:
		if event.index == _touch_active_id:
			_touch_active_id = -1
	elif event is InputEventScreenDrag and event.index == _touch_active_id:
		var drag := event as InputEventScreenDrag
		var delta: Vector2 = drag.position - _touch_last_pos
		_touch_last_pos = event.position
		_rotate(delta * 0.006 * _sensitivity)

func _rotate(delta: Vector2) -> void:
	var main := get_tree().get_first_node_in_group("main_controller")
	var invert := false
	if main != null:
		invert = main.camera_invert_y()
	yaw -= delta.x
	pitch += delta.y * (-1.0 if invert else 1.0)
	pitch = clampf(pitch, -1.2, 0.6)

func _process(delta: float) -> void:
	# 手柄右摇杆
	var axis_x := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	var axis_y := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	if absf(axis_x) > 0.15:
		yaw -= axis_x * 2.4 * delta * _sensitivity
	if absf(axis_y) > 0.15:
		pitch += axis_y * 2.0 * delta * _sensitivity
		pitch = clampf(pitch, -1.2, 0.6)
	rotation.y = yaw
	rotation.x = pitch
	# 第一人称时朝向与角色一致
	var player: CharacterBody3D = get_parent()
	if player != null and _spring.spring_length < 0.5:
		player.rotation.y = yaw + PI
