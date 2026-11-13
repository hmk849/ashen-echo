class_name EntityFactory
extends Node
## 程序化模型工厂:人形(玩家/NPC/教徒)、狼、雪傀儡 —— 全部为原创低多边形模型。

static func _c(colors: Dictionary, key: String, fallback: Color) -> Color:
	var v: Variant = colors.get(key, null)
	if v is Color:
		return v
	if v is Array and (v as Array).size() >= 3:
		var a: Array = v
		return Color(float(a[0]), float(a[1]), float(a[2]))
	return fallback

static func make_humanoid(colors: Dictionary) -> Node3D:
	var root := Node3D.new()
	var skin: Color = _c(colors, "skin", Color(0.9, 0.78, 0.68))
	var cloth: Color = _c(colors, "cloth", Color(0.3, 0.35, 0.45))
	var pants: Color = _c(colors, "pants", Color(0.2, 0.22, 0.28))
	var hair: Color = _c(colors, "hair", Color(0.15, 0.12, 0.1))
	# 躯干
	var torso := MeshInstance3D.new()
	var torso_mesh := CapsuleMesh.new()
	torso_mesh.radius = 0.26
	torso_mesh.height = 0.75
	torso.mesh = torso_mesh
	torso.position = Vector3(0, 1.15, 0)
	torso.name = "Torso"
	var tmat := StandardMaterial3D.new()
	tmat.albedo_color = cloth
	torso_mesh.material = tmat
	root.add_child(torso)
	# 头
	var head := MeshInstance3D.new()
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.17
	head_mesh.height = 0.34
	head.mesh = head_mesh
	head.position = Vector3(0, 1.72, 0)
	head.name = "Head"
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = skin
	head_mesh.material = hmat
	root.add_child(head)
	# 头发
	var hair_node := MeshInstance3D.new()
	var hair_mesh := SphereMesh.new()
	hair_mesh.radius = 0.18
	hair_mesh.height = 0.3
	hair_node.mesh = hair_mesh
	hair_node.position = Vector3(0, 1.78, 0.02)
	hair_node.name = "Hair"
	var hm := StandardMaterial3D.new()
	hm.albedo_color = hair
	hair_mesh.material = hm
	root.add_child(hair_node)
	# 四肢(记录在身体节点里,供程序化动画摆动)
	for side: String in ["L", "R"]:
		var sx := 1.0 if side == "L" else -1.0
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.07
		arm_mesh.height = 0.55
		arm.mesh = arm_mesh
		arm.position = Vector3(sx * 0.33, 1.2, 0)
		arm.name = "Arm" + side
		var amat := StandardMaterial3D.new()
		amat.albedo_color = cloth.lerp(skin, 0.4)
		arm_mesh.material = amat
		root.add_child(arm)
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.09
		leg_mesh.height = 0.7
		leg.mesh = leg_mesh
		leg.position = Vector3(sx * 0.14, 0.42, 0)
		leg.name = "Leg" + side
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = pants
		leg_mesh.material = lmat
		root.add_child(leg)
	# 手持武器挂点
	var hand := Node3D.new()
	hand.name = "HandR"
	hand.position = Vector3(-0.4, 1.1, 0.15)
	root.add_child(hand)
	return root

