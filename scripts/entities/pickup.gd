extends CharacterBody3D
## 拾取物:靠近自动收入背包,带旋转动画与浮空。

var item_id := ""
var label := ""
var _mesh: MeshInstance3D
var _collected := false

func _ready() -> void:
	set_meta("pickup_uid", str(randi()) + "_" + item_id)
	var cs := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	cs.shape = sphere
	cs.position = Vector3(0, 0.4, 0)
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = 0.22
	mesh.height = 0.44
	_mesh.mesh = mesh
	var mat := StandardMaterial3D.new()
	var item: Dictionary = GameData.get_item(item_id)
	var color: Color = Color(0.6, 0.8, 0.5)
	var raw_color: Variant = item.get("color", null)
	if raw_color is Array and (raw_color as Array).size() >= 3:
		var ca: Array = raw_color
		color = Color(float(ca[0]), float(ca[1]), float(ca[2]))
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.5
	mesh.material = mat
	add_child(_mesh)
	var area := Area3D.new()
	var acs := CollisionShape3D.new()
	var asphere := SphereShape3D.new()
	asphere.radius = 1.6
	acs.shape = asphere
	area.add_child(acs)
	area.body_entered.connect(_on_body_entered)
	add_child(area)
	# 落地
	velocity = Vector3(0, -1.0, 0)

func _on_body_entered(body: Node3D) -> void:
	if _collected or not (body is CharacterBody3D) or body.name != "Player":
		return
	_collected = true
	set_meta("collected", true)
	GameState.add_item(item_id, 1)
	AudioManager.play_sfx("pickup")
	EventBus.notify.emit("获得物品", "%s x1" % label)
	queue_free()

func _physics_process(delta: float) -> void:
	if not is_on_floor():
		velocity.y -= 9.8 * delta
	else:
		velocity.y = 0
	move_and_slide()
	if _mesh != null:
		_mesh.rotate_y(delta * 2.0)
		_mesh.position.y = 0.5 + sin(Time.get_ticks_msec() / 400.0) * 0.08
