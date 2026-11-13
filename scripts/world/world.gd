extends Node3D
## 世界主控制器:地形、环境、昼夜、天气、聚落、NPC、敌人、玩家、交互与UI装配。

var terrain: TerrainGenerator = null
var day_night: DayNightCycle = null
var weather: WeatherSystem = null
var player: CharacterBody3D = null
var camera_rig: Node3D = null
var hud: CanvasLayer = null
var touch_controls: CanvasLayer = null
var shop_ui: CanvasLayer = null
var journal_ui: CanvasLayer = null
var inventory_ui: CanvasLayer = null
var skill_ui: CanvasLayer = null
var _spawned_pickups: Array[Node3D] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("world")
	terrain = preload("res://scripts/world/terrain_generator.gd").new()
	add_child(terrain)
	day_night = preload("res://scripts/world/day_night.gd").new()
	day_night.name = "DayNight"
	add_child(day_night)
	weather = preload("res://scripts/world/weather_system.gd").new()
	weather.name = "Weather"
	add_child(weather)
	var props := preload("res://scripts/world/props_builder.gd").new()
	add_child(props)
	_spawn_player()
	props.build(self)
	_spawn_npcs()
	_spawn_enemies()
	_spawn_pickups()
	_setup_location_triggers()
	_build_ui()
	EventBus.ending_reached.connect(_on_ending)
	EventBus.notify.connect(func(title, body): hud.toast(title, body))
	# 祭坛交互
	var altar := get_node_or_null("PeakAltar")
	if altar != null:
		altar.set_meta("interact_dialogue", "altar_root")
		altar.set_meta("interact_prompt", "查看祭坛")
	# 首次抵达烬峰播过场
	EventBus.location_reached.connect(func(loc_id):
		if loc_id == "peak" and not GameState.get_flag("seen_peak_cutscene", false):
			GameState.set_flag("seen_peak_cutscene", true)
			var main := get_tree().get_first_node_in_group("main_controller")
			if main != null:
				main.call("play_cutscene", "peak_arrival"))
	AudioManager.play_music("town")
	AudioManager.play_ambient("snow")
	_apply_ambient_volume()

func _apply_ambient_volume() -> void:
	AudioManager.set_ambient_volume_db(-8.0)

func _spawn_player() -> void:
	player = preload("res://scripts/entities/player.gd").new()
	player.name = "Player"
	add_child(player)
	var ground := terrain.height(2.0, 6.0)
	player.global_position = Vector3(2.0, ground + 1.2, 6.0)
	camera_rig = preload("res://scripts/entities/camera_rig.gd").new()
	camera_rig.name = "CameraRig"
	player.add_child(camera_rig)

func _spawn_npcs() -> void:
	for npc_id: String in GameData.npcs.keys():
		var def: Dictionary = GameData.npcs[npc_id]
		if def.get("cutscene_only", false):
			continue
		var npc := preload("res://scripts/entities/npc.gd").new()
		npc.npc_id = npc_id
		npc.name = npc_id
		add_child(npc)
		var spawn: Array = def.get("spawn", [0, 0, 0])
		var pos := Vector3(spawn[0], terrain.height(spawn[0], spawn[2]) + 1.0, spawn[2])
		npc.global_position = pos
		npc.build(def)

