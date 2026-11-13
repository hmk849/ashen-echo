extends CharacterBody3D
## NPC:日程驱动的日常行为、闲逛、对话触发、任务关联。

var npc_id := ""
var _def: Dictionary = {}
var _model: Node3D
var _wander_target := Vector3.ZERO
var _wander_timer := 0.0
var _talking := false
var _schedule_target := Vector3.ZERO

func _ready() -> void:
	add_to_group("npcs")
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.6
	cs.shape = capsule
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	set_meta("interact_prompt", "交谈")

func build(def: Dictionary) -> void:
	_def = def
	var colors: Dictionary = def.get("colors", {})
	_model = EntityFactory.make_humanoid(colors)
	add_child(_model)
	# 名牌(头顶)
	var label := Label3D.new()
	label.text = def.get("name", npc_id)
	label.font_size = 48
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.fixed_size = false
	label.pixel_size = 0.01
	label.position = Vector3(0, 2.15, 0)
	label.modulate = Color(1.0, 0.9, 0.7)
	add_child(label)

func interact() -> void:
	if _talking:
		return
	_talking = true
	# 面向玩家
	var player := get_tree().get_first_node_in_group("player") as Node3D
	if player != null:
		var look := atan2(player.global_position.x - global_position.x, player.global_position.z - global_position.z)
		rotation.y = look
	var root: String = _def.get("dialogue_root", npc_id)
	DialogueManager.start(root)
	# 对话结束后恢复
	await _wait_dialogue_end()
	_talking = false

func _wait_dialogue_end() -> void:
	while DialogueManager.is_active():
		await get_tree().process_frame

func _physics_process(delta: float) -> void:
	if _talking:
		velocity = Vector3.ZERO
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	# 日程:根据小时选择目标点
	var hour := _world_hour()
	var schedule: Array = _def.get("schedule", [])
	var target := global_position
	if not schedule.is_empty():
		var chosen: Array = schedule[0]
		for entry: Array in schedule:
			if float(entry[0]) <= hour:
				chosen = entry
		var pos: Array = chosen[1]
		target = Vector3(pos[0], 0, pos[1])
	# 白天在日程点附近闲逛,夜间停在日程点
	var dist_xz := Vector2(global_position.x - target.x, global_position.z - target.z).length()
	_wander_timer -= delta
	if dist_xz > 2.5:
		var dir := (target - global_position)
		dir.y = 0
		dir = dir.normalized()
		velocity.x = dir.x * 2.2
		velocity.z = dir.z * 2.2
		rotation.y = atan2(dir.x, dir.z)
	elif _wander_timer <= 0.0:
		_wander_timer = randf_range(3.0, 8.0)
		var angle := randf_range(0, TAU)
		var r := randf_range(1.5, 5.0)
		_wander_target = target + Vector3(cos(angle) * r, 0, sin(angle) * r)
		velocity.x = 0
		velocity.z = 0
	else:
		var to_wander := _wander_target - global_position
		to_wander.y = 0
		if to_wander.length() > 0.8:
			var d := to_wander.normalized()
			velocity.x = d.x * 1.1
			velocity.z = d.z * 1.1
			rotation.y = atan2(d.x, d.z)
		else:
			velocity.x = 0
			velocity.z = 0
	# 贴地
	var world := get_parent()
	if world != null and world.terrain != null:
		var ground: float = world.terrain.height(global_position.x, global_position.z)
		if is_on_floor() and absf(global_position.y - ground) > 2.0:
			global_position.y = ground + 0.1
	move_and_slide()

func _world_hour() -> float:
	var world := get_parent()
	if world != null and world.day_night != null:
		return world.day_night.time_hours
	return 12.0
