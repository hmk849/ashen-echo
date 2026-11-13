extends CharacterBody3D
## 玩家:移动(摇杆/键盘/手柄)、跳跃、翻滚、连击、格挡、交互、第一/第三人称。

const WALK_SPEED := 4.2
const RUN_SPEED := 6.5
const JUMP_VELOCITY := 4.8
const GRAVITY := 9.8

var _attack_combo := 0
var _attack_timer := 0.0
var _attack_cd := 0.0
var _rolling := false
var _roll_timer := 0.0
var _iframe_timer := 0.0
var _blocking := false
var _invincible := false
var _footstep_timer := 0.0
var _walk_anim := 0.0
var _model: Node3D
var _sword: Node3D
var _weapon_length := 0.9
var _view_first_person := false
var _dead := false
var _near_interactable: Node3D = null

func _ready() -> void:
	name = "Player"
	add_to_group("player")
	# 碰撞体
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.35
	capsule.height = 1.7
	cs.shape = capsule
	cs.position = Vector3(0, 0.85, 0)
	add_child(cs)
	# 模型
	_model = EntityFactory.make_humanoid({
		"skin": Color(0.88, 0.74, 0.64),
		"cloth": Color(0.45, 0.3, 0.2),
		"pants": Color(0.25, 0.25, 0.3),
		"hair": Color(0.12, 0.1, 0.09),
	})
	add_child(_model)
	_sword = EntityFactory.make_sword(0.9)
	var hand: Node3D = _model.get_node("HandR")
	hand.add_child(_sword)
	_sword.rotation.x = PI  # 刀刃向下
	# 交互检测区域
	var area := Area3D.new()
	area.name = "InteractArea"
	var acs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.6
	acs.shape = sphere
	area.add_child(acs)
	area.position = Vector3(0, 1.0, 0)
	area.body_entered.connect(_on_interact_area_body)
	area.body_exited.connect(_on_interact_area_body_exit)
	area.area_entered.connect(func(a): _check_interactable(a))
	add_child(area)
	EventBus.player_died.connect(_on_respawn)

func _on_interact_area_body(body: Node3D) -> void:
	_check_interactable(body)

func _on_interact_area_body_exit(body: Node3D) -> void:
	if _near_interactable == body:
		_near_interactable = null

func _check_interactable(node: Node) -> void:
	if node is Node3D and node.has_meta("interact_prompt"):
		_near_interactable = node
		var prompt: String = node.get_meta("interact_prompt")
		var world := get_parent()
		if world != null and world.get("hud") != null:
			world.hud.set_interact_prompt(prompt)