func _spawn_enemies() -> void:
	# 敌人分区:狼群(猎人区)、教团(废弃灯塔)、傀儡(烬峰)、以及深窖区
	var packs := [
		{"type": "wolf", "center": Vector3(-120, 0, 70), "radius": 18.0, "count": 4, "min_chapter": 0},
		{"type": "cultist", "center": Vector3(150, 0, -110), "radius": 22.0, "count": 4, "min_chapter": 0},
		{"type": "cultist", "center": Vector3(-50, 0, 160), "radius": 16.0, "count": 3, "min_chapter": 0},
		{"type": "golem", "center": Vector3(170, 0, 150), "radius": 24.0, "count": 2, "min_chapter": 0},
		{"type": "cultist_elite", "center": Vector3(185, 0, 165), "radius": 10.0, "count": 1, "min_chapter": 0},
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("enemy_packs")
	for pack: Dictionary in packs:
		for i: int in pack["count"]:
			var enemy := preload("res://scripts/entities/enemy.gd").new()
			enemy.enemy_type = pack["type"]
			var angle := rng.randf_range(0, TAU)
			var dist := rng.randf_range(2.0, float(pack["radius"]))
			var x: float = pack["center"].x + cos(angle) * dist
			var z: float = pack["center"].z + sin(angle) * dist
			add_child(enemy)
			enemy.global_position = Vector3(x, terrain.height(x, z) + 1.2, z)
			enemy.build()
	# 终章 Boss:灰烬主教(烬峰之巅)
	var boss := preload("res://scripts/entities/enemy.gd").new()
	boss.enemy_type = "boss_bishop"
	boss.is_boss = true
	add_child(boss)
	boss.global_position = Vector3(196.0, terrain.height(196.0, 196.0) + 1.5, 196.0)
	boss.build()

func _spawn_pickups() -> void:
	# 采集点:雪绒草 x 8、寒铁矿 x 5、木柴堆 x 6,散布在世界
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("pickups")
	var specs := [
		{"item": "snowgrass", "count": 8, "label": "雪绒草"},
		{"item": "cold_iron_ore", "count": 5, "label": "寒铁矿"},
		{"item": "firewood", "count": 6, "label": "木柴"},
	]
	for spec: Dictionary in specs:
		for i: int in spec["count"]:
			var x := rng.randf_range(-200.0, 200.0)
			var z := rng.randf_range(-200.0, 200.0)
			if Vector2(x, z).length() < 45.0:
				continue  # 不刷在镇里
			var pickup := preload("res://scripts/entities/pickup.gd").new()
			pickup.item_id = spec["item"]
			pickup.label = spec["label"]
			add_child(pickup)
			pickup.global_position = Vector3(x, terrain.height(x, z) + 0.6, z)
			_spawned_pickups.append(pickup)

func _setup_location_triggers() -> void:
	var locations := [
		{"id": "town", "pos": Vector3(0, 0, 0), "radius": 30.0, "name": "炉边镇"},
		{"id": "lighthouse", "pos": Vector3(0, 0, -56), "radius": 14.0, "name": "余烬灯塔"},
		{"id": "hunters_hut", "pos": Vector3(-140, 0, 90), "radius": 16.0, "name": "灰枝的猎屋"},
		{"id": "ruin_lighthouse", "pos": Vector3(160, 0, -120), "radius": 18.0, "name": "废弃的二号灯塔"},
		{"id": "crypt", "pos": Vector3(-50, 0, 160), "radius": 18.0, "name": "古窖遗迹"},
		{"id": "peak", "pos": Vector3(200, 0, 200), "radius": 25.0, "name": "烬峰之巅"},
		{"id": "shrine", "pos": Vector3(-180, 0, -150), "radius": 14.0, "name": "雪中神龛"},
	]
	for loc: Dictionary in locations:
		var area := Area3D.new()
		area.name = "Loc_" + loc["id"]
		var shape := CollisionShape3D.new()
		var sphere := SphereShape3D.new()
		sphere.radius = loc["radius"]
		shape.shape = sphere
		area.add_child(shape)
		var pos: Vector3 = loc["pos"]
		area.global_position = Vector3(pos.x, terrain.height(pos.x, pos.z), pos.z)
		area.body_entered.connect(func(body):
			if body == player:
				EventBus.location_reached.emit(loc["id"])
				if not GameState.get_flag("visited_" + loc["id"], false):
					GameState.set_flag("visited_" + loc["id"], true)
					EventBus.notify.emit("抵达", loc["name"]))
		add_child(area)

func _build_ui() -> void:
	hud = preload("res://scripts/ui/hud.gd").new()
	add_child(hud)
	journal_ui = preload("res://scripts/ui/quest_journal.gd").new()
	add_child(journal_ui)
	inventory_ui = preload("res://scripts/ui/inventory_ui.gd").new()
	add_child(inventory_ui)
	skill_ui = preload("res://scripts/ui/skill_tree_ui.gd").new()
	add_child(skill_ui)
	shop_ui = preload("res://scripts/ui/shop_ui.gd").new()
	add_child(shop_ui)
	var touch_devices := DisplayServer.is_touchscreen_available() or OS.get_name() == "Android" or OS.get_name() == "iOS"
	touch_controls = preload("res://scripts/ui/touch_controls.gd").new()
	touch_controls.visible = touch_devices
	add_child(touch_controls)

func open_shop() -> void:
	shop_ui.open()

func _on_ending(ending_id: String) -> void:
	GameState.set_flag("ending_" + ending_id, true)

# ================================================================ 存档
func get_save_data() -> Dictionary:
	var data := {
		"time_hours": day_night.time_hours,
		"weather": weather.current_id,
		"bosses_dead": GameState.get_flag("bosses_dead", {}).duplicate(true),
		"player_pos": [player.global_position.x, player.global_position.y, player.global_position.z],
		"collected_pickups": _collected_pickup_ids(),
	}
	return data

func _collected_pickup_ids() -> Array:
	var ids: Array = []
	for p: Node3D in _spawned_pickups:
		if is_instance_valid(p) and p.get_meta("collected", false):
			ids.append(p.get_meta("pickup_uid", ""))
	return ids

func apply_save_data(data: Dictionary) -> void:
	day_night.time_hours = float(data.get("time_hours", 9.0))
	weather.force_weather(String(data.get("weather", "snow")))
	var pos: Array = data.get("player_pos", [2.0, 10.0, 6.0])
	if pos.size() == 3:
		player.global_position = Vector3(pos[0], pos[1], pos[2])
	var collected: Array = data.get("collected_pickups", [])
	for p: Node3D in _spawned_pickups:
		if is_instance_valid(p) and p.get_meta("pickup_uid", "") in collected:
			p.queue_free()
	# 已击杀的 Boss 不复活
	var bosses: Dictionary = data.get("bosses_dead", {})
	for id: String in bosses.keys():
		if bosses[id]:
			for e: Node in get_tree().get_nodes_in_group("enemies"):
				if e is CharacterBody3D and e.get_meta("boss_key", "") == id:
					e.queue_free()

func apply_quality(quality: String) -> void:
	weather.apply_quality(quality)
	day_night.apply_quality(quality)
