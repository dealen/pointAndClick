extends Node3D
## A room built from a JSON description (see docs/WRITING_CASES.md).
##
## Walls are numbered 0 = back, 1 = right, 2 = front, 3 = left. The camera
## looks at one wall at a time ("view"). The wall nearest the camera is
## invisible from behind, and props tagged with that wall are hidden too.

const People := preload("res://core/people.gd")
## Anything narrower than this on screen is not offered as a tap target.
const MIN_PIXELS := 6.0

var data: Dictionary = {}
var size := Vector3(5, 3, 4)
var props: Array = []
var view := 0

var _mats: Dictionary = {}
var _blinkers: Array = []
var _conditional: Array = []
var _time := 0.0


func build(room_data: Dictionary, detective: Dictionary) -> void:
	data = room_data
	size = _v3(data.get("size", [5, 3, 4]))
	_build_shell()
	for light in data.get("lights", []):
		_add_light(light)
	for prop in data.get("props", []):
		_add_prop(prop, detective)
	refresh()


## Re-checks every "if" on props and parts. Call after facts change.
func refresh() -> void:
	var near := (view + 2) % 4
	for n in props:
		var p: Dictionary = n.get_meta("data")
		n.visible = GameState.check(p.get("if")) and int(p.get("wall", -1)) != near
	for part in _conditional:
		part.visible = GameState.check(part.get_meta("if"))


func set_view(p_view: int) -> void:
	view = posmod(p_view, 4)
	refresh()


## Hotspots that can be tapped right now. With a camera, things seen edge-on
## (a poster on a side wall) are left out until the player turns to face them.
func hotspots(camera: Camera3D = null) -> Array:
	var out: Array = []
	for n in props:
		var p: Dictionary = n.get_meta("data")
		if not (n.visible and p.has("hotspot") and GameState.check(p["hotspot"].get("if"))):
			continue
		if camera != null:
			var rect := screen_rect(n, camera)
			if minf(rect.size.x, rect.size.y) < MIN_PIXELS:
				continue
		out.append(n)
	return out


## Where a prop appears on screen, in viewport pixels.
func screen_rect(n: Node3D, camera: Camera3D) -> Rect2:
	var box: AABB = n.get_meta("aabb")
	var rect := Rect2()
	for i in 8:
		var point := camera.unproject_position(n.global_transform * box.get_endpoint(i))
		rect = Rect2(point, Vector2.ZERO) if i == 0 else rect.expand(point)
	return rect


## The hotspot under a tap. Small things win over the big things behind them.
func pick(camera: Camera3D, pos: Vector2, margin: float) -> Node3D:
	var best: Node3D = null
	var best_area := INF
	for n in hotspots(camera):
		var rect := screen_rect(n, camera).grow(margin)
		if rect.has_point(pos) and rect.get_area() < best_area:
			best = n
			best_area = rect.get_area()
	return best


func _process(delta: float) -> void:
	_time += delta
	var on := fmod(_time, 1.0) < 0.5
	for m in _blinkers:
		m.emission_energy_multiplier = m.get_meta("glow") if on else 0.0


# ------------------------------------------------------------------ building

func _build_shell() -> void:
	var floor_mesh := BoxMesh.new()
	floor_mesh.size = Vector3(size.x, 0.2, size.z)
	var floor_node := MeshInstance3D.new()
	floor_node.mesh = floor_mesh
	floor_node.position.y = -0.1
	floor_node.material_override = _mat(Color.html(str(data.get("floor", "#3a3340"))))
	add_child(floor_node)

	var wall_color := Color.html(str(data.get("walls", "#4a4458")))
	var walls := [
		[Vector3(0, size.y / 2, -size.z / 2), 0.0, size.x],
		[Vector3(size.x / 2, size.y / 2, 0), -90.0, size.z],
		[Vector3(0, size.y / 2, size.z / 2), 180.0, size.x],
		[Vector3(-size.x / 2, size.y / 2, 0), 90.0, size.z],
	]
	for w in walls:
		var quad := QuadMesh.new()
		quad.size = Vector2(w[2], size.y)
		var wall := MeshInstance3D.new()
		wall.mesh = quad
		wall.position = w[0]
		wall.rotation_degrees.y = w[1]
		wall.material_override = _mat(wall_color)
		wall.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(wall)