func _physics_process(delta: float) -> void:
	if _dead:
		velocity.y -= GRAVITY * delta
		move_and_slide()
		return
	# 重力
	if not is_on_floor():
		velocity.y -= GRAVITY * delta
	else:
		velocity.y = maxf(velocity.y, -0.5)
	# 输入
	var input_dir := _move_input()
	var wish_dir := (transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized() if input_dir.length() > 0.1 else Vector3.ZERO
	# 暴雪减速
	var world := get_parent()
	var weather_slow := 1.0
	if world != null and world.weather != null and world.weather.current_id == "blizzard" and not GameState.has_skill("s4"):
		weather_slow = 0.72
	var sprint := _action_pressed("sprint") and GameState.stamina > 1.0
	var speed := (RUN_SPEED if sprint else WALK_SPEED) * weather_slow
	if sprint and wish_dir.length() > 0.1:
		GameState.stamina = maxf(GameState.stamina - 12.0 * delta, 0.0)
	else:
		GameState.stamina = minf(GameState.stamina + 8.0 * delta, GameState.max_stamina)
	if _rolling:
		_roll_timer -= delta
		if _roll_timer <= 0.0:
			_rolling = false
		speed = 8.0
	velocity.x = wish_dir.x * speed
	velocity.z = wish_dir.z * speed
	# 跳跃
	if is_on_floor() and _action_just_pressed("jump"):
		velocity.y = JUMP_VELOCITY
	# 翻滚
	if not _rolling and _action_just_pressed("roll") and GameState.consume_stamina(18.0):
		_rolling = true
		_roll_timer = 0.45
		_iframe_timer = 0.4
		AudioManager.play_sfx("roll")
	if TouchInput.button_just_pressed("skill_heal"):
		heal_skill()
	# 格挡
	_blocking = _action_pressed("block") and is_on_floor()
	# 攻击
	_update_attack(delta)
	# 体力无敌帧
	_iframe_timer = maxf(_iframe_timer - delta, 0.0)
	# 朝向:移动时面向移动方向(战斗时面向锁定目标省略)
	if wish_dir.length() > 0.1 and not _blocking:
		var target_yaw := atan2(wish_dir.x, wish_dir.z)
		rotation.y = lerp_angle(rotation.y, target_yaw, delta * 10.0)
	# 走路动画(摆动四肢)
	_animate_walk(delta, wish_dir.length())
	# 脚步声
	if is_on_floor() and wish_dir.length() > 0.1:
		_footstep_timer -= delta * (1.6 if sprint else 1.0)
		if _footstep_timer <= 0.0:
			_footstep_timer = 0.55
			AudioManager.play_sfx("footstep_snow", -6.0)
	move_and_slide()
	# 掉出世界保护
	if global_position.y < -30.0:
		global_position = Vector3(2, terrain_height(2, 6) + 2.0, 6)

func terrain_height(x: float, z: float) -> float:
	var world := get_parent()
	if world != null and world.terrain != null:
		return world.terrain.height(x, z)
	return 0.0

func _update_attack(delta: float) -> void:
	_attack_cd = maxf(_attack_cd - delta, 0.0)
	if _attack_timer > 0.0:
		_attack_timer -= delta
		if _attack_timer <= 0.0:
			_apply_attack_damage()
	if _action_just_pressed("attack") and not _rolling and _attack_cd <= 0.0 and not _blocking:
		_attack_combo = (_attack_combo + 1) % 3
		_attack_cd = 0.55
		_attack_timer = 0.22
		AudioManager.play_sfx("sword_swing")
		# 挥刀动画
		var tween := create_tween()
		var hand: Node3D = _model.get_node("HandR")
		tween.tween_property(hand, "rotation:x", -2.2, 0.08)
		tween.tween_property(hand, "rotation:x", 0.6, 0.18)
		tween.tween_property(hand, "rotation:x", 0.0, 0.1)

func _apply_attack_damage() -> void:
	var attack_range := 1.9 + _weapon_length * 0.5
	var forward := -global_transform.basis.z
	var world := get_parent()
	if world == null:
		return
	for e: Node in get_tree().get_nodes_in_group("enemies"):
		if e is CharacterBody3D and is_instance_valid(e):
			var to_enemy: Vector3 = (e.global_position - global_position)
			var dist := to_enemy.length()
			if dist > attack_range + 0.6:
				continue
			var dir_dot := forward.dot(to_enemy.normalized())
			if dir_dot < 0.35:
				continue
			e.take_damage(GameState.attack_power() * (1.0 + 0.15 * _attack_combo), global_position)

func take_damage(amount: float, _from: Vector3 = Vector3.ZERO) -> void:
	if _iframe_timer > 0.0 or _dead:
		return
	# 烬火护体:免死
	if GameState.hp - amount <= 0.0 and GameState.has_skill("e3") and not GameState.get_flag("e3_used_this_fight", false):
		GameState.set_flag("e3_used_this_fight", true)
		GameState.heal(GameState.max_hp * 0.3)
		EventBus.notify.emit("烬火护体", "在致命一击中,龙火的余温救了你。")
		amount = 0.0
	var mitigated := amount
	if _blocking:
		var block_mult := 0.5 - (0.2 if GameState.has_skill("c3") else 0.0)
		mitigated = amount * block_mult
		GameState.consume_stamina(15.0)
		if GameState.stamina <= 0.0:
			_blocking = false
	GameState.hp = maxf(GameState.hp - mitigated, 0.0)
	EventBus.player_damaged.emit(mitigated)
	AudioManager.play_sfx("hurt")
	_iframe_timer = 0.5
	if GameState.hp <= 0.0:
		_die()

func _die() -> void:
	_dead = true
	AudioManager.play_sfx("enemy_die")
	EventBus.player_died.emit()

func _on_respawn() -> void:
	# 在最近篝火复活
	var pos: Vector3 = GameState.last_campfire_pos
	if pos == Vector3.ZERO:
		pos = Vector3(8, terrain_height(8, 4) + 1.0, 4)
	GameState.hp = GameState.max_hp * 0.5
	GameState.gold = maxi(0, GameState.gold - 5)
	global_position = Vector3(pos.x, pos.y + 1.5, pos.z)
	velocity = Vector3.ZERO
	_dead = false
	GameState.set_flag("e3_used_this_fight", false)
	EventBus.notify.emit("苏醒", "你在篝火边醒来,丢失了 5 枚雪币。")
	EventBus.player_respawned.emit()

func heal_skill() -> void:
	if GameState.has_skill("e2") and GameState.consume_stamina(40.0) and GameState.hp < GameState.max_hp:
		GameState.heal(35.0)
		AudioManager.play_sfx("heal")
		EventBus.notify.emit("烬火复苏", "恢复 35 点生命。")

# ================================================================ 输入合并
func _move_input() -> Vector2:
	var v := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	# 手柄左摇杆
	var jx := Input.get_axis("dpad_left", "dpad_right")
	var jy := Input.get_axis("dpad_up", "dpad_down")
	v = v if v.length() > 0.05 else Vector2(jx, jy)
	# 触屏虚拟摇杆
	if TouchInput.move_vector.length() > 0.05:
		v = TouchInput.move_vector
	return v

func _action_pressed(action: String) -> bool:
	return Input.is_action_pressed(action) or TouchInput.button_pressed(action)

func _action_just_pressed(action: String) -> bool:
	return Input.is_action_just_pressed(action) or TouchInput.button_just_pressed(action)

func toggle_view() -> void:
	_view_first_person = not _view_first_person
	_model.visible = not _view_first_person

func _unhandled_input(event: InputEvent) -> void:
	if _dead:
		return
	if event.is_action_pressed("toggle_view"):
		toggle_view()
	if event.is_action_pressed("interact"):
		_try_interact()
	if event.is_action_pressed("heal_skill"):
		heal_skill()

func _try_interact() -> void:
	# 优先:附近 NPC(通过对话管理器)
	var nearest: Node3D = null
	var nearest_dist := 3.5
	for n: Node in get_tree().get_nodes_in_group("npcs"):
		if n is Node3D:
			var d: float = (n.global_position - global_position).length()
			if d < nearest_dist:
				nearest_dist = d
				nearest = n
	if nearest != null and nearest.has_method("interact"):
		nearest.interact()
		return
	if _near_interactable != null:
		if _near_interactable.has_meta("interact_dialogue"):
			DialogueManager.start(_near_interactable.get_meta("interact_dialogue"))
		elif _near_interactable.has_method("interact"):
			_near_interactable.interact()

# ================================================================ 程序化行走动画
func _animate_walk(delta: float, intensity: float) -> void:
	_walk_anim += delta * (6.0 + 6.0 * intensity)
	var swing := sin(_walk_anim) * 0.5 * intensity
	var arm_l: MeshInstance3D = _model.get_node_or_null("ArmL")
	var arm_r: MeshInstance3D = _model.get_node_or_null("ArmR")
	var leg_l: MeshInstance3D = _model.get_node_or_null("LegL")
	var leg_r: MeshInstance3D = _model.get_node_or_null("LegR")
	if arm_l != null:
		arm_l.rotation.x = swing
	if arm_r != null:
		arm_r.rotation.x = -swing * 0.4  # 右手持剑
	if leg_l != null:
		leg_l.rotation.x = -swing
	if leg_r != null:
		leg_r.rotation.x = swing
	var torso: MeshInstance3D = _model.get_node_or_null("Torso")
	if torso != null:
		torso.position.y = 1.15 + absf(sin(_walk_anim)) * 0.03 * intensity
