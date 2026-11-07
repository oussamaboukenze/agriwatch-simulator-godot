extends Node3D
## Procedural village and pasture. Animation is visual, in real seconds.
var farm
var walkers: Array = []
var clock := 0.0
var windmill: Node3D
var smoke: Array = []
var rain_drops: Array = []
var raining := false

func cube(pos: Vector3, size: Vector3, color: String, parent: Node = self):
	return farm.box(pos, size, Color(color), parent)

func ball(pos: Vector3, radius: float, color: String, parent: Node = self):
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2
	mesh.radial_segments = 7
	mesh.rings = 4
	return farm.shape(mesh, pos, Color(color), parent)

func cylinder(pos: Vector3, radius: float, height: float, color: String, parent: Node = self):
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 8
	return farm.shape(mesh, pos, Color(color), parent)

func roof(pos: Vector3, width: float, depth: float, parent: Node):
	for side in [-1, 1]:
		var part = cube(pos + Vector3(side * width * 0.25, 0, 0), Vector3(width * 0.62, 0.25, depth), "a94b38", parent)
		part.rotation.z = side * -0.52

func building(pos: Vector3, size: Vector3, color: String, house := false):
	var root := Node3D.new()
	root.position = pos
	add_child(root)
	cube(Vector3(0, size.y / 2, 0), size, color, root)
	roof(Vector3(0, size.y + 0.6, 0), size.x + 0.9, size.z + 0.8, root)
	cube(Vector3(0, 1.1, size.z / 2 + 0.03), Vector3(1.3 if house else 3, 2.2, 0.12), "69462d", root)
	for side in [-1, 1]:
		cube(Vector3(side * size.x * 0.31, 2.1, size.z / 2 + 0.07), Vector3(1.2, 1.2, 0.12), "80c8de", root)
		cube(Vector3(side * size.x * 0.31, 2.1, size.z / 2 + 0.15), Vector3(0.08, 1.2, 0.1), "f4e5bc", root)
	if house:
		cube(Vector3(2, size.y + 1, -1), Vector3(0.7, 2.5, 0.7), "ab8970", root)
		for i in range(4):
			var puff = ball(pos + Vector3(2, size.y + 2 + i * 0.6, -1), 0.28 + i * 0.14, "dfdfce")
			smoke.append({"node": puff, "base": puff.position, "phase": i * 0.8})

func fence(a: Vector3, b: Vector3):
	var length := a.distance_to(b)
	var direction := (b - a).normalized()
	var count := int(length / 2.5)
	for i in range(count + 1):
		cube(a.lerp(b, float(i) / maxi(count, 1)) + Vector3(0, 0.75, 0), Vector3(0.17, 1.5, 0.17), "d5bc8a")
	for height in [0.5, 1.1]:
		var rail = cube((a + b) / 2 + Vector3(0, height, 0), Vector3(0.12, 0.15, length), "c4a87a")
		rail.rotation.y = atan2(direction.x, direction.z)

func animal(pos: Vector3, sheep: bool, phase: float):
	var root := Node3D.new()
	add_child(root)
	var coat := "eee4c9" if sheep else "e9e5d9"
	var body = ball(Vector3(0, 1, 0), 0.65 if sheep else 0.85, coat, root)
	body.scale = Vector3(0.7, 0.75, 1.35)
	if not sheep:
		for i in range(3):
			var patch = ball(Vector3(0.48 if i % 2 == 0 else -0.48, 1.1, (i - 1) * 0.45), 0.27, "3c3a33", root)
			patch.scale.x = 0.2
	var head = ball(Vector3(0, 1.2, 0.88), 0.3 if sheep else 0.38, "645744" if sheep else "eee4cb", root)
	ball(Vector3(0, 1.12, 1.15), 0.22, "b28c75", root)
	for side in [-1, 1]:
		cube(Vector3(side * 0.34, 1.37, 0.87), Vector3(0.3, 0.1, 0.18), coat, root)
		ball(Vector3(side * 0.2, 1.37, 1.13), 0.045, "222824", root)
		if not sheep: cylinder(Vector3(side * 0.2, 1.65, 0.83), 0.05, 0.3, "e1ca91", root)
	var legs: Array = []
	for x in [-0.32, 0.32]:
		for z in [-0.5, 0.5]: legs.append(cube(Vector3(x, 0.4, z), Vector3(0.12, 0.8, 0.12), "645744", root))
	walkers.append({"node": root, "home": pos, "phase": phase, "legs": legs, "speed": 0.14 if sheep else 0.1, "radius": Vector2(2.0, 1.3), "head": head})

