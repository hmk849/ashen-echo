class_name TerrainGenerator
extends Node3D
## 程序化地形:基于高度函数的分块网格 + 顶点颜色(雪/岩/草)+ 三角网格碰撞。

const CHUNK_SIZE := 64.0
const CHUNK_SUBDIV := 24
const GRID := 8   # 8x8 块 = 512m x 512m 世界

var _noise := FastNoiseLite.new()
var _mountain_noise := FastNoiseLite.new()

func _ready() -> void:
	_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_noise.seed = 20261113
	_noise.frequency = 0.006
	_noise.fractal_octaves = 4
	_noise.fractal_gain = 0.5
	_mountain_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX
	_mountain_noise.seed = 99
	_mountain_noise.frequency = 0.004
	_mountain_noise.fractal_octaves = 3
	_build_chunks()

func height(x: float, z: float) -> float:
	var base := _noise.get_noise_2d(x, z) * 7.0
	var detail := _noise.get_noise_2d(x * 4.0, z * 4.0) * 1.2
	# 烬峰:东南角大山
	var peak := Vector2(200.0, 200.0)
	var d_peak := Vector2(x, z).distance_to(peak)
	var mountain := maxf(0.0, 1.0 - d_peak / 130.0)
	mountain = pow(mountain, 1.6) * 52.0
	mountain += _mountain_noise.get_noise_2d(x, z) * mountain * 0.25
	# 北部丘陵
	var hills := maxf(0.0, 1.0 - Vector2(x, z).distance_to(Vector2(-120, -120)) / 110.0) * 14.0
	var h := base + detail + mountain + hills
	# 镇区与灯塔附近压平
	h = _flatten(h, Vector2(x, z), Vector2(0, 0), 42.0, 3.5)
	h = _flatten(h, Vector2(x, z), Vector2(0, -56), 18.0, 4.0)
	h = _flatten(h, Vector2(x, z), Vector2(-140, 90), 20.0, 5.0)
	h = _flatten(h, Vector2(x, z), Vector2(-50, 160), 22.0, 5.0)
	h = _flatten(h, Vector2(x, z), Vector2(160, -120), 20.0, 5.0)
	return h

func _flatten(h: float, pos: Vector2, center: Vector2, radius: float, target: float) -> float:
	var d := pos.distance_to(center)
	if d > radius * 1.6:
		return h
	var t := clampf((d - radius * 0.55) / (radius * 1.05), 0.0, 1.0)
	return lerpf(target, h, smoothstep(0.0, 1.0, t))

func _build_chunks() -> void:
	var half := float(GRID) / 2.0
	for cx: int in GRID:
		for cz: int in GRID:
			var chunk := _build_chunk(cx - half, cz - half)
			chunk.name = "Chunk_%d_%d" % [cx, cz]
			add_child(chunk)

func _build_chunk(cx: float, cz: float) -> Node3D:
	var root := Node3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	plane.subdivide_width = CHUNK_SUBDIV
	plane.subdivide_depth = CHUNK_SUBDIV
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, plane.surface_get_arrays(0))
	var mdt := MeshDataTool.new()
	mdt.create_from_surface(arr_mesh, 0)
	var origin := Vector3(cx * CHUNK_SIZE, 0.0, cz * CHUNK_SIZE)
	var vcount := mdt.get_vertex_count()
	for i: int in vcount:
		var v: Vector3 = mdt.get_vertex(i)
		var world_pos := origin + v
		var h := height(world_pos.x, world_pos.z)
		mdt.set_vertex(i, Vector3(v.x, h - origin.y, v.z))
	# 法线:用高度场差分近似
	for i: int in vcount:
		var v: Vector3 = mdt.get_vertex(i)
		var world_pos := origin + v
		var hl := height(world_pos.x - 1.5, world_pos.z)
		var hr := height(world_pos.x + 1.5, world_pos.z)
		var hd := height(world_pos.x, world_pos.z - 1.5)
		var hu := height(world_pos.x, world_pos.z + 1.5)
		var normal := Vector3(hl - hr, 3.0, hd - hu).normalized()
		mdt.set_vertex_normal(i, normal)
	# 顶点颜色:按高度与坡度混合雪/岩/枯草
	for i: int in vcount:
		var v: Vector3 = mdt.get_vertex(i)
		var world_pos := origin + v
		var n: Vector3 = mdt.get_vertex_normal(i)
		var slope := 1.0 - n.y
		var snow := Color(0.88, 0.92, 0.98)
		var rock := Color(0.35, 0.34, 0.36)
		var dry_grass := Color(0.42, 0.4, 0.3)
		var c := snow
		if world_pos.y < 4.0:
			c = snow.lerp(dry_grass, clampf((4.0 - world_pos.y) / 6.0, 0.0, 0.85))
		if slope > 0.35:
			c = c.lerp(rock, clampf((slope - 0.35) / 0.4, 0.0, 1.0))
		if world_pos.y > 30.0:
			c = c.lerp(Color(0.95, 0.96, 1.0), 0.4)
		# 少量随机变化
		var jitter := _noise.get_noise_2d(world_pos.x * 0.5, world_pos.z * 0.5) * 0.05
		c.r = clampf(c.r + jitter, 0.0, 1.0)
		c.g = clampf(c.g + jitter, 0.0, 1.0)
		c.b = clampf(c.b + jitter, 0.0, 1.0)
		mdt.set_vertex_color(i, c)
	var mesh := ArrayMesh.new()
	mdt.commit_to_surface(mesh)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var texture: Texture2D = load("res://assets/textures/ground_snow.png")
	if texture != null:
		mat.albedo_texture = texture
		mat.uv1_scale = Vector3(0.25, 0.25, 0.25)
	mesh.surface_set_material(0, mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = origin
	root.add_child(mi)
	# 碰撞
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var trimesh := mesh.create_trimesh_shape()
	cs.shape = trimesh
	body.add_child(cs)
	body.position = origin
	root.add_child(body)
	return root
