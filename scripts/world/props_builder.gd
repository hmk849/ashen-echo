extends Node3D
## 场景道具构建:炉边镇、余烬灯塔、猎屋、古窖遗迹、神龛、树木/岩石(多网格实例)、篝火。

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 424242

func build(world: Node3D) -> void:
	var terrain: TerrainGenerator = world.terrain
	# —— 树木与岩石(多网格,性能友好)
	_scatter_vegetation(terrain)
	# —— 炉边镇
	_build_town(world)
	# —— 余烬灯塔(主灯塔,仍在燃烧)
	_build_lighthouse(world, Vector2(0, -56), true)
	# —— 废弃的二号灯塔
	_build_lighthouse(world, Vector2(160, -120), false)
	# —— 灰枝的猎屋
	_build_hut(world, Vector2(-140, 90))
	# —— 古窖遗迹(石墙圈)
	_build_crypt(world, Vector2(-50, 160))
	# —— 雪中神龛
	_build_shrine(world, Vector2(-180, -150))
	# —— 烬峰祭坛
	_build_peak_altar(world, Vector2(196, 196))
	# —— 篝火:镇中心、猎屋、遗迹、烬峰半山
	for pos: Vector2 in [Vector2(8, 4), Vector2(-136, 86), Vector2(-46, 156), Vector2(150, 150)]:
		_build_campfire(world, pos)

# ================================================================ 植被
func _scatter_vegetation(terrain: Node) -> void:
	var tree_count := 220
	var rock_count := 120
	var transforms: Array[Transform3D] = []
	var rock_transforms: Array[Transform3D] = []
	var attempts := 0
	while transforms.size() < tree_count and attempts < tree_count * 12:
		attempts += 1
		var x := _rng.randf_range(-240.0, 240.0)
		var z := _rng.randf_range(-240.0, 240.0)
		var v := Vector2(x, z)
		# 避开聚落与顶峰
		if v.length() < 46.0 or v.distance_to(Vector2(0, -56)) < 22.0 \
			or v.distance_to(Vector2(-140, 90)) < 22.0 or v.distance_to(Vector2(-50, 160)) < 24.0 \
			or v.distance_to(Vector2(160, -120)) < 24.0 or v.distance_to(Vector2(-180, -150)) < 18.0 \
			or v.distance_to(Vector2(200, 200)) < 40.0:
			continue
		var h: float = terrain.height(x, z)
		if h > 34.0:
			continue  # 高山不长树
		var t := Transform3D(Basis().scaled(Vector3.ONE * _rng.randf_range(0.7, 1.4)), Vector3(x, h, z))
		transforms.append(t)
	attempts = 0
	while rock_transforms.size() < rock_count and attempts < rock_count * 12:
		attempts += 1
		var x := _rng.randf_range(-240.0, 240.0)
		var z := _rng.randf_range(-240.0, 240.0)
		if Vector2(x, z).length() < 40.0:
			continue
		var h: float = terrain.height(x, z)
		var t := Transform3D(Basis().rotated(Vector3.UP, _rng.randf_range(0, TAU)).scaled(
			Vector3(_rng.randf_range(0.5, 2.2), _rng.randf_range(0.4, 1.6), _rng.randf_range(0.5, 2.2))),
			Vector3(x, h - 0.2, z))
		rock_transforms.append(t)
	# 树 = 树干多网格 + 树冠多网格(共享同一组变换)
	var trunk_mesh := _trunk_mesh()
	var foliage_mesh := _foliage_mesh()
	_add_multimesh(trunk_mesh, transforms)
	var foliage_transforms: Array[Transform3D] = []
	for t: Transform3D in transforms:
		var s := t.basis.get_scale()
		var ft := Transform3D(t.basis, t.origin + Vector3(0, 3.0 * s.y, 0))
		foliage_transforms.append(ft)
	_add_multimesh(foliage_mesh, foliage_transforms)
	_add_multimesh(_rock_mesh(), rock_transforms)

