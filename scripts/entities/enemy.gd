extends CharacterBody3D
## 敌人 AI:巡逻 → 发现(仇恨)→ 追击 → 攻击;受击硬直、死亡掉落。

var enemy_type := "cultist"
var is_boss := false
var hp := 40.0
var max_hp := 40.0
var attack_damage := 8.0
var move_speed := 3.0
var aggro_range := 14.0
var attack_range := 2.0
var attack_cooldown := 1.2
var xp_reward := 25
var loot_table: Array = []
var loot_count := 1

var _state := "patrol"
var _patrol_center := Vector3.ZERO
var _patrol_target := Vector3.ZERO
var _patrol_timer := 0.0
var _attack_timer := 0.0
var _hurt_timer := 0.0
var _dead := false
var _model: Node3D
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	add_to_group("enemies")
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.6 if not is_boss else 2.2
	cs.shape = capsule
	cs.position = Vector3(0, 0.8 if not is_boss else 1.1, 0)
	add_child(cs)

func build() -> void:
	var def: Dictionary = GameData.get_enemy(enemy_type)
	max_hp = float(def.get("hp", 40))
	hp = max_hp
	attack_damage = float(def.get("damage", 8))
	move_speed = float(def.get("speed", 3.0))
	aggro_range = float(def.get("aggro", 14.0))
	attack_range = float(def.get("attack_range", 2.0))
	xp_reward = int(def.get("xp", 25))
	loot_table = def.get("loot", [])
	_patrol_center = global_position
	_patrol_target = global_position
	if is_boss:
		set_meta("boss_key", enemy_type)
		loot_count = 3
	match def.get("model", "humanoid"):
		"wolf":
			_model = EntityFactory.make_wolf()
		"golem":
			_model = EntityFactory.make_golem(1.6)
		_:
			var colors: Dictionary = def.get("colors", {"cloth": Color(0.25, 0.1, 0.1), "pants": Color(0.15, 0.1, 0.12)})
			_model = EntityFactory.make_humanoid(colors)
			if def.get("weapon", true):
				var sword := EntityFactory.make_sword(0.8, Color(0.3, 0.3, 0.34))
				_model.get_node("HandR").add_child(sword)
	add_child(_model)
	var label := Label3D.new()
	label.text = def.get("name", enemy_type)
	label.font_size = 40
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.pixel_size = 0.012
	label.position = Vector3(0, 2.3, 0)
	label.modulate = Color(1.0, 0.6, 0.5)
	add_child(label)

func take_damage(amount: float, from_pos: Vector3) -> void:
	if _dead:
		return
	hp -= amount
	_hurt_timer = 0.25
	AudioManager.play_sfx("sword_hit")
	# 击退
	var push := (global_position - from_pos).normalized() * 3.0
	velocity.x = push.x
	velocity.z = push.z
	# 血条(头顶)
	_update_hp_label()
	if hp <= 0.0:
		_die()

func _update_hp_label() -> void:
	var label: Label3D = _find_label()
	if label != null:
		label.text = "%d/%d" % [ceili(hp), ceili(max_hp)]

func _find_label() -> Label3D:
	for c in get_children():
		if c is Label3D:
			return c
	return null

func _die() -> void:
	_dead = true
	AudioManager.play_sfx("enemy_die")
	EventBus.enemy_killed.emit(enemy_type, name)
	GameState.add_xp(xp_reward)
	# 掉落
	var loot_id: String = loot_table.pick_random() if not loot_table.is_empty() else ""
	if not loot_id.is_empty():
		for i: int in loot_count:
			var pickup := preload("res://scripts/entities/pickup.gd").new()
			pickup.item_id = loot_id
			pickup.label = GameData.get_item(loot_id).get("name", loot_id)
			get_parent().add_child(pickup)
			var angle := randf_range(0, TAU)
			pickup.global_position = global_position + Vector3(cos(angle) * 0.8, 1.0, sin(angle) * 0.8)
	# Boss 记录
	if is_boss:
		var bosses: Dictionary = GameState.get_flag("bosses_dead", {})
		bosses[enemy_type] = true
		GameState.set_flag("bosses_dead", bosses)
		GameState.set_flag("boss_dead_" + enemy_type, true)
	# 尸体淡出
	var tween := create_tween()
	tween.tween_property(self, "position:y", position.y - 0.8, 1.2)
	tween.parallel().tween_property(_model, "transparency", 1.0, 1.2)
	tween.tween_callback(queue_free)

func _physics_process(delta: float) -> void:
	if _dead:
		move_and_slide()
		return
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	_attack_timer = maxf(_attack_timer - delta, 0.0)
	_hurt_timer = maxf(_hurt_timer - delta, 0.0)
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	var dist := to_player.length()
	match _state:
		"patrol":
			_patrol_timer -= delta
			if _patrol_timer <= 0.0:
				_patrol_timer = randf_range(3.0, 7.0)
				var angle := randf_range(0, TAU)
				var r := randf_range(2.0, 8.0)
				_patrol_target = _patrol_center + Vector3(cos(angle) * r, 0, sin(angle) * r)
			_move_toward(_patrol_target, move_speed * 0.4)
			if dist < aggro_range and not DialogueManager.is_active():
				_state = "chase"
				if enemy_type == "wolf":
					AudioManager.play_sfx("wolf")
		"chase":
			if dist > aggro_range * 2.2:
				_state = "patrol"
			_move_toward(player.global_position, move_speed)
			if dist <= attack_range + 0.4:
				_state = "attack"
		"attack":
			_move_toward(player.global_position, 0.5)
			if dist > attack_range + 1.2:
				_state = "chase"
			elif _attack_timer <= 0.0 and _hurt_timer <= 0.0:
				_attack_timer = attack_cooldown
				# 攻击动画:向前扑
				var tween := create_tween()
				if _model != null:
					tween.tween_property(_model, "position:z", -0.5, 0.12)
					tween.tween_property(_model, "position:z", 0.0, 0.18)
				if dist <= attack_range + 0.8:
					(player as Node).call("take_damage", attack_damage, global_position)
	# 贴地
	var world := get_parent()
	if world != null and world.terrain != null and is_on_floor():
		var ground: float = world.terrain.height(global_position.x, global_position.z)
		if absf(global_position.y - ground) > 2.5:
			global_position.y = ground + 0.1
	move_and_slide()

func _move_toward(target: Vector3, speed: float) -> void:
	var dir := target - global_position
	dir.y = 0
	if dir.length() < 0.5:
		velocity.x = 0
		velocity.z = 0
		return
	dir = dir.normalized()
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	rotation.y = atan2(dir.x, dir.z)
