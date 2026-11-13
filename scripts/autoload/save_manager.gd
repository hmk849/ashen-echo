extends Node
## 存档系统:3 个手动槽位 + 1 个自动存档,JSON 序列化到 user://。

const SAVE_DIR := "user://saves"
const SLOTS := ["auto", "1", "2", "3"]

var _world_ref: Node = null   # 由 World 在启动时注册

func register_world(world: Node) -> void:
	_world_ref = world

func _slot_path(slot: String) -> String:
	return "%s/slot_%s.json" % [SAVE_DIR, slot]

func save_to_slot(slot: String) -> bool:
	if _world_ref == null:
		return false
	var dir := DirAccess.open("user://")
	if dir != null and not dir.dir_exists("saves"):
		dir.make_dir("saves")
	var data := {
		"version": 1,
		"timestamp": Time.get_datetime_string_from_system(true),
		"play_seconds": GameState.play_seconds,
		"game": GameState.to_dict(),
		"quests": QuestManager.to_dict(),
		"world": _world_ref.get_save_data(),
	}
	var file := FileAccess.open(_slot_path(slot), FileAccess.WRITE)
	if file == null:
		push_error("SaveManager: 无法写入存档 " + slot)
		return false
	file.store_string(JSON.stringify(data, "\t"))
	file.close()
	EventBus.notify.emit("已保存", "进度已保存到槽位 %s。" % ("自动" if slot == "auto" else slot))
	return true

func load_from_slot(slot: String) -> bool:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var parsed = JSON.parse_string(file.get_file_as_string(path))
	file.close()
	if not (parsed is Dictionary):
		return false
	GameState.from_dict(parsed.get("game", {}))
	QuestManager.from_dict(parsed.get("quests", {}))
	if _world_ref:
		_world_ref.apply_save_data(parsed.get("world", {}))
	EventBus.game_loaded.emit()
	return true

func slot_info(slot: String) -> Dictionary:
	var path := _slot_path(slot)
	if not FileAccess.file_exists(path):
		return {}
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var parsed = JSON.parse_string(file.get_file_as_string(path))
	file.close()
	if not (parsed is Dictionary):
		return {}
	return {
		"timestamp": parsed.get("timestamp", ""),
		"level": int(parsed.get("game", {}).get("level", 1)),
		"play_seconds": int(parsed.get("play_seconds", 0)),
		"chapter": _current_chapter(parsed),
	}

func _current_chapter(parsed: Dictionary) -> String:
	var quests: Dictionary = parsed.get("quests", {})
	var completed: Array = quests.get("completed", [])
	for chapter: String in [
		"m8_final_choice", "m7_peak", "m6_ballad", "m5_crypt",
		"m4_shadow", "m3_whisper", "m2_trail", "m1_intro"]:
		if chapter in completed:
			return GameData.get_quest(chapter).get("title", chapter)
	var active: Dictionary = quests.get("active", {})
	if not active.is_empty():
		var first: String = active.keys()[0]
		return GameData.get_quest(first).get("title", first)
	return "序章"

func autosave() -> void:
	save_to_slot("auto")

func format_play_time(seconds: int) -> String:
	var h := seconds / 3600
	var m := (seconds % 3600) / 60
	return "%d小时%02d分" % [h, m]