func _add_multimesh(mesh: Mesh, transforms: Array[Transform3D]) -> void:
	if transforms.is_empty():
		return
	var mmi := MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = transforms.size()
	for i: int in transforms.size():
		mm.set_instance_transform(i, transforms[i])
	mmi.multimesh = mm
	add_child(mmi)

func _trunk_mesh() -> Mesh:
	var cyl := CylinderMesh.new()
	cyl.top_radius = 0.16
	cyl.bottom_radius = 0.3
	cyl.height = 3.4
	cyl.radial_segments = 6
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.18, 0.13)
	var bark_tex: Texture2D = load("res://assets/textures/bark.png")
	if bark_tex != null:
		mat.albedo_texture = bark_tex
	cyl.material = mat
	return cyl

func _foliage_mesh() -> Mesh:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.6
	cone.height = 3.4
	cone.radial_segments = 7
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.18, 0.3, 0.25)
	cone.material = mat
	return cone

func _rock_mesh() -> Mesh:
	var mesh := SphereMesh.new()
	mesh.radius = 0.8
	mesh.height = 1.2
	mesh.radial_segments = 5
	mesh.rings = 2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.38, 0.38, 0.4)
	var rock_tex: Texture2D = load("res://assets/textures/rock.png")
	if rock_tex != null:
		mat.albedo_texture = rock_tex
	mesh.material = mat
	return mesh

