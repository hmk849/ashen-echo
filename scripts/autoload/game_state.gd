extends Node
## 玩家全局状态:等级、经验、生命、体力、背包、装备、技能、金币、剧情旗标、好感度。

signal inventory_changed

const SKILL_TREE := {
	"combat": {
		"name": "战斗",
		"skills": {
			"c1": {"name": "锋刃 I", "desc": "攻击伤害 +15%", "cost": 1, "requires": ""},
			"c2": {"name": "锋刃 II", "desc": "攻击伤害 +20%", "cost": 1, "requires": "c1"},
			"c3": {"name": "铁壁", "desc": "格挡伤害减免 +20%", "cost": 1, "requires": ""},
			"c4": {"name": "顺势斩", "desc": "完美翻滚后 3 秒内伤害 +30%", "cost": 2, "requires": "c1"},
		}
	},
	"survival": {
		"name": "生存",
		"skills": {
			"s1": {"name": "强健体魄 I", "desc": "生命上限 +20", "cost": 1, "requires": ""},
			"s2": {"name": "强健体魄 II", "desc": "生命上限 +30", "cost": 1, "requires": "s1"},
			"s3": {"name": "持久", "desc": "体力消耗 -25%", "cost": 1, "requires": ""},
			"s4": {"name": "雪原行者", "desc": "暴雪中不再减速", "cost": 2, "requires": "s3"},
		}
	},
	"ember": {
		"name": "守烬",
		"skills": {
			"e1": {"name": "余烬之温", "desc": "篝火回复速度 +50%", "cost": 1, "requires": ""},
			"e2": {"name": "烬火复苏", "desc": "解锁技能:消耗 40 体力,恢复 35 生命", "cost": 2, "requires": "e1"},
			"e3": {"name": "烬火护体", "desc": "受致命伤害时免死并回复 30% 生命(每场战斗一次)", "cost": 2, "requires": "e1"},
			"e4": {"name": "龙血共鸣", "desc": "最终章选择「薪传」时获得额外对话与隐藏内容", "cost": 3, "requires": "e2"},
		}
	},
}

var player_name := "洛尘"
var level := 1
var xp := 0
var hp := 100.0
var max_hp := 100.0
var stamina := 100.0
var max_stamina := 100.0
var gold := 30
var skill_points := 0
var learned_skills: Array[String] = []
var inventory: Dictionary = {}   # item_id -> count
var equipped_weapon := "training_sword"
var equipped_armor := "cloth_armor"
var flags: Dictionary = {}       # 剧情旗标
var affinity: Dictionary = {}    # npc_id -> 好感度
var play_seconds := 0
var ending_id := ""
var last_campfire_pos := Vector3.ZERO

func xp_to_next() -> int:
	return 80 + (level - 1) * 60

func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	xp += amount
	EventBus.xp_gained.emit(amount)
	while xp >= xp_to_next():
		xp -= xp_to_next()
		level += 1
		skill_points += 1
		max_hp += 10
		hp = max_hp
		EventBus.level_up.emit(level)
		EventBus.notify.emit("升级", "等级提升到 %d,获得 1 点技能点。" % level)

func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)

func has_skill(id: String) -> bool:
	return id in learned_skills

func learn_skill(id: String) -> bool:
	var def := _find_skill(id)
	if def.is_empty() or has_skill(id) or skill_points < int(def.get("cost", 1)):
		return false
	var req: String = def.get("requires", "")
	if not req.is_empty() and not has_skill(req):
		return false
	skill_points -= int(def.get("cost", 1))
	learned_skills.append(id)
	if id == "s1":
		max_hp += 20
	if id == "s2":
		max_hp += 30
	return true

func _find_skill(id: String) -> Dictionary:
	for branch: String in SKILL_TREE:
		var skills: Dictionary = SKILL_TREE[branch]["skills"]
		if skills.has(id):
			var d: Dictionary = (skills[id] as Dictionary).duplicate()
			d["branch"] = branch
			return d
	return {}