static func make_sword(length := 0.9, color := Color(0.75, 0.77, 0.8)) -> Node3D:
	var root := Node3D.new()
	var blade := MeshInstance3D.new()
	var blade_mesh := BoxMesh.new()
	blade_mesh.size = Vector3(0.06, length, 0.015)
	blade.mesh = blade_mesh
	blade.position = Vector3(0, length / 2.0 + 0.12, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = color
	bmat.metallic = 0.85
	bmat.roughness = 0.3
	blade_mesh.material = bmat
	root.add_child(blade)
	var guard := MeshInstance3D.new()
	var guard_mesh := BoxMesh.new()
	guard_mesh.size = Vector3(0.2, 0.05, 0.05)
	guard.mesh = guard_mesh
	guard.position = Vector3(0, 0.12, 0)
	var gmat := StandardMaterial3D.new()
	gmat.albedo_color = Color(0.4, 0.3, 0.15)
	guard_mesh.material = gmat
	root.add_child(guard)
	var grip := MeshInstance3D.new()
	var grip_mesh := CylinderMesh.new()
	grip_mesh.top_radius = 0.03
	grip_mesh.bottom_radius = 0.035
	grip_mesh.height = 0.22
	grip.mesh = grip_mesh
	grip.position = Vector3(0, 0.0, 0)
	var grmat := StandardMaterial3D.new()
	grmat.albedo_color = Color(0.25, 0.16, 0.1)
	grip_mesh.material = grmat
	root.add_child(grip)
	return root

static func make_wolf() -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := CapsuleMesh.new()
	body_mesh.radius = 0.24
	body_mesh.height = 1.1
	body.mesh = body_mesh
	body.rotation.z = PI / 2.0
	body.position = Vector3(0, 0.55, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.42, 0.42, 0.46)
	body_mesh.material = bmat
	root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.26, 0.24, 0.4)
	head.mesh = head_mesh
	head.position = Vector3(0, 0.7, -0.65)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.35, 0.35, 0.4)
	head_mesh.material = hmat
	root.add_child(head)
	for sx: float in [-0.16, 0.16]:
		for sz: float in [-0.35, 0.35]:
			var leg := MeshInstance3D.new()
			var leg_mesh := CapsuleMesh.new()
			leg_mesh.radius = 0.05
			leg_mesh.height = 0.5
			leg.mesh = leg_mesh
			leg.position = Vector3(sx, 0.25, sz)
			leg.name = "Leg_%d_%d" % [int(sx * 100), int(sz * 100)]
			var lmat := StandardMaterial3D.new()
			lmat.albedo_color = Color(0.3, 0.3, 0.34)
			leg_mesh.material = lmat
			root.add_child(leg)
	return root

static func make_golem(scale := 1.6) -> Node3D:
	var root := Node3D.new()
	var body := MeshInstance3D.new()
	var body_mesh := BoxMesh.new()
	body_mesh.size = Vector3(0.9, 1.2, 0.6) * scale
	body.mesh = body_mesh
	body.position = Vector3(0, 1.1 * scale, 0)
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.55, 0.58, 0.62)
	var rock_tex: Texture2D = load("res://assets/textures/rock.png")
	if rock_tex != null:
		bmat.albedo_texture = rock_tex
	body_mesh.material = bmat
	root.add_child(body)
	var head := MeshInstance3D.new()
	var head_mesh := BoxMesh.new()
	head_mesh.size = Vector3(0.42, 0.4, 0.42) * scale
	head.mesh = head_mesh
	head.position = Vector3(0, 1.95 * scale, 0)
	var hmat := StandardMaterial3D.new()
	hmat.albedo_color = Color(0.4, 0.45, 0.5)
	hmat.emission_enabled = true
	hmat.emission = Color(0.2, 0.7, 1.0)
	hmat.emission_energy_multiplier = 0.8
	head_mesh.material = hmat
	root.add_child(head)
	for sx: float in [-0.62, 0.62]:
		var arm := MeshInstance3D.new()
		var arm_mesh := CapsuleMesh.new()
		arm_mesh.radius = 0.16 * scale
		arm_mesh.height = 1.0 * scale
		arm.mesh = arm_mesh
		arm.position = Vector3(sx * scale, 1.2 * scale, 0)
		arm.name = "Arm" + ("L" if sx > 0 else "R")
		var amat := StandardMaterial3D.new()
		amat.albedo_color = Color(0.48, 0.5, 0.55)
		arm_mesh.material = amat
		root.add_child(arm)
		var leg := MeshInstance3D.new()
		var leg_mesh := CapsuleMesh.new()
		leg_mesh.radius = 0.18 * scale
		leg_mesh.height = 0.7 * scale
		leg.mesh = leg_mesh
		leg.position = Vector3(sx * 0.3 * scale, 0.35 * scale, 0)
		var lmat := StandardMaterial3D.new()
		lmat.albedo_color = Color(0.45, 0.47, 0.5)
		leg_mesh.material = lmat
		root.add_child(leg)
	return root
