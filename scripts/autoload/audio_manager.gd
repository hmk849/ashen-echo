extends Node
## 音频管理器:双通道音乐淡入淡出、环境音层、SFX 池、总线音量控制。

const MUSIC := {
	"menu": "res://assets/audio/music_menu.ogg",
	"town": "res://assets/audio/music_town.ogg",
	"explore": "res://assets/audio/music_explore.ogg",
	"danger": "res://assets/audio/music_danger.ogg",
	"boss": "res://assets/audio/music_boss.ogg",
	"ending": "res://assets/audio/music_ending.ogg",
}
const SFX := {
	"ui_click": "res://assets/audio/sfx_ui_click.wav",
	"ui_open": "res://assets/audio/sfx_ui_open.wav",
	"footstep_snow": "res://assets/audio/sfx_footstep_snow.wav",
	"footstep_rock": "res://assets/audio/sfx_footstep_rock.wav",
	"sword_swing": "res://assets/audio/sfx_sword_swing.wav",
	"sword_hit": "res://assets/audio/sfx_sword_hit.wav",
	"hurt": "res://assets/audio/sfx_hurt.wav",
	"enemy_die": "res://assets/audio/sfx_enemy_die.wav",
	"pickup": "res://assets/audio/sfx_pickup.wav",
	"quest_done": "res://assets/audio/sfx_quest_done.wav",
	"levelup": "res://assets/audio/sfx_levelup.wav",
	"bell": "res://assets/audio/sfx_bell.wav",
	"drink": "res://assets/audio/sfx_drink.wav",
	"roll": "res://assets/audio/sfx_roll.wav",
	"wolf": "res://assets/audio/sfx_wolf.wav",
	"heal": "res://assets/audio/sfx_heal.wav",
	"door": "res://assets/audio/sfx_door.wav",
}
const AMBIENT := {
	"wind": "res://assets/audio/amb_wind.ogg",
	"snow": "res://assets/audio/amb_snow.ogg",
}

var _music_a: AudioStreamPlayer
var _music_b: AudioStreamPlayer
var _current_music := ""
var _ambient_player: AudioStreamPlayer
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_cache: Dictionary = {}

func _ready() -> void:
	for bus_name: String in ["Music", "Ambient", "SFX"]:
		if AudioServer.get_bus_index(bus_name) == -1:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	_music_a = AudioStreamPlayer.new()
	_music_b = AudioStreamPlayer.new()
	_music_a.bus = "Music"
	_music_b.bus = "Music"
	add_child(_music_a)
	add_child(_music_b)
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Ambient"
	add_child(_ambient_player)
	for i: int in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_sfx_pool.append(p)

func play_music(id: String, fade_time := 2.0) -> void:
	if id == _current_music or not MUSIC.has(id):
		return
	_current_music = id
	var target := _music_a.playing and _music_a.volume_db > -40.0
	var active_player := _music_b if target else _music_a
	var fading_player := _music_a if target else _music_b
	var stream: AudioStream = load(MUSIC[id])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	active_player.stream = stream
	active_player.volume_db = -40.0
	active_player.play()
	var tween := create_tween()
	tween.tween_property(active_player, "volume_db", 0.0, fade_time)
	tween.parallel().tween_property(fading_player, "volume_db", -40.0, fade_time)
	tween.tween_callback(func(): fading_player.stop())

func stop_music(fade_time := 1.0) -> void:
	_current_music = ""
	var tween := create_tween()
	tween.tween_property(_music_a, "volume_db", -40.0, fade_time)
	tween.parallel().tween_property(_music_b, "volume_db", -40.0, fade_time)
	tween.tween_callback(func():
		_music_a.stop()
		_music_b.stop())

func play_ambient(id: String) -> void:
	if not AMBIENT.has(id):
		return
	var stream: AudioStream = load(AMBIENT[id])
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	_ambient_player.stream = stream
	_ambient_player.volume_db = 0.0
	_ambient_player.play()

func set_ambient_volume_db(db: float) -> void:
	_ambient_player.volume_db = db

func stop_ambient() -> void:
	_ambient_player.stop()

func play_sfx(name_id: String, volume_db := 0.0) -> void:
	if not SFX.has(name_id):
		return
	var stream: AudioStream
	if _sfx_cache.has(name_id):
		stream = _sfx_cache[name_id]
	else:
		stream = load(SFX[name_id])
		_sfx_cache[name_id] = stream
	for p: AudioStreamPlayer in _sfx_pool:
		if not p.playing:
			p.stream = stream
			p.volume_db = volume_db
			p.play()
			return
	_sfx_pool[0].stream = stream
	_sfx_pool[0].play()

func set_bus_volume(bus_name: String, linear: float) -> void:
	var idx := AudioServer.get_bus_index(bus_name)
	if idx >= 0:
		AudioServer.set_bus_volume_db(idx, linear_to_db(clampf(linear, 0.0001, 1.0)))
		AudioServer.set_bus_mute(idx, linear <= 0.01)