func add_item(id: String, count: int = 1) -> void:
	if id.is_empty():
		return
	inventory[id] = int(inventory.get(id, 0)) + count
	inventory_changed.emit()
	EventBus.item_collected.emit(id, count)

func remove_item(id: String, count: int = 1) -> bool:
	var have := int(inventory.get(id, 0))
	if have < count:
		return false
	if have == count:
		inventory.erase(id)
	else:
		inventory[id] = have - count
	inventory_changed.emit()
	return true

func has_item(id: String, count: int = 1) -> bool:
	return int(inventory.get(id, 0)) >= count

func set_flag(key: String, value: Variant = true) -> void:
	flags[key] = value

func get_flag(key: String, default_value: Variant = null) -> Variant:
	return flags.get(key, default_value)

func add_affinity(npc_id: String, amount: int) -> void:
	affinity[npc_id] = int(affinity.get(npc_id, 0)) + amount

# ---------------------------------------------------------------- 数值计算
func attack_power() -> float:
	var weapon := GameData.get_item(equipped_weapon)
	var base := float(weapon.get("attack", 8))
	var mult := 1.0
	if has_skill("c1"):
		mult += 0.15
	if has_skill("c2"):
		mult += 0.2
	return base * mult

func defense_power() -> float:
	var armor := GameData.get_item(equipped_armor)
	return float(armor.get("defense", 0))

func stamina_cost_mult() -> float:
	return 1.0 if not has_skill("s3") else 0.75

func consume_stamina(amount: float) -> bool:
	var cost := amount * stamina_cost_mult()
	if stamina < cost:
		return false
	stamina -= cost
	return true

func to_dict() -> Dictionary:
	return {
		"player_name": player_name, "level": level, "xp": xp,
		"hp": hp, "max_hp": max_hp, "gold": gold,
		"skill_points": skill_points, "learned_skills": learned_skills,
		"inventory": inventory, "equipped_weapon": equipped_weapon,
		"equipped_armor": equipped_armor, "flags": flags,
		"affinity": affinity, "play_seconds": play_seconds,
		"ending_id": ending_id,
		"last_campfire_pos": [last_campfire_pos.x, last_campfire_pos.y, last_campfire_pos.z],
	}

func from_dict(data: Dictionary) -> void:
	player_name = data.get("player_name", "洛尘")
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	hp = float(data.get("hp", 100))
	max_hp = float(data.get("max_hp", 100))
	gold = int(data.get("gold", 30))
	skill_points = int(data.get("skill_points", 0))
	learned_skills.clear()
	for s: String in data.get("learned_skills", []):
		learned_skills.append(s)
	inventory = data.get("inventory", {})
	equipped_weapon = data.get("equipped_weapon", "training_sword")
	equipped_armor = data.get("equipped_armor", "cloth_armor")
	flags = data.get("flags", {})
	affinity = data.get("affinity", {})
	play_seconds = int(data.get("play_seconds", 0))
	ending_id = data.get("ending_id", "")
	var pos: Array = data.get("last_campfire_pos", [0, 0, 0])
	if pos.size() == 3:
		last_campfire_pos = Vector3(pos[0], pos[1], pos[2])

func reset_for_new_game() -> void:
	player_name = "洛尘"
	level = 1
	xp = 0
	hp = 100.0
	max_hp = 100.0
	stamina = 100.0
	max_stamina = 100.0
	gold = 30
	skill_points = 0
	learned_skills = []
	inventory = {"training_sword": 1, "cloth_armor": 1, "herb_paste": 2, "roasted_mushroom": 2}
	equipped_weapon = "training_sword"
	equipped_armor = "cloth_armor"
	flags = {}
	affinity = {}
	play_seconds = 0
	ending_id = ""
	last_campfire_pos = Vector3.ZERO
