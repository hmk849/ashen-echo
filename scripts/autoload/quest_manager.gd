extends Node
## 任务系统:主线 / 支线 / 隐藏任务,分步骤推进,事件驱动。

var active: Dictionary = {}      # quest_id -> {"step": int, "progress": int}
var completed: Array[String] = []
var failed: Array[String] = []

var _eval_timer := 0.0

func _ready() -> void:
	EventBus.enemy_killed.connect(_on_enemy_killed)
	EventBus.npc_talked.connect(_on_npc_talked)
	EventBus.location_reached.connect(_on_location_reached)
	EventBus.item_collected.connect(_on_item_collected)
	EventBus.quest_advanced.connect(func(_q, _s): _check_active_quests())
	GameState.inventory_changed.connect(_check_active_quests)

func _process(delta: float) -> void:
	_eval_timer -= delta
	if _eval_timer <= 0.0:
		_eval_timer = 0.5
		_check_active_quests()

func start_quest(quest_id: String) -> void:
	if active.has(quest_id) or quest_id in completed:
		return
	var quest := GameData.get_quest(quest_id)
	if quest.is_empty():
		push_error("QuestManager: 未知任务 " + quest_id)
		return
	active[quest_id] = {"step": 0, "progress": 0}
	EventBus.quest_started.emit(quest_id)
	var title: String = quest.get("title", quest_id)
	EventBus.notify.emit("新任务", title)
	_check_active_quests()

func is_active(quest_id: String) -> bool:
	return active.has(quest_id)

func is_completed(quest_id: String) -> bool:
	return quest_id in completed

func current_step(quest_id: String) -> Dictionary:
	var q: Dictionary = active.get(quest_id, {})
	var steps: Array = GameData.get_quest(quest_id).get("steps", [])
	var idx := int(q.get("step", 0))
	if idx < steps.size():
		return steps[idx]
	return {}

func _check_active_quests() -> void:
	for quest_id: String in active.keys():
		_evaluate_quest(quest_id)

func _evaluate_quest(quest_id: String) -> void:
	var state: Dictionary = active[quest_id]
	var steps: Array = GameData.get_quest(quest_id).get("steps", [])
	while state["step"] < steps.size():
		var step: Dictionary = steps[state["step"]]
		if _step_done(quest_id, step, state):
			state["step"] = int(state["step"]) + 1
			state["progress"] = 0
			EventBus.quest_advanced.emit(quest_id, int(state["step"]))
			if state["step"] >= steps.size():
				_complete_quest(quest_id)
				return
		else:
			break

func _step_done(_quest_id: String, step: Dictionary, state: Dictionary) -> bool:
	var type: String = step.get("type", "")
	var target: String = step.get("target", "")
	match type:
		"talk":
			return _talked_to(target)
		"kill":
			return int(state.get("progress", 0)) >= int(step.get("count", 1))
		"collect":
			return GameState.has_item(target, int(step.get("count", 1)))
		"reach":
			return GameState.get_flag("reached_" + target, false)
		"flag":
			return GameState.get_flag(step.get("flag", ""), false)
		"choice":
			return GameState.get_flag(step.get("flag", ""), false)
	return true

func _talked_to(npc_id: String) -> bool:
	return GameState.get_flag("talked_" + npc_id, false)

func _on_enemy_killed(enemy_type: String, _enemy_id: String) -> void:
	for quest_id: String in active.keys():
		var state: Dictionary = active[quest_id]
		var step := current_step(quest_id)
		if step.get("type", "") == "kill" and step.get("target", "") == enemy_type:
			state["progress"] = int(state.get("progress", 0)) + 1
			EventBus.notify.emit("任务进度", "%s (%d/%d)" % [GameData.get_quest(quest_id).get("title", quest_id), state["progress"], int(step.get("count", 1))])
	_evaluate_quest_wrapper()

func _evaluate_quest_wrapper() -> void:
	_check_active_quests()

func _on_npc_talked(npc_id: String, _node_id: String) -> void:
	for quest_id: String in active.keys():
		var step := current_step(quest_id)
		if step.get("type", "") == "talk" and step.get("target", "") == npc_id:
			GameState.set_flag("talked_" + npc_id, true)
	_check_active_quests()

func _on_location_reached(location_id: String) -> void:
	GameState.set_flag("reached_" + location_id, true)
	_check_active_quests()

func _on_item_collected(item_id: String, _count: int) -> void:
	for quest_id: String in active.keys():
		var step := current_step(quest_id)
		if step.get("type", "") == "collect" and step.get("target", "") == item_id:
			pass  # collect 在 _step_done 里实时检查背包
	_check_active_quests()

func _complete_quest(quest_id: String) -> void:
	var quest := GameData.get_quest(quest_id)
	var rewards: Dictionary = quest.get("rewards", {})
	GameState.add_xp(int(rewards.get("xp", 0)))
	GameState.gold += int(rewards.get("gold", 0))
	for item: String in rewards.get("items", []):
		GameState.add_item(item, 1)
	active.erase(quest_id)
	completed.append(quest_id)
	EventBus.quest_completed.emit(quest_id)
	EventBus.notify.emit("任务完成", quest.get("title", quest_id))
	SaveManager.autosave()
	var next_id: String = quest.get("next", "")
	if not next_id.is_empty():
		start_quest(next_id)

func grant_kill_progress(enemy_type: String) -> void:
	EventBus.enemy_killed.emit(enemy_type, enemy_type)

# ---------------------------------------------------------------- 存档序列化
func to_dict() -> Dictionary:
	var out := {}
	for quest_id: String in active:
		out[quest_id] = active[quest_id]
	return {"active": out, "completed": completed}

func from_dict(data: Dictionary) -> void:
	active = {}
	completed = []
	for quest_id: String in data.get("active", {}).keys():
		active[quest_id] = data["active"][quest_id]
	for quest_id: String in data.get("completed", []):
		completed.append(quest_id)
