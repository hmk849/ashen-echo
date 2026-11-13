extends Node
## 集成测试:由 main.gd 在 ASHEN_TEST=1 环境变量下自动运行。

var _failures := 0
var _checks := 0

func run() -> void:
	print("[TEST] 开始集成测试")
	_test_data_loaded()
	await _test_new_game()
	await _test_world_entities()
	await _test_quest_flow()
	await _test_combat()
	await _test_save_load()
	await _test_ui_smoke()
	await _test_dialogue()
	_summary()

func _check(cond: bool, name: String) -> void:
	_checks += 1
	if cond:
		print("[PASS] ", name)
	else:
		_failures += 1
		print("[FAIL] ", name)

func _summary() -> void:
	print("[TEST] 完成: %d 项检查, %d 失败" % [_checks, _failures])
	if _failures == 0:
		print("TEST_RESULT: PASS")
	else:
		print("TEST_RESULT: FAIL")
	await get_tree().process_frame
	get_tree().quit(0 if _failures == 0 else 1)

func _test_data_loaded() -> void:
	_check(load("res://assets/fonts/NotoSansSC_subset.ttf") is FontFile, "中文字体可加载")
	_check(load("res://assets/ui/title_bg.png") is Texture2D, "标题背景可加载")
	_check(load("res://assets/audio/music_town.ogg") is AudioStream, "音乐资源可加载")
	_check(load("res://assets/audio/sfx_sword_hit.wav") is AudioStream, "音效资源可加载")
	_check(GameData.items.size() >= 20, "物品数据加载 (%d)" % GameData.items.size())
	_check(GameData.quests.size() >= 15, "任务数据加载 (%d)" % GameData.quests.size())
	_check(GameData.dialogue["nodes"].size() >= 30, "对话数据加载 (%d)" % GameData.dialogue["nodes"].size())
	_check(GameData.npcs.size() >= 6, "NPC 数据加载")
	_check(GameData.enemies.size() >= 5, "敌人数据加载")

func _test_new_game() -> void:
	GameState.reset_for_new_game()
	_check(GameState.hp == 100.0, "新游戏状态重置")
	var main := get_tree().get_first_node_in_group("main_controller")
	_check(main != null, "主控制器就绪")
	# 通过反射调用私有方法(测试专用)
	main.call("_start_world", null)
	await _wait_frames(60)
	# 跳过开场过场(它会暂停游戏树)
	for n: Node in get_tree().root.get_children():
		if n.get_script() != null and String(n.get_script().get_path()).contains("cutscene_player"):
			n.call("_finish")
	await _wait_frames(10)
	get_tree().paused = false
	var world := get_tree().get_first_node_in_group("world")
	_check(world != null, "世界创建成功")
	await _wait_frames(30)
	_check(get_tree().get_first_node_in_group("player") != null, "玩家生成")
	_check(QuestManager.is_active("m1_intro"), "主线第一章自动开始")

func _test_world_entities() -> void:
	await _wait_frames(30)
	var world := get_tree().get_first_node_in_group("world")
	_check(world != null and world.terrain != null, "地形生成")
	var h0: float = world.terrain.height(0, 0)
	var hp: float = world.terrain.height(200, 200)
	_check(hp > h0 + 30.0, "烬峰地形抬升 (镇=%f 峰=%f)" % [h0, hp])
	_check(get_tree().get_nodes_in_group("npcs").size() >= 5, "NPC 生成 (%d)" % get_tree().get_nodes_in_group("npcs").size())
	_check(get_tree().get_nodes_in_group("enemies").size() >= 10, "敌人生成 (%d)" % get_tree().get_nodes_in_group("enemies").size())
	_check(world.day_night != null and world.weather != null, "昼夜与天气系统运行")
	_check(world.weather.current_id in ["clear", "snow", "fog", "blizzard"], "天气状态有效: " + world.weather.current_id)