func _add_light(l: Dictionary) -> void:
	var light: Light3D
	if str(l.get("type", "omni")) == "sun":
		light = DirectionalLight3D.new()
		light.rotation_degrees = _v3(l.get("rot", [-60, 30, 0]))
	else:
		var omni := OmniLight3D.new()
		omni.omni_range = float(l.get("range", 4.0))
		omni.position = _v3(l.get("pos", [0, 2, 0]))
		light = omni
	light.light_color = Color.html(str(l.get("color", "#ffffff")))
	light.light_energy = float(l.get("energy", 1.0))
	light.shadow_enabled = bool(l.get("shadow", false))
	add_child(light)


func _add_prop(p: Dictionary, detective: Dictionary) -> void:
	var n := Node3D.new()
	n.name = str(p.get("id", "prop"))
	n.position = _v3(p.get("pos", [0, 0, 0]))
	n.rotation_degrees.y = float(p.get("rot", 0))
	if p.has("scale"):
		n.scale = _v3(p["scale"])
	add_child(n)
	var parts: Array = p.get("parts", []).duplicate()
	if p.has("person"):
		parts.append_array(People.parts(p["person"], detective))
	var box := AABB()
	var first := true
	for part in parts:
		var part_box := _add_part(n, part)
		if part.get("nohit", false):
			continue
		box = part_box if first else box.merge(part_box)
		first = false
	n.set_meta("data", p)
	n.set_meta("aabb", box)
	props.append(n)


func _add_part(parent: Node3D, part: Dictionary) -> AABB:
	var mesh: Mesh
	var extent := Vector3.ONE
	if part.has("box"):
		var box := BoxMesh.new()
		box.size = _v3(part["box"])
		extent = box.size
		mesh = box
	elif part.has("cyl"):
		var c: Array = part["cyl"]
		var cyl := CylinderMesh.new()
		cyl.bottom_radius = float(c[0])
		cyl.top_radius = float(c[2]) if c.size() > 2 else float(c[0])
		cyl.height = float(c[1])
		cyl.radial_segments = 10
		cyl.rings = 1
		extent = Vector3(float(c[0]) * 2, float(c[1]), float(c[0]) * 2)
		mesh = cyl
	else:
		var r := float(part.get("sphere", 0.1))
		var sphere := SphereMesh.new()
		sphere.radius = r
		sphere.height = r * 2
		sphere.radial_segments = 10
		sphere.rings = 5
		extent = Vector3.ONE * r * 2
		mesh = sphere

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = _v3(part.get("at", [0, 0, 0]))
	node.rotation_degrees = _v3(part.get("rot", [0, 0, 0]))
	var color := Color.html(str(part.get("color", "#808080")))
	var glow := float(part.get("glow", 0.0))
	if part.get("blink", false):
		var m := _mat(color, glow, float(part.get("alpha", 1.0)), true)
		m.set_meta("glow", glow)
		_blinkers.append(m)
		node.material_override = m
	else:
		node.material_override = _mat(color, glow, float(part.get("alpha", 1.0)))
	if glow > 0.0:
		node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if part.has("if"):
		node.set_meta("if", part["if"])
		_conditional.append(node)
	parent.add_child(node)
	return node.transform * AABB(-extent / 2, extent)


func _mat(color: Color, glow := 0.0, alpha := 1.0, unique := false) -> StandardMaterial3D:
	var key := "%s|%s|%s" % [color.to_html(), glow, alpha]
	if not unique and _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 1.0
	m.metallic_specular = 0.0
	if glow > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = glow
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color.a = alpha
	if not unique:
		_mats[key] = m
	return m


static func _v3(a: Variant) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))