# ================================================================ 建筑
func _building(world: Node3D, pos: Vector2, size: Vector3, color: Color, roof_color: Color, rot := 0.0) -> Node3D:
	var root := Node3D.new()
	var h: float = world.terrain.height(pos.x, pos.y)
	root.position = Vector3(pos.x, h, pos.y)
	root.rotation.y = rot
	var body := CSGBox3D.new()
	body.size = size
	body.position = Vector3(0, size.y / 2.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	var wood_tex: Texture2D = load("res://assets/textures/wood.png")
	if wood_tex != null:
		mat.albedo_texture = wood_tex
		mat.uv1_scale = Vector3(size.x / 4.0, size.y / 4.0, size.z / 4.0)
	body.material = mat
	root.add_child(body)
	# 屋顶(三棱柱)
	var roof := MeshInstance3D.new()
	var prism := PrismMesh.new()
	prism.size = Vector3(size.x + 0.8, 1.8, size.z + 0.9)
	prism.left_to_right = 0.5
	roof.mesh = prism
	roof.position = Vector3(0, size.y + 0.9, 0)
	var roof_mat := StandardMaterial3D.new()
	roof_mat.albedo_color = roof_color
	prism.material = roof_mat
	root.add_child(roof)
	# 碰撞
	var static_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = Vector3(0, size.y / 2.0, 0)
	static_body.add_child(cs)
	root.add_child(static_body)
	world.add_child(root)
	return root

func _build_town(world: Node3D) -> void:
	# 镇中心广场 + 环形建筑
	var wall := Color(0.55, 0.42, 0.3)
	var roof := Color(0.45, 0.2, 0.15)
	_building(world, Vector2(-18, -10), Vector3(8, 4.5, 7), wall, roof, 0.3)      # 铁匠铺(温霭)
	_building(world, Vector2(18, -12), Vector3(7, 4, 6), wall.lerp(Color.WHITE, 0.15), roof, -0.2)  # 镇公所(墨桓)
	_building(world, Vector2(-14, 14), Vector3(6, 3.8, 5.5), wall.lerp(Color.BLACK, 0.15), roof, 0.1)  # 杂货摊(白鸢)
	_building(world, Vector2(16, 14), Vector3(6, 3.8, 5.5), wall, roof, -0.4)     # 民居
	_building(world, Vector2(0, 24), Vector3(7, 4, 6), wall.lerp(Color.BLACK, 0.25), roof, 0.0)      # 民居
	_building(world, Vector2(-24, 2), Vector3(5.5, 3.5, 5), wall, roof, 1.2)      # 民居
	_building(world, Vector2(24, 4), Vector3(5.5, 3.5, 5), wall.lerp(Color.WHITE, 0.2), roof, -1.1)  # 守塔人小屋
	# 中央钟塔
	var h: float = world.terrain.height(0, 0)
	var tower := CSGCylinder3D.new()
	tower.radius = 1.6
	tower.height = 10.0
	tower.position = Vector3(0, h + 5.0, 0)
	var tower_mat := StandardMaterial3D.new()
	tower_mat.albedo_color = Color(0.5, 0.48, 0.45)
	var stone_tex: Texture2D = load("res://assets/textures/stone.png")
	if stone_tex != null:
		tower_mat.albedo_texture = stone_tex
	tower.material = tower_mat
	world.add_child(tower)
	var bell := AudioStreamPlayer3D.new()
	bell.stream = load("res://assets/audio/sfx_bell.wav")
	bell.max_db = 6.0
	bell.unit_size = 30.0
	bell.position = Vector3(0, h + 9.0, 0)
	bell.name = "TownBell"
	world.add_child(bell)
	# 篝火围栏、木箱点缀
	for i: int in 10:
		var angle := TAU * i / 10.0
		var bx := 12.0 * cos(angle)
		var bz := 12.0 * sin(angle)
		var crate := CSGBox3D.new()
		crate.size = Vector3(0.9, 0.9, 0.9)
		crate.position = Vector3(bx, world.terrain.height(bx, bz) + 0.45, bz)
		var crate_mat := StandardMaterial3D.new()
		crate_mat.albedo_color = Color(0.42, 0.3, 0.18)
		crate.material = crate_mat
		world.add_child(crate)

func _build_lighthouse(world: Node3D, pos: Vector2, burning: bool) -> void:
	var h: float = world.terrain.height(pos.x, pos.y)
	var root := Node3D.new()
	root.position = Vector3(pos.x, h, pos.y)
	root.name = "Lighthouse" + ("_Main" if burning else "_Ruin")
	var body := CSGCylinder3D.new()
	body.radius = 3.2
	body.height = 18.0
	body.position = Vector3(0, 9.0, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.58, 0.55)
	var stone_tex: Texture2D = load("res://assets/textures/stone.png")
	if stone_tex != null:
		mat.albedo_texture = stone_tex
	body.material = mat
	root.add_child(body)
	var lamp_mat := StandardMaterial3D.new()
	if burning:
		lamp_mat.albedo_color = Color(1.0, 0.65, 0.25)
		lamp_mat.emission_enabled = true
		lamp_mat.emission = Color(1.0, 0.5, 0.15)
		lamp_mat.emission_energy_multiplier = 3.0
	else:
		lamp_mat.albedo_color = Color(0.15, 0.15, 0.17)
	var lamp := CSGCylinder3D.new()
	lamp.radius = 2.2
	lamp.height = 3.0
	lamp.position = Vector3(0, 19.5, 0)
	lamp.material = lamp_mat
	root.add_child(lamp)
	if burning:
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.6, 0.25)
		light.light_energy = 2.2
		light.omni_range = 40.0
		light.position = Vector3(0, 19.5, 0)
		root.add_child(light)
		var flame := GPUParticles3D.new()
		flame.amount = 24
		flame.lifetime = 1.2
		var fmat := ParticleProcessMaterial.new()
		fmat.direction = Vector3.UP
		fmat.spread = 8.0
		fmat.initial_velocity_min = 2.0
		fmat.initial_velocity_max = 4.0
		fmat.gravity = Vector3(0, 2.0, 0)
		fmat.scale_min = 0.6
		fmat.scale_max = 1.4
		flame.process_material = fmat
		var quad := QuadMesh.new()
		quad.size = Vector2(0.5, 0.5)
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(1.0, 0.55, 0.15, 0.8)
		emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		emat.emission_enabled = true
		emat.emission = Color(1.0, 0.5, 0.1)
		emat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		quad.material = emat
		flame.draw_pass_1 = quad
		flame.position = Vector3(0, 19.0, 0)
		root.add_child(flame)
	# 碰撞
	var static_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 3.2
	cyl.height = 18.0
	cs.shape = cyl
	cs.position = Vector3(0, 9.0, 0)
	static_body.add_child(cs)
	root.add_child(static_body)
	world.add_child(root)

