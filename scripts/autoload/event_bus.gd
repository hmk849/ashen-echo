extends Node
## 全局事件总线:所有跨系统通信都走这里,保持模块解耦。
signal enemy_killed(enemy_type: String, enemy_id: String)
signal item_collected(item_id: String, count: int)
signal npc_talked(npc_id: String, node_id: String)
signal location_reached(location_id: String)
signal quest_started(quest_id: String)
signal quest_advanced(quest_id: String, step_index: int)
signal quest_completed(quest_id: String)
signal xp_gained(amount: int)
signal level_up(new_level: int)
signal player_damaged(amount: float)
signal player_died
signal player_respawned
signal time_changed(hour: int)
signal weather_changed(weather_id: String)
signal cutscene_started
signal cutscene_ended
signal ending_reached(ending_id: String)
signal notify(title: String, body: String)
signal save_requested(slot: int)
signal game_loaded
