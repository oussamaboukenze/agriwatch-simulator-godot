extends Node3D
signal selected(index: int)
var camera: Camera3D
var focus := Vector3.ZERO
var yaw := 0.32
var pitch := 0.82
var distance := 76.0
var beds: Array = []
var lamps: Array = []
var water: Array = []
var life
var sim
var crop_nodes: Array = []
var crop_names: Array = []
var signs: Array = []
var markers: Array = []

func parcel_center(index: int) -> Vector3:
	return Vector3((index % 3 - 1) * 20.0, 0, -5.2 if index < 3 else 5.2)

func material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.9
	return mat

func shape(mesh: Mesh, pos: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	obj.mesh = mesh
	obj.material_override = material(color)
	obj.position = pos
	parent.add_child(obj)
	return obj

func box(pos: Vector3, size: Vector3, color: Color, parent: Node = self) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return shape(mesh, pos, color, parent)

func _ready():
	box(Vector3(0, -0.4, 0), Vector3(82, 0.7, 64), Color("7b9360"))
	box(Vector3(0, 0.01, 12), Vector3(76, 0.1, 2.2), Color("c2b38d"))
	for i in range(sim.parcels.size()):
		var center := parcel_center(i)
		var x := center.x
		var z := center.z
		beds.append(box(center, Vector3(17, 0.3, 8.8), Color("60442f")))
		var body := StaticBody3D.new()
		body.set_meta("parcel", i)
		var collision := CollisionShape3D.new()
		var volume := BoxShape3D.new()
		volume.size = Vector3(17, 2, 8.8)
		collision.shape = volume
		body.position = center + Vector3(0, 0.5, 0)
		body.add_child(collision)
		add_child(body)
		var plants := Node3D.new()
		add_child(plants)
		crop_nodes.append(plants)
		crop_names.append("__unset__")
		# Furrows remain visible on unplanted land.
		for row in range(14):
			box(Vector3(x - 7.4 + row * 1.13, 0.17, z), Vector3(0.12, 0.06, 8.4), Color("795639"))
		box(Vector3(x, 0.3, z + 3.6), Vector3(16, 0.12, 0.12), Color("3a5461"))
		var drops := Node3D.new()
		add_child(drops)
		for n in range(24):
			box(Vector3(x - 7.5 + n * 0.65, 0.85, z + 3.4), Vector3(0.06, 0.65, 0.06), Color("71cce7"), drops)
		water.append(drops)
		var group: Array = []
		for s in range(3):
			var offset: Vector2 = sim.STATION_OFFSETS[s]
			var station_pos := center + Vector3(offset.x, 0, offset.y)
			box(station_pos + Vector3(0, 1, 0), Vector3(0.12, 2, 0.12), Color("d0d6cb"))
			for m in range(3):
				group.append(box(station_pos + Vector3((m - 1) * 0.35, 1.9 - m * 0.38, 0), Vector3(0.3, 0.3, 0.3), Color("62dcad")))
			var station_sign := Label3D.new()
			station_sign.text = "%02d-%s" % [i + 1, ["A", "B", "C"][s]]
			station_sign.position = station_pos + Vector3(0, 2.45, 0)
			station_sign.font_size = 24
			station_sign.pixel_size = 0.015
			station_sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			add_child(station_sign)
		lamps.append(group)
		var label := Label3D.new()
		label.position = Vector3(x, 1.1, z + 4.4)
		label.font_size = 28
		label.pixel_size = 0.013
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		add_child(label)
		signs.append(label)
		markers.append(box(Vector3(x, 0.2, z + 4.3), Vector3(16.5, 0.12, 0.22), Color("62dcad")))
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, 0)
	sun.light_energy = 1.3
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color("a6c8d9")
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.65
	add_child(env)
	camera = Camera3D.new()
	camera.fov = 52
	camera.h_offset = -11.0
	add_child(camera)
	life = preload("res://scripts/life.gd").new()
	life.farm = self
	add_child(life)