func person(pos: Vector3, phase: float, shirt: String):
	var root := Node3D.new()
	add_child(root)
	cube(Vector3(0, 1.2, 0), Vector3(0.55, 0.75, 0.35), shirt, root)
	ball(Vector3(0, 1.87, 0), 0.25, "c9946c", root)
	cylinder(Vector3(0, 2.08, 0), 0.4, 0.08, "d9ba6b", root)
	cylinder(Vector3(0, 2.2, 0), 0.23, 0.2, "cfa85b", root)
	var limbs: Array = []
	for side in [-1, 1]:
		limbs.append(cube(Vector3(side * 0.16, 0.43, 0), Vector3(0.2, 0.85, 0.22), "34505e", root))
		limbs.append(cube(Vector3(side * 0.4, 1.17, 0), Vector3(0.16, 0.7, 0.18), shirt, root))
	walkers.append({"node": root, "home": pos, "phase": phase, "legs": limbs, "speed": 0.16, "radius": Vector2(5, 0.65)})

func tree(pos: Vector3, height: float):
	cylinder(pos + Vector3(0, height * 0.35, 0), 0.23, height * 0.7, "795339")
	for i in range(3):
		var crown = ball(pos + Vector3(sin(i * 2.1) * 0.6, height - i * 0.4, cos(i * 2.1) * 0.6), 1.5, ["4e7946", "658e4e", "789b58"][i])
		crown.scale.y = 1.1

