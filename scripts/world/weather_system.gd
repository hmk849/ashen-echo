class_name WeatherSystem
extends Node3D
## 天气系统:晴 / 降雪 / 浓雾 / 暴雪,带过渡;GPU 粒子雪、雾密度、风声联动。

var current_id := "snow"
var _next_change := 60.0
var _snow_particles: GPUParticles3D
var _blizzard_particles: GPUParticles3D
var _quality := "中"
var _target_fog := 0.008
var _rng := RandomNumberGenerator.new()

const WEATHERS := {
	"clear": {"fog": 0.004, "particles": 0.0, "name": "晴朗"},
	"snow": {"fog": 0.010, "particles": 300.0, "name": "降雪"},
	"fog": {"fog": 0.030, "particles": 80.0, "name": "浓雾"},
	"blizzard": {"fog": 0.045, "particles": 900.0, "name": "暴雪"},
}

func _ready() -> void:
	_rng.seed = 777
	_snow_particles = _make_snow("Snow", 300, 0.35, Vector3(6, -4, 2))
	_blizzard_particles = _make_snow("Blizzard", 900, 1.6, Vector3(16, -6, 4))
	add_child(_snow_particles)
	add_child(_blizzard_particles)
	force_weather(current_id)

func _make_snow(pname: String, amount: int, size: float, vel: Vector3) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.name = pname
	p.amount = amount
	p.lifetime = 7.0
	p.visibility_aabb = AABB(Vector3(-40, -25, -40), Vector3(80, 50, 80))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0.2, -1, 0.1)
	mat.spread = 12.0
	mat.initial_velocity_min = vel.length() * 0.8
	mat.initial_velocity_max = vel.length() * 1.2
	mat.gravity = Vector3(vel.x, -3.5, vel.z)
	mat.scale_min = 0.4
	mat.scale_max = 1.0
	p.process_material = mat
	var quad := QuadMesh.new()
	quad.size = Vector2(size * 0.12, size * 0.12)
	var tex: Texture2D = load("res://assets/textures/particle_snow.png")
	if tex != null:
		var umat := StandardMaterial3D.new()
		umat.albedo_texture = tex
		umat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		umat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		umat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		quad.material = umat
	p.draw_pass_1 = quad
	p.local_coords = false
	return p

func apply_quality(quality: String) -> void:
	_quality = quality
	match quality:
		"低":
			_snow_particles.amount = 120
			_blizzard_particles.amount = 300
		"中":
			_snow_particles.amount = 300
			_blizzard_particles.amount = 900
		"高":
			_snow_particles.amount = 500
			_blizzard_particles.amount = 1600

func force_weather(id: String) -> void:
	if not WEATHERS.has(id):
		return
	current_id = id
	_apply_current()

func _apply_current() -> void:
	var conf: Dictionary = WEATHERS[current_id]
	_target_fog = float(conf["fog"])
	_snow_particles.emitting = current_id == "snow" or current_id == "blizzard"
	_blizzard_particles.emitting = current_id == "blizzard"
	_snow_particles.visible = _snow_particles.emitting
	_blizzard_particles.visible = _blizzard_particles.emitting
	match current_id:
		"clear":
			AudioManager.set_ambient_volume_db(-16.0)
		"snow":
			AudioManager.set_ambient_volume_db(-8.0)
		"fog":
			AudioManager.set_ambient_volume_db(-10.0)
		"blizzard":
			AudioManager.set_ambient_volume_db(-3.0)
	EventBus.weather_changed.emit(current_id)

func _process(delta: float) -> void:
	# 粒子跟随相机
	var cam := get_viewport().get_camera_3d()
	if cam != null:
		var cp := cam.global_position
		_snow_particles.global_position = Vector3(cp.x, cp.y + 18.0, cp.z)
		_blizzard_particles.global_position = Vector3(cp.x, cp.y + 18.0, cp.z)
	# 雾密度平滑过渡
	var world := get_parent()
	if world is Node3D:
		var dn: Node = world.get_node_or_null("DayNight")
		if dn != null and dn.world_env is WorldEnvironment:
			var env: Environment = dn.world_env.environment
			env.fog_density = lerpf(env.fog_density, _target_fog, delta * 0.4)
	# 天气随机演化
	_next_change -= delta
	if _next_change <= 0.0:
		_next_change = _rng.randf_range(90.0, 180.0)
		var roll := _rng.randf()
		var new_id := current_id
		if current_id == "clear":
			new_id = "snow" if roll < 0.6 else "fog"
		elif current_id == "snow":
			new_id = "clear" if roll < 0.35 else ("blizzard" if roll < 0.55 else "fog")
		elif current_id == "fog":
			new_id = "snow" if roll < 0.5 else "clear"
		elif current_id == "blizzard":
			new_id = "snow" if roll < 0.7 else "fog"
		if new_id != current_id:
			current_id = new_id
			_apply_current()
			EventBus.notify.emit("天气", "天气转为:%s" % WEATHERS[current_id]["name"])