func _build_hut(world: Node3D, pos: Vector2) -> void:
	var root := _building(world, pos, Vector3(6, 3.5, 5), Color(0.4, 0.3, 0.2), Color(0.3, 0.18, 0.12), 0.6)
	root.name = "HuntersHut"
	# 晾晒的兽皮
	var hide := CSGBox3D.new()
	hide.size = Vector3(1.4, 1.8, 0.06)
	hide.position = Vector3(pos.x + 3.5, world.terrain.height(pos.x + 3.5, pos.y) + 2.0, pos.y)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.5, 0.38, 0.25)
	hide.material = hmat
	world.add_child(hide)

func _build_crypt(world: Node3D, pos: Vector2) -> void:
	var root := Node3D.new()
	var h: float = world.terrain.height(pos.x, pos.y)
	root.position = Vector3(pos.x, h, pos.y)
	root.name = "Crypt"
	var stone := Color(0.3, 0.32, 0.36)
	var stone_tex: Texture2D = load("res://assets/textures/stone.png")
	# 环形残墙
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i: int in 14:
		var angle := TAU * i / 14.0
		if i in [3, 4, 10]:   # 缺口
			continue
		var r := 13.0
		var wx := pos.x + cos(angle) * r
		var wz := pos.y + sin(angle) * r
		var wall := CSGBox3D.new()
		wall.size = Vector3(3.2, rng.randf_range(1.8, 3.4), 1.0)
		wall.position = Vector3(wx, world.terrain.height(wx, wz) + wall.size.y / 2.0, wz)
		wall.rotation.y = -angle + PI / 2.0
		var mat := StandardMaterial3D.new()
		mat.albedo_color = stone
		if stone_tex != null:
			mat.albedo_texture = stone_tex
		wall.material = mat
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = wall.size
		cs.shape = box
		sb.position = wall.position
		sb.rotation = wall.rotation
		sb.add_child(cs)
		world.add_child(wall)
		world.add_child(sb)
	# 中央石门
	var gate := CSGBox3D.new()
	gate.size = Vector3(3.0, 4.2, 0.8)
	gate.position = Vector3(pos.x, h + 2.1, pos.y)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.18, 0.2, 0.28)
	gmat.metallic = 0.4
	gate.material = gmat
	world.add_child(gate)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = gate.size
	cs.shape = box
	sb.position = gate.position
	sb.add_child(cs)
	world.add_child(sb)
	# 幽光
	var light := OmniLight3D.new()
	light.light_color = Color(0.3, 0.6, 1.0)
	light.light_energy = 1.2
	light.omni_range = 18.0
	light.position = Vector3(pos.x, h + 3.0, pos.y)
	world.add_child(light)

func _build_shrine(world: Node3D, pos: Vector2) -> void:
	var h: float = world.terrain.height(pos.x, pos.y)
	var root := Node3D.new()
	root.position = Vector3(pos.x, h, pos.y)
	var base := CSGCylinder3D.new()
	base.radius = 2.2
	base.height = 0.8
	base.position = Vector3(0, 0.4, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.52, 0.5)
	base.material = bmat
	root.add_child(base)
	var stone := CSGBox3D.new()
	stone.size = Vector3(1.2, 2.4, 0.7)
	stone.position = Vector3(0, 1.8, 0)
	stone.rotation.z = 0.15
	var smat := StandardMaterial3D.new()
	smat.albedo_color = Color(0.75, 0.7, 0.65)
	smat.emission_enabled = true
	smat.emission = Color(0.4, 0.7, 0.9)
	smat.emission_energy_multiplier = 0.6
	stone.material = smat
	root.add_child(stone)
	world.add_child(root)