func _ready():
	building(Vector3(-18, 0, -22), Vector3(8, 4, 6), "f3dca7", true)
	building(Vector3(-5, 0, -23), Vector3(9, 4.5, 7), "a75340")
	building(Vector3(30, 0, 23), Vector3(6, 2.5, 4), "b49568")
	cube(Vector3(-18, 0.03, -14), Vector3(9, 0.12, 7), "c6b38b")
	cube(Vector3(-34, 0.04, 0), Vector3(2.5, 0.15, 54), "c6b38b")
	cube(Vector3(0, 0.04, -15), Vector3(69, 0.15, 2), "c6b38b")
	for x in range(-38, 40, 5):
		tree(Vector3(x, 0, -29), 3.6 + sin(x) * 0.5)
	for z in range(-20, 28, 7): tree(Vector3(-38, 0, z), 4.3)
	for i in range(6): tree(Vector3(17 + (i % 3) * 5, 0, -23 + (i / 3) * 5), 3.8)
	# Outer boundary and pasture, with entrances left open.
	fence(Vector3(-40, 0, -31), Vector3(40, 0, -31))
	fence(Vector3(-40, 0, -31), Vector3(-40, 0, 31))
	fence(Vector3(40, 0, -31), Vector3(40, 0, 31))
	fence(Vector3(-40, 0, 31), Vector3(-5, 0, 31))
	fence(Vector3(5, 0, 31), Vector3(40, 0, 31))
	fence(Vector3(-29, 0, 15), Vector3(24, 0, 15))
	fence(Vector3(-29, 0, 15), Vector3(-29, 0, 28))
	fence(Vector3(-29, 0, 28), Vector3(24, 0, 28))
	fence(Vector3(24, 0, 15), Vector3(24, 0, 28))
	for i in range(7): animal(Vector3(-23 + (i % 4) * 5, 0, 19 + (i / 4) * 5), false, i * 1.3)
	for i in range(9): animal(Vector3(1 + (i % 4) * 5, 0, 18 + (i / 4) * 3.3), true, i * 1.7)
	for i in range(5): person(Vector3(-24 + i * 12, 0, 12), i * 1.5, ["cf7150", "4d869b", "c4a350", "668b64", "97729a"][i])
	person(Vector3(-16, 0, -15), 2, "4d869b")
	# Well, water trough and hay bales.
	cylinder(Vector3(-28, 0.6, -18), 1, 1.2, "a6a18b")
	cylinder(Vector3(-28, 1.22, -18), 0.75, 0.04, "508ba4")
	for x in [-29, -27]: cube(Vector3(x, 2, -18), Vector3(0.13, 2.2, 0.13), "795339")
	roof(Vector3(-28, 3.1, -18), 3, 2.3, self)
	cube(Vector3(-4, 0.4, 25), Vector3(4, 0.8, 1), "969c92")
	cube(Vector3(-4, 0.82, 25), Vector3(3.7, 0.05, 0.8), "65b3c8")
	for i in range(7): cylinder(Vector3(6 + (i % 3) * 1.6, 0.6 + (i / 3) * 0.3, -23), 0.7, 1.2, "dfc378")
	# Tractor: chassis, cabin, large rear wheels, exhaust.
	var tractor := Node3D.new()
	tractor.position = Vector3(-32, 0, -9)
	add_child(tractor)
	cube(Vector3(0, 0.9, 0), Vector3(1.6, 0.8, 3), "487e51", tractor)
	cube(Vector3(0, 1.5, 0.8), Vector3(1.3, 0.7, 1.3), "65984f", tractor)
	cube(Vector3(0, 2, -0.8), Vector3(1.5, 1.5, 1.3), "76aeb3", tractor)
	cube(Vector3(0, 2.85, -0.8), Vector3(1.9, 0.15, 1.6), "e5d9a8", tractor)
	cylinder(Vector3(0.5, 2, 1), 0.1, 1.7, "424d49", tractor)
	for side in [-1, 1]:
		for z in [-1, 1]:
			var wheel = cylinder(Vector3(side * 1, 0.65, z), 0.75 if z == -1 else 0.5, 0.4, "2c3534", tractor)
			wheel.rotation.z = PI / 2
	# Wind turbine beside the barn.
	cylinder(Vector3(7, 3.5, -19), 0.2, 7, "c5cbc2")
	windmill = Node3D.new()
	windmill.position = Vector3(7, 7, -19)
	add_child(windmill)
	ball(Vector3.ZERO, 0.35, "e8dfbc", windmill)
	for i in range(4):
		var blade = cube(Vector3(sin(i * PI / 2) * 1.5, cos(i * PI / 2) * 1.5, 0), Vector3(0.35, 2.8, 0.12), "e7dfc7", windmill)
		blade.rotation.z = -i * PI / 2
	# Cloud silhouettes and visible rain, without external assets.
	for i in range(7):
		for j in range(3):
			var cloud = ball(Vector3(-30 + i * 10 + j, 15 + sin(i) * 2, -30), 1.6, "e5ece7")
			cloud.scale = Vector3(1.7, 0.4, 0.7)
	for i in range(110):
		var drop = cube(Vector3(fmod(i * 13.7, 65) - 32, fmod(i * 1.7, 11) + 1, fmod(i * 7.3, 43) - 22), Vector3(0.035, 0.6, 0.035), "91c7da")
		rain_drops.append(drop)

func _process(delta):
	clock += delta
	windmill.rotation.z = clock * 0.7
	for actor in walkers:
		var t: float = clock * actor.speed + actor.phase
		actor.node.position = actor.home + Vector3(sin(t) * actor.radius.x, 0, cos(t) * actor.radius.y)
		actor.node.rotation.y = atan2(cos(t) * actor.radius.x, -sin(t) * actor.radius.y)
		for i in range(actor.legs.size()): actor.legs[i].rotation.x = sin(clock * 5 + i * PI) * 0.23
		if actor.has("head"): actor.head.rotation.x = sin(clock * 0.8 + actor.phase) * 0.18
	for puff in smoke:
		puff.node.position = puff.base + Vector3(sin(clock + puff.phase) * 0.3, fmod(clock * 0.3 + puff.phase, 1.2), 0)
	for drop in rain_drops:
		drop.visible = raining
		if raining: drop.position.y = fposmod(drop.position.y - delta * 10, 12)
