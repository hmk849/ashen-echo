class_name DayNightCycle
extends Node3D
## 昼夜循环:太阳/月亮方向光、天空渐变、雾色、环境光,随游戏时间驱动。

const DAY_LENGTH_MINUTES := 10.0   # 一昼夜 = 现实 10 分钟

var time_hours := 9.0
var sun: DirectionalLight3D
var moon: DirectionalLight3D
var world_env: WorldEnvironment
var sky_mat: ProceduralSkyMaterial
var _quality := "中"

const DAWN_TOP := Color(0.22, 0.24, 0.38)
const DAWN_BOTTOM := Color(0.85, 0.55, 0.35)
const DAY_TOP := Color(0.35, 0.48, 0.68)
const DAY_BOTTOM := Color(0.75, 0.8, 0.85)
const DUSK_TOP := Color(0.18, 0.2, 0.34)
const DUSK_BOTTOM := Color(0.9, 0.5, 0.3)
const NIGHT_TOP := Color(0.02, 0.03, 0.08)
const NIGHT_BOTTOM := Color(0.07, 0.09, 0.16)

func _ready() -> void:
	sun = DirectionalLight3D.new()
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.light_color = Color(1.0, 0.93, 0.82)
	sun.directional_shadow_max_distance = 90.0
	add_child(sun)
	moon = DirectionalLight3D.new()
	moon.light_energy = 0.18
	moon.light_color = Color(0.6, 0.7, 0.95)
	moon.shadow_enabled = false
	add_child(moon)
	# 环境
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = DAY_TOP
	sky_mat.sky_horizon_color = DAY_BOTTOM
	var sky := Sky.new()
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.0
	env.fog_enabled = true
	env.fog_light_color = Color(0.7, 0.75, 0.8)
	env.fog_density = 0.008
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 1.05
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.05
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	apply_quality(_quality)

func apply_quality(quality: String) -> void:
	_quality = quality
	match quality:
		"低":
			sun.shadow_enabled = false
			sun.directional_shadow_max_distance = 0.0
		"中":
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 60.0
			sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
		"高":
			sun.shadow_enabled = true
			sun.directional_shadow_max_distance = 110.0

func is_night() -> bool:
	return time_hours < 6.0 or time_hours >= 19.0

func _process(delta: float) -> void:
	time_hours += delta * (24.0 / (DAY_LENGTH_MINUTES * 60.0))
	if time_hours >= 24.0:
		time_hours -= 24.0
	var prev_hour := int(time_hours)
	_update_sun_moon()
	_update_sky()
	var hour := int(time_hours)
	if hour != prev_hour:
		EventBus.time_changed.emit(hour)

func _update_sun_moon() -> void:
	# 太阳高度角:6 点日出、12 点最高、18 点日落
	var day_t := clampf((time_hours - 6.0) / 12.0, 0.0, 1.0)
	var elevation := sin(day_t * PI) * 62.0
	var azimuth := (time_hours - 12.0) * 15.0
	if time_hours >= 6.0 and time_hours < 18.0:
		sun.visible = true
		moon.visible = false
		sun.rotation = Vector3(deg_to_rad(-elevation), deg_to_rad(azimuth), 0.0)
		sun.light_energy = 0.25 + sin(day_t * PI) * 0.95
		var warm := 1.0 - sin(day_t * PI)
		sun.light_color = Color(1.0, 0.95 - warm * 0.2, 0.85 - warm * 0.35)
	else:
		# 夜晚:月亮
		var night_t := 0.0
		if time_hours >= 18.0:
			night_t = (time_hours - 18.0) / 12.0
		else:
			night_t = (time_hours + 6.0) / 12.0
		sun.visible = false
		moon.visible = true
		var moon_elev := sin(night_t * PI) * 50.0
		moon.rotation = Vector3(deg_to_rad(-moon_elev), deg_to_rad(azimuth + 180.0), 0.0)
		moon.light_energy = 0.12 + sin(night_t * PI) * 0.12

func _update_sky() -> void:
	var day_t := clampf((time_hours - 6.0) / 12.0, 0.0, 1.0)
	var strength := sin(day_t * PI)
	var top: Color
	var bottom: Color
	if time_hours >= 5.0 and time_hours < 8.0:
		top = DAWN_TOP
		bottom = DAWN_BOTTOM
	elif time_hours >= 8.0 and time_hours < 17.0:
		top = DAY_TOP.lerp(Color(0.4, 0.5, 0.7), 1.0 - strength)
		bottom = DAY_BOTTOM
	elif time_hours >= 17.0 and time_hours < 19.5:
		top = DUSK_TOP
		bottom = DUSK_BOTTOM
	else:
		top = NIGHT_TOP
		bottom = NIGHT_BOTTOM
	sky_mat.sky_top_color = top
	sky_mat.sky_horizon_color = bottom
	var env := world_env.environment
	env.fog_light_color = bottom.lerp(Color(0.6, 0.65, 0.72), 0.4)
	env.ambient_light_energy = 0.45 + strength * 0.65