func _process(delta):
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_Z): move.z -= 1
	if Input.is_physical_key_pressed(KEY_S): move.z += 1
	if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_Q): move.x -= 1
	if Input.is_physical_key_pressed(KEY_D): move.x += 1
	focus += move.rotated(Vector3.UP, yaw) * delta * 8
	focus.x = clampf(focus.x, -40, 40)
	focus.z = clampf(focus.z, -30, 30)
	camera.position = focus + Vector3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)) * distance
	camera.look_at(focus)

func _unhandled_input(event):
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		yaw -= event.relative.x * 0.006
		pitch = clampf(pitch + event.relative.y * 0.005, 0.25, 1.4)
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP: distance = maxf(12, distance - 2)
		if event.button_index == MOUSE_BUTTON_WHEEL_DOWN: distance = minf(120, distance + 3)
		if event.button_index == MOUSE_BUTTON_LEFT:
			var origin := camera.project_ray_origin(event.position)
			var query := PhysicsRayQueryParameters3D.create(origin, origin + camera.project_ray_normal(event.position) * 200)
			var hit := get_world_3d().direct_space_state.intersect_ray(query)
			if hit and hit.collider.has_meta("parcel"): selected.emit(hit.collider.get_meta("parcel"))

func refresh(parcels: Array, selected_index: int):
	life.raining = parcels[0].values[2] > 0.5
	for i in range(parcels.size()):
		if crop_names[i] != parcels[i].crop: rebuild_crop(i, parcels[i].crop)
		var moisture: float = parcels[i].values[1] / 100.0
		var soil_color := Color("b89663").lerp(Color("493f30"), moisture)
		beds[i].material_override.albedo_color = soil_color.lightened(0.16) if i == selected_index else soil_color
		water[i].visible = parcels[i].irrigation
		for s in range(3):
			for m in range(3):
				lamps[i][s * 3 + m].material_override.albedo_color = Color("62dcad") if parcels[i].stations[s].online[m] else Color("ee675c")
		var diagnosis: Dictionary = sim.diagnosis(i)
		var color: Color = {"good": Color("79d797"), "alert": Color("ef8968"), "empty": Color("e7c97d"), "unknown": Color("a8b5c1")}[diagnosis.kind]
		markers[i].material_override.albedo_color = color
		signs[i].modulate = color
		signs[i].text = "%02d · %s\n%s" % [i + 1, "TERRE NUE" if parcels[i].crop == "" else parcels[i].crop.to_upper(), {"good": "COMPATIBLE", "alert": "À SURVEILLER", "empty": "À ÉVALUER", "unknown": "SANS DONNÉES"}[diagnosis.kind]]

func rebuild_crop(index: int, crop: String):
	crop_names[index] = crop
	for child in crop_nodes[index].get_children():
		crop_nodes[index].remove_child(child)
		child.queue_free()
	if crop == "": return
	var center := parcel_center(index)
	var height: float = {"Blé": 1.0, "Maïs": 1.8, "Soja": 0.7, "Orge": 0.9, "Pomme de terre": 0.5, "Tomate": 1.1}[crop]
	var color: Color = {"Blé": Color("e5c466"), "Maïs": Color("b8c953"), "Soja": Color("4c8751"), "Orge": Color("d3b779"), "Pomme de terre": Color("5c8a48"), "Tomate": Color("bd6c44")}[crop]
	for row in range(14):
		for col in range(6):
			var pos := center + Vector3(-7.4 + row * 1.13, height / 2 + 0.2, -3.2 + col * 1.2)
			box(pos, Vector3(0.1, height, 0.1), Color("749743"), crop_nodes[index])
			var crown := SphereMesh.new()
			crown.radius = 0.25
			crown.height = 0.55
			crown.radial_segments = 5
			crown.rings = 3
			shape(crown, pos + Vector3(0, height / 2, 0), color, crop_nodes[index])