func _build_peak_altar(world: Node3D, pos: Vector2) -> void:
	var h: float = world.terrain.height(pos.x, pos.y)
	var root := Node3D.new()
	root.position = Vector3(pos.x, h, pos.y)
	root.name = "PeakAltar"
	var ring := CSGCylinder3D.new()
	ring.radius = 5.0
	ring.height = 0.6
	ring.position = Vector3(0, 0.3, 0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.22, 0.26)
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.3, 0.1)
	mat.emission_energy_multiplier = 0.5
	ring.material = mat
	root.add_child(ring)
	var pillar := CSGCylinder3D.new()
	pillar.radius = 0.5
	pillar.height = 4.0
	pillar.position = Vector3(0, 2.3, 0)
	var pmat := StandardMaterial3D.new()
	pmat.albedo_color = Color(0.2, 0.18, 0.22)
	pillar.material = pmat
	root.add_child(pillar)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.4, 0.15)
	light.light_energy = 2.0
	light.omni_range = 25.0
	light.position = Vector3(0, 4.0, 0)
	root.add_child(light)
	# 碰撞体(供交互检测)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 5.0
	cyl.height = 1.0
	cs.shape = cyl
	cs.position = Vector3(0, 0.5, 0)
	sb.add_child(cs)
	root.add_child(sb)
	world.add_child(root)

func _build_campfire(world: Node3D, pos: Vector2) -> void:
	var h: float = world.terrain.height(pos.x, pos.y)
	var root := Node3D.new()
	root.position = Vector3(pos.x, h, pos.y)
	root.name = "Campfire"
	# 石圈
	for i: int in 7:
		var angle := TAU * i / 7.0
		var rock := CSGSphere3D.new()
		rock.radius = 0.28
		rock.position = Vector3(cos(angle) * 1.1, 0.15, sin(angle) * 1.1)
		var rmat := StandardMaterial3D.new()
		rmat.albedo_color = Color(0.3, 0.3, 0.32)
		rock.material = rmat
		root.add_child(rock)
	# 火焰粒子
	var flame := GPUParticles3D.new()
	flame.amount = 18
	flame.lifetime = 1.0
	var fmat := ParticleProcessMaterial.new()
	fmat.direction = Vector3.UP
	fmat.spread = 10.0
	fmat.initial_velocity_min = 1.5
	fmat.initial_velocity_max = 3.0
	fmat.gravity = Vector3(0, 1.5, 0)
	fmat.scale_min = 0.5
	fmat.scale_max = 1.2
	flame.process_material = fmat
	var quad := QuadMesh.new()
	quad.size = Vector2(0.45, 0.45)
	var emat := StandardMaterial3D.new()
	emat.albedo_color = Color(1.0, 0.55, 0.15, 0.85)
	emat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	emat.emission_enabled = true
	emat.emission = Color(1.0, 0.5, 0.1)
	emat.emission_energy_multiplier = 2.0
	emat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	quad.material = emat
	flame.draw_pass_1 = quad
	flame.position = Vector3(0, 0.4, 0)
	root.add_child(flame)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.6, 0.25)
	light.light_energy = 1.8
	light.omni_range = 14.0
	light.position = Vector3(0, 1.2, 0)
	root.add_child(light)
	# 交互:休息(治疗+存档)
	var area := Area3D.new()
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 2.2
	cs.shape = sphere
	area.add_child(cs)
	area.body_entered.connect(func(body):
		if body is CharacterBody3D and body.name == "Player":
			GameState.last_campfire_pos = root.global_position
			if GameState.hp < GameState.max_hp:
				var heal_mult := 1.5 if GameState.has_skill("e1") else 1.0
				GameState.heal(999.0)
				GameState.stamina = GameState.max_stamina
				EventBus.notify.emit("篝火休息", "寒夜中稍作休整,生命与体力完全恢复。")
				AudioManager.play_sfx("heal"))
	root.add_child(area)
	world.add_child(root)