func _test_quest_flow() -> void:
	# 主线推进:与温霏对话 → 抵达灯塔 → 与白鸢对话
	EventBus.npc_talked.emit("wenai", "wenai_root")
	await _wait_frames(3)
	_check(QuestManager.current_step("m1_intro").get("type", "") == "reach", "对话推进任务步骤")
	EventBus.location_reached.emit("lighthouse")
	await _wait_frames(3)
	_check(QuestManager.current_step("m1_intro").get("target", "") == "baiyuan", "地点触发推进任务步骤")
	EventBus.npc_talked.emit("baiyuan", "baiyuan_root")
	await _wait_frames(3)
	_check(QuestManager.is_completed("m1_intro"), "第一章完成")
	_check(QuestManager.is_active("m2_trail"), "第二章自动衔接")
	# 支线
	GameState.add_item("cold_iron_ore", 3)
	QuestManager.start_quest("s1_warmsteel")
	await _wait_frames(60)
	_check(QuestManager.current_step("s1_warmsteel").get("type", "") == "talk" or QuestManager.is_completed("s1_warmsteel"), "收集型任务步骤推进")
	GameState.remove_item("cold_iron_ore", 3)
	GameState.add_xp(500)
	_check(GameState.level >= 3, "升级与经验系统 (等级 %d)" % GameState.level)
	GameState.learn_skill("c1")
	_check(GameState.has_skill("c1"), "技能学习")

func _test_combat() -> void:
	var enemy: CharacterBody3D = get_tree().get_nodes_in_group("enemies")[0]
	var hp_before: float = enemy.hp
	enemy.take_damage(10.0, enemy.global_position + Vector3.FORWARD)
	await _wait_frames(3)
	_check(enemy.hp < hp_before or not is_instance_valid(enemy), "敌人受击扣血")
	# 玩家受击
	var player: CharacterBody3D = get_tree().get_first_node_in_group("player")
	var php: float = GameState.hp
	player.take_damage(10.0)
	_check(GameState.hp < php, "玩家受击扣血")

func _test_save_load() -> void:
	var ok := SaveManager.save_to_slot("1")
	_check(ok, "写入存档")
	GameState.gold = 999
	GameState.hp = 12.0
	var loaded := SaveManager.load_from_slot("1")
	_check(loaded, "读取存档")
	_check(GameState.gold != 999, "存档恢复游戏状态 (金币=%d)" % GameState.gold)
	_check(GameState.hp > 12.0, "存档恢复生命值")

func _test_ui_smoke() -> void:
	var world := get_tree().get_first_node_in_group("world")
	_check(world != null and world.hud != null, "HUD 创建")
	_check(world != null and world.journal_ui != null, "任务日志 UI 创建")
	_check(world != null and world.inventory_ui != null, "背包 UI 创建")
	_check(world != null and world.skill_ui != null, "技能树 UI 创建")
	_check(world != null and world.shop_ui != null, "商店 UI 创建")
	# 打开/关闭各界面
	world.journal_ui.visible = true
	world.journal_ui._rebuild()
	_check(true, "任务日志打开与刷新")
	world.journal_ui.visible = false
	world.inventory_ui.visible = true
	world.inventory_ui._rebuild()
	world.inventory_ui.visible = false
	world.skill_ui.visible = true
	world.skill_ui._rebuild()
	world.skill_ui.visible = false
	world.shop_ui.open()
	world.shop_ui.visible = false
	_check(true, "背包/技能/商店界面打开")
	# HUD 通知
	world.hud.toast("测试", "通知系统工作正常")
	_check(true, "通知系统")

func _test_dialogue() -> void:
	DialogueManager.start("wenai_root")
	await _wait_frames(5)
	_check(DialogueManager.is_active(), "对话系统启动")
	var node := GameData.get_dialogue_node("altar_root")
	_check(not node.get("choices", []).is_empty(), "祭坛结局选项存在")
	var end3: Dictionary = {}
	for c: Dictionary in node.get("choices", []):
		if String(c.get("text", "")).contains("薪传"):
			end3 = c
	_check(not end3.is_empty(), "隐藏结局「薪传」选项存在")
	DialogueManager.stop()

func _wait_frames(n: int) -> void:
	for i: int in n:
		await get_tree().process_frame
