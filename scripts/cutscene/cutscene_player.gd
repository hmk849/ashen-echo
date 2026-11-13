extends CanvasLayer
## 电影化过场:黑边、镜头路径、字幕序列、可跳过。

var cutscene_id := ""
var _dim_top: ColorRect
var _dim_bottom: ColorRect
var _caption: Label
var _camera: Camera3D
var _elapsed := 0.0
var _captions: Array = []
var _path: Array = []
var _duration := 10.0
var _finished := false

const CUTSCENES := {
	"intro": {
		"duration": 16.0,
		"captions": [
			{"t": 0.5, "speaker": "旁白", "text": "长冬第七年。太阳被灰烬遮蔽,霜烬大陆只剩白与灰。"},
			{"t": 5.0, "speaker": "旁白", "text": "传说中七座余烬灯塔,如今只剩烬峰山脚下的一座,仍在燃烧。"},
			{"t": 10.0, "speaker": "旁白", "text": "它庇护着炉边镇——也庇护着最后的守烬人。"},
			{"t": 13.5, "speaker": "洛尘", "text": "老窑……你到底去了哪里?"},
		],
		"path": [
			{"pos": [30, 14, 40], "look": [0, 6, 0]},
			{"pos": [-24, 10, 30], "look": [0, 6, -20]},
			{"pos": [6, 9, 28], "look": [0, 7, 0]},
		],
	},
	"peak_arrival": {
		"duration": 10.0,
		"captions": [
			{"t": 0.5, "speaker": "旁白", "text": "烬峰之巅。风声呼啸,祭坛的火光在雪幕中明灭。"},
			{"t": 5.0, "speaker": "洛尘", "text": "答案,就在这里了。"},
		],
		"path": [
			{"pos": [186, 58, 176], "look": [196, 55, 196]},
			{"pos": [190, 57, 184], "look": [196, 55, 196]},
		],
	},
}

func _ready() -> void:
	layer = 70
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not CUTSCENES.has(cutscene_id):
		queue_free()
		return
	var def: Dictionary = CUTSCENES[cutscene_id]
	_duration = float(def["duration"])
	_captions = def["captions"]
	_path = def["path"]
	get_tree().paused = true
	EventBus.cutscene_started.emit()
	# 黑边
	_dim_top = ColorRect.new()
	_dim_top.color = Color(0, 0, 0, 1)
	_dim_top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_dim_top.custom_minimum_size = Vector2(0, 90)
	add_child(_dim_top)
	_dim_bottom = ColorRect.new()
	_dim_bottom.color = Color(0, 0, 0, 1)
	_dim_bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_dim_bottom.custom_minimum_size = Vector2(0, 90)
	add_child(_dim_bottom)
	_caption = Label.new()
	_caption.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_caption.position = Vector2(-500, -220)
	_caption.custom_minimum_size = Vector2(1000, 0)
	_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_caption.add_theme_font_size_override("font_size", 24)
	_caption.add_theme_color_override("font_color", Color(1, 0.95, 0.85))
	_caption.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	_caption.add_theme_constant_override("outline_size", 6)
	add_child(_caption)
	# 过场相机
	var world := get_tree().get_first_node_in_group("world")
	_camera = Camera3D.new()
	_camera.fov = 60
	world.add_child(_camera)
	_camera.make_current()
	AudioManager.play_sfx("ui_open")

func _process(delta: float) -> void:
	if _finished:
		return
	_elapsed += delta
	var t := clampf(_elapsed / _duration, 0.0, 1.0)
	# 相机沿路径插值
	var path_t := t * float(_path.size() - 1)
	var seg := int(path_t)
	var f := path_t - float(seg)
	var from: Dictionary = _path[seg]
	var to: Dictionary = _path[mini(seg + 1, _path.size() - 1)]
	var pos := Vector3(from["pos"][0], from["pos"][1], from["pos"][2]).lerp(
		Vector3(to["pos"][0], to["pos"][1], to["pos"][2]), f)
	var look := Vector3(from["look"][0], from["look"][1], from["look"][2]).lerp(
		Vector3(to["look"][0], to["look"][1], to["look"][2]), f)
	_camera.global_position = pos
	_camera.look_at(look, Vector3.UP)
	# 字幕
	var text := ""
	for c: Dictionary in _captions:
		if float(c["t"]) <= _elapsed:
			text = "[b]%s[/b]  %s" % [c["speaker"], c["text"]]
	_caption.text = text
	if _elapsed >= _duration:
		_finish()

func _finish() -> void:
	_finished = true
	_camera.queue_free()
	queue_free()
	get_tree().paused = false
	EventBus.cutscene_ended.emit()
	# 玩家相机恢复
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var cam: Node3D = player.get_node_or_null("CameraRig")
		if cam != null:
			var game_cam: Camera3D = cam.get_node_or_null("SpringArm3D/Camera3D")
			if game_cam != null:
				game_cam.make_current()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause") or (event is InputEventScreenTouch and event.pressed and _elapsed > 2.0):
		_finish()
