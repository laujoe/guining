extends SubViewportContainer
## First-person observation stations. Only the camera and lamp/shadow move.
const SURFACE = preload("res://scripts/library_surface.gdshader")
const ATLAS = preload("res://assets/lantern-materials-v1.png")
var app
var view: SubViewport
var world: Node3D
var architecture: Node3D
var camera: Camera3D
var lamp_root: Node3D
var lamp_light: OmniLight3D
var handle_roots: Dictionary = {}
var ink_roots: Dictionary = {}
var seam_nodes: Dictionary = {}
var mats: Dictionary = {}
var built = false
var last_lamp = -1.0
var last_node = ""

func _ready() -> void:
	name = "ShadowLibrary"
	size = Vector2(1600, 900)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func material(color: String, kind: int = -1, emission: float = 0.0) -> Material:
	var key = color + str(kind) + str(emission)
	if mats.has(key): return mats[key]
	var result: Material
	if kind >= 0:
		var shader_mat = ShaderMaterial.new()
		shader_mat.shader = SURFACE
		shader_mat.set_shader_parameter("pigment", Color(color))
		shader_mat.set_shader_parameter("kind", kind)
		shader_mat.set_shader_parameter("atlas", ATLAS)
		result = shader_mat
	else:
		var standard = StandardMaterial3D.new()
		standard.albedo_color = Color(color)
		standard.roughness = 0.78
		if emission > 0:
			standard.emission_enabled = true
			standard.emission = Color(color)
			standard.emission_energy_multiplier = emission
		result = standard
	mats[key] = result
	return result

func box(parent: Node3D, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	n.mesh = mesh
	n.material_override = mat
	n.position = p
	parent.add_child(n)
	return n

func sphere(parent: Node3D, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var n = MeshInstance3D.new()
	var mesh = SphereMesh.new()
	mesh.radius = 0.5
	mesh.height = 1
	mesh.radial_segments = 20
	mesh.rings = 10
	n.mesh = mesh
	n.scale = dimensions
	n.position = p
	n.material_override = mat
	parent.add_child(n)
	return n

func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, height: float, mat: Material) -> MeshInstance3D:
	var n = box(parent, (a + b) * 0.5, Vector3(width, height, a.distance_to(b)), mat)
	if a.distance_to(b) > 0.001:
		var direction = (b-a).normalized()
		n.basis = Basis.looking_at(direction,Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	return n

func roof(parent: Node3D, y: float, width: float, length: float) -> void:
	var mesh = ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES)
	var zs = [-1.0, -0.88, -0.5, 0.0, 0.5, 0.88, 1.0]
	var ys = [0.2, 0.0, 0.6, 1.35, 0.6, 0.0, 0.2]
	for i in range(zs.size() - 1):
		var a = Vector3(-width / 2, y + ys[i], zs[i] * length / 2)
		var b = Vector3(width / 2, y + ys[i], zs[i] * length / 2)
		var c = Vector3(width / 2, y + ys[i + 1], zs[i + 1] * length / 2)
		var d = Vector3(-width / 2, y + ys[i + 1], zs[i + 1] * length / 2)
		var normal = (c-a).cross(b-a).normalized()
		for p in [a,c,b,a,d,c]:
			mesh.surface_set_normal(normal)
			mesh.surface_add_vertex(p)
	mesh.surface_end()
	var n = MeshInstance3D.new()
	n.mesh = mesh
	var mat = StandardMaterial3D.new()
	mat.albedo_color = Color("434944")
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	n.material_override = mat
	parent.add_child(n)
	for z in [-length / 2, length / 2]:
		box(parent, Vector3(0, y + 0.12, z), Vector3(width + 0.12, 0.18, 0.14), material("806348",4))
	box(parent, Vector3(0,y+1.35,0),Vector3(width,0.16,0.19),material("756d53"))
	for row in range(5):
		box(parent,Vector3(0,y-0.1,-length*0.4+row*length*0.2),Vector3(width,0.14,0.16),material("806348",4))
	for side in [-1,0,1]:
		box(parent,Vector3(side*width*0.32,y-0.18,0),Vector3(0.14,0.16,length),material("492b21",2))

func bookcase(parent: Node3D, p: Vector3, angle: float, size_factor: float = 1.0) -> void:
	var root = Node3D.new()
	root.position = p
	root.rotation.y = angle
	root.scale = Vector3.ONE * size_factor
	parent.add_child(root)
	var wood = material("492b21",2)
	box(root,Vector3(0,2.1,-0.34),Vector3(4.8,4.2,0.18),wood)
	for x in [-2.4,2.4]: box(root,Vector3(x,2.1,0),Vector3(0.16,4.4,0.8),wood)
	for row in range(5):
		box(root,Vector3(0,0.22+row*1.0,0),Vector3(4.8,0.14,0.8),wood)
		if row == 4: continue
		for i in range(8):
			var book_height = 0.53 + fposmod(i*0.17+row*0.13,0.33)
			var col = ["554e3b","37433d","513b32","726650"][(i+row)%4]
			var b = box(root,Vector3(-2.05+i*0.56,0.29+row+book_height/2,0.13),Vector3(0.42,book_height,0.56),material(col))
			b.rotation.z = sin(i*3+row)*0.035
			box(root,Vector3(-2.05+i*0.56,0.44+row+book_height/2,0.417),Vector3(0.14,0.25,0.008),material("a99a7d"))
			var title = Label3D.new()
			title.text = ["论\n语","诗\n经","礼\n记","周\n易"][(i+row)%4]
			title.font = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
			title.font_size = 32
			title.pixel_size = 0.002
			title.outline_size = 0
			title.modulate = Color("3b3128")
			title.position = Vector3(-2.05+i*0.56,0.44+row+book_height/2,0.426)
			root.add_child(title)
			for binding in [0.12,0.32]:
				box(root,Vector3(-2.18+i*0.56,0.29+row+binding,0.419),Vector3(0.035,0.045,0.008),material("a99a7d"))
			for page in range(5):
				box(root,Vector3(-2.05+i*0.56,0.31+row+page*0.018,-0.08),Vector3(0.40,0.008,0.13),material("9b8d71"))

func lotus(parent: Node3D) -> void:
	var bronze = material("383a2c")
	var gold = material("655a3a")
	sphere(parent,Vector3(0,0.08,0),Vector3(0.48,0.12,0.48),bronze)
	sphere(parent,Vector3(0,0.24,0),Vector3(0.12,0.32,0.12),bronze)
	sphere(parent,Vector3(0,0.42,0),Vector3(0.62,0.19,0.62),bronze)
	for i in range(12):
		var angle = i * TAU / 12
		var petal = sphere(parent,Vector3(sin(angle)*0.25,0.49,cos(angle)*0.25),Vector3(0.18,0.28,0.08),gold)
		petal.rotation = Vector3(0,angle,0.28)
	var hoop = MeshInstance3D.new()
	var torus = TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.38
	hoop.mesh = torus
	hoop.material_override = bronze
	hoop.rotation.x = PI/2
	hoop.position.y = 0.81
	parent.add_child(hoop)
	sphere(parent,Vector3(0,0.7,0),Vector3(0.055,0.22,0.055),material("ffcb78",-1,1.2))

func build() -> void:
	built = true
	view = SubViewport.new()
	view.size = Vector2i(1600,900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	add_child(view)
	world = Node3D.new()
	view.add_child(world)
	architecture = Node3D.new()
	architecture.name = "FixedPhysicalArchitecture"
	world.add_child(architecture)
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("aeb6b0")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("dbd7c7")
	settings.ambient_light_energy = 0.32
	settings.fog_enabled = true
	settings.fog_density = 0.006
	settings.fog_light_color = Color("aeb6b0")
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	world.add_child(env)
	var sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-42,-32,0)
	sun.light_color = Color("ffe6bf")
	sun.light_energy = 0.8
	sun.shadow_enabled = true
	world.add_child(sun)
	var wood = material("492b21",2)
	var carved = material("806348",4)
	for id in app.core.graph.spatial.positions:
		var platform = Node3D.new()
		platform.name = "Platform_" + id
		platform.position = app.core.shadow_position(id)
		architecture.add_child(platform)
		var width: float = 10.0 if id == "B" else 8.8
		box(platform,Vector3(0,-0.25,0),Vector3(width,0.5,8.8),wood)
		for plank in range(12):
			box(platform,Vector3(-width/2+(plank+0.5)*width/12,0.018,0),Vector3(width/12-0.025,0.035,8.75),wood)
		for z in [-4.25,4.25]: box(platform,Vector3(0,-0.32,z),Vector3(width+0.15,0.55,0.16),carved)
		for x in [-3.9,3.9]:
			for z in [-3.9,3.9]:
				box(platform,Vector3(x,2.1,z),Vector3(0.22,4.2,0.22),wood)
				box(platform,Vector3(x,0.14,z),Vector3(0.42,0.28,0.42),material("78796b"))
		if id in ["B","C","F"]:
			roof(platform,4.2,10.1,10.0)
		else:
			for x in [-3.9,3.9]: box(platform,Vector3(x,3.55,0),Vector3(0.22,0.26,8.1),carved)
		if id != "F":
			for side in [-1,1]:
				beam(platform,Vector3(side*4.15,0.88,-4.1),Vector3(side*4.15,0.88,4.1),0.10,0.12,wood)
				for bar in range(12):
					box(platform,Vector3(side*4.15,0.45,-3.85+bar*0.7),Vector3(0.07,0.85,0.07),wood)
			bookcase(platform,Vector3(-2.5,0,-3.7),0,0.68)
			# Observation handles are physical props; Q/E operate this same pivot.
			if id != "D":
				var handle = Node3D.new()
				handle.position = Vector3(3.2,0,1.0) if id == "B" else Vector3(1.2,0,2.4)
				platform.add_child(handle)
				sphere(handle,Vector3(0,0.12,0),Vector3(0.65,0.24,0.65),material("777562"))
				box(handle,Vector3(0,0.6,0),Vector3(0.16,1.1,0.16),wood)
				var pivot = Node3D.new()
				handle.add_child(pivot)
				box(pivot,Vector3(0,1.14,0),Vector3(1.25,0.13,0.16),wood)
				handle_roots[id] = pivot
	# Suspended book stacks and stairs at several depths, all intact and stationary.
	bookcase(architecture,Vector3(8,0,2),-0.4,1.8)
	bookcase(architecture,Vector3(-23,7,-23),0.55,1.4)
	bookcase(architecture,Vector3(16,9,-32),-0.5,1.5)
	stairs(Vector3(-6,0,15),Vector3(-6,3,6),2.0)
	stairs(Vector3(16,6,-9),Vector3(16,10,-20),1.8)
	for edge in app.core.graph.edges:
		build_passage(edge)
	# False straight corridor at the hub: its capped end is visibly solid and never a graph edge.
	var hub: Vector3 = app.core.shadow_position("B")
	beam(architecture,hub+Vector3(0,0,0),hub+Vector3(0,0,-9),1.5,0.22,wood)
	beam(architecture,hub+Vector3(0,0.14,0),hub+Vector3(0,0.14,-8.5),0.7,0.035,material("13191b"))
	box(architecture,hub+Vector3(0,0.8,-9),Vector3(1.6,1.6,0.18),carved)
	build_room()
	build_lamp_station()
	camera = Camera3D.new()
	camera.fov = app.core.graph.spatial.fov
	camera.near = 0.07
	camera.far = 160
	world.add_child(camera)
	camera.current = true
	var gradient = GradientTexture2D.new()
	gradient.width = 4
	gradient.height = 256
	gradient.fill_from = Vector2(0,0)
	gradient.fill_to = Vector2(0,1)
	gradient.gradient = Gradient.new()
	gradient.gradient.colors = PackedColorArray([Color(0.025,0.04,0.04,0),Color(0.025,0.04,0.04,0.93)])
	var fade = TextureRect.new()
	fade.texture = gradient
	fade.position = Vector2(0,640)
	fade.size = Vector2(1600,260)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var title_shade = ColorRect.new()
	title_shade.color = Color(0.025,0.04,0.04,0.72)
	title_shade.position = Vector2(32,18)
	title_shade.size = Vector2(310,146)
	title_shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(title_shade)

func stairs(a: Vector3, b: Vector3, width: float) -> void:
	for i in range(15):
		var p = a.lerp(b,float(i)/14)
		box(architecture,p-Vector3(0,0.10,0),Vector3(width,0.2,abs(b.z-a.z)/14+0.035),material("492b21",2))
	for side in [-1,1]: beam(architecture,a+Vector3(side*width/2,-0.3,0),b+Vector3(side*width/2,-0.3,0),0.16,0.2,material("492b21",2))

func build_passage(edge: Dictionary) -> void:
	var p: Dictionary = app.core.shadow_edge_points(edge)
	var a: Vector3 = app.core.shadow_position(edge.fromNode)
	var b: Vector3 = app.core.shadow_position(edge.toNode)
	var near_elbow: Vector3 = p.a - p.lateral * 2.5 - Vector3(0,0.14,0)
	var far_elbow: Vector3 = p.b + p.lateral * 2.5 - Vector3(0,0.14,0)
	var wood = material("492b21",2)
	# The wooden stubs end BEFORE the projected join and remain visibly separate.
	beam(architecture,a,near_elbow,1.65,0.22,wood)
	beam(architecture,near_elbow,p.a-p.lateral*0.65-Vector3(0,0.14,0),1.65,0.22,wood)
	beam(architecture,b,far_elbow,1.65,0.22,wood)
	beam(architecture,far_elbow,p.b+p.lateral*0.65-Vector3(0,0.14,0),1.65,0.22,wood)
	var root = Node3D.new()
	root.name = "Ink_"+edge.id
	world.add_child(root)
	ink_roots[edge.id] = root
	update_ink(edge,0.52)
	var seam = MeshInstance3D.new()
	var marker = QuadMesh.new()
	marker.size = Vector2(0.7,0.025)
	seam.mesh = marker
	var gold = StandardMaterial3D.new()
	gold.albedo_color = Color("ffd18a")
	gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	gold.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	gold.cull_mode = BaseMaterial3D.CULL_DISABLED
	gold.no_depth_test = true
	gold.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	gold.render_priority = 100
	seam.material_override = gold
	world.add_child(seam)
	seam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	seam.visible = false
	seam_nodes[edge.id] = seam

func update_ink(edge: Dictionary, lamp: float) -> void:
	var root: Node3D = ink_roots[edge.id]
	for child in root.get_children():
		root.remove_child(child)
		child.queue_free()
	var p: Dictionary = app.core.shadow_edge_points(edge,lamp)
	var fixed: Dictionary = app.core.shadow_edge_points(edge)
	var ink = material("101718")
	var lift = Vector3(0,0.14,0)
	var a: Vector3 = app.core.shadow_position(edge.fromNode)+lift
	var b: Vector3 = app.core.shadow_position(edge.toNode)+lift
	# Only the last ink segment changes when the lamp is moved; floors are untouched.
	beam(root,a,fixed.a-fixed.lateral*2.5,0.84,0.035,ink)
	beam(root,fixed.a-fixed.lateral*2.5,p.a,0.84,0.035,ink)
	beam(root,b,fixed.b+fixed.lateral*2.5,0.84,0.035,ink)
	beam(root,fixed.b+fixed.lateral*2.5,p.b,0.84,0.035,ink)

func build_room() -> void:
	var room = Node3D.new()
	room.position = app.core.shadow_position("F")
	architecture.add_child(room)
	var wood = material("492b21",2)
	box(room,Vector3(0,1.75,-3.9),Vector3(7.8,3.5,0.18),wood)
	for x in [-3.9,3.9]: box(room,Vector3(x,1.75,0),Vector3(0.18,3.5,7.8),wood)
	for x in [-2.8,2.8]:
		box(room,Vector3(x,1.9,3.8),Vector3(2.0,3.4,0.1),material("c4a16b",-1,0.4))
		for i in range(6): box(room,Vector3(x-0.85+i*0.34,1.9,3.88),Vector3(0.045,3.4,0.05),wood)
	box(room,Vector3(0,0.85,-0.6),Vector3(3.4,0.16,1.65),wood)
	var lamp = Node3D.new()
	lamp.position = Vector3(-0.9,0.95,-0.5)
	room.add_child(lamp)
	lotus(lamp)
	var light = OmniLight3D.new()
	light.position = Vector3(-0.9,1.65,-0.5)
	light.light_color = Color("ffc47b")
	light.light_energy = 3.5
	light.omni_range = 8
	light.shadow_enabled = true
	room.add_child(light)
	# A quiet seated profile behind the lamp, intentionally a distant silhouette.
	var robe = material("303832")
	sphere(room,Vector3(0.9,1.25,-1.7),Vector3(0.75,1.4,0.65),robe)
	sphere(room,Vector3(0.9,2.12,-1.65),Vector3(0.37,0.46,0.38),material("8b7960"))
	box(room,Vector3(0.9,2.4,-1.68),Vector3(0.42,0.24,0.42),robe)
	sphere(room,Vector3(0.9,1.88,-1.39),Vector3(0.18,0.45,0.12),robe)
	beam(room,Vector3(0.6,1.7,-1.5),Vector3(0.1,1.05,-0.6),0.25,0.25,robe)

func build_lamp_station() -> void:
	var p: Vector3 = app.core.shadow_position("E")
	box(architecture,p+Vector3(2.1,0.68,-1.6),Vector3(2.5,0.15,1.1),material("492b21",2))
	beam(architecture,p+Vector3(1,0.79,-1.6),p+Vector3(3.2,0.79,-1.6),0.025,0.025,material("b69860"))
	lamp_root = Node3D.new()
	world.add_child(lamp_root)
	lotus(lamp_root)
	lamp_light = OmniLight3D.new()
	lamp_light.position = Vector3(0,0.7,0)
	lamp_light.light_color = Color("ffd294")
	lamp_light.light_energy = 0.75
	lamp_light.omni_range = 6
	lamp_light.shadow_enabled = true
	lamp_root.add_child(lamp_light)
	# Brush rest is the local shadow caster beside the oil-lamp rail.
	for x in [1.0,1.75]: box(architecture,p+Vector3(x,1.08,-2.25),Vector3(0.09,0.65,0.12),material("342c22"))
	beam(architecture,p+Vector3(0.85,1.4,-2.25),p+Vector3(1.9,1.4,-2.25),0.13,0.13,material("342c22"))
	for x in [1.15,1.45,1.7]: beam(architecture,p+Vector3(x,1.43,-2.55),p+Vector3(x,1.38,-1.9),0.035,0.035,material("b69b6d"))

func sync() -> void:
	var active: bool = app.mode == "ding_graph"
	visible = active
	if not active:
		if built: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if not built: build()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var s: Dictionary = app.core.state.shadow
	var angle: float = float(s.view) * PI/2
	var focus: Vector3 = app.core.shadow_camera_focus(s.node,int(s.view))
	if app.graph_rotating:
		angle = (app.graph_from_view + app.graph_turn_dir * app.graph_rotation) * PI/2
		focus = app.core.shadow_camera_focus(s.node,app.graph_from_view).lerp(focus,app.graph_rotation)
	var eye: Vector3 = app.core.shadow_camera_position(s.node,angle)
	if not app.travel_target.is_empty():
		var t = smoothstep(0,1,app.travel_t)
		var end_eye: Vector3 = app.core.shadow_camera_position(app.travel_target,float(s.view)*PI/2)
		if app.core.settings.reduced_motion:
			eye = end_eye if t > 0.5 else eye
		else:
			eye = crossing_eye(s.node,app.travel_target,eye,end_eye,t)
		focus = focus.lerp(app.core.shadow_camera_focus(app.travel_target,int(s.view)),t)
	if eye.distance_to(focus) > 0.01: camera.look_at_from_position(eye,focus,Vector3.UP)
	for id in handle_roots: handle_roots[id].rotation.y = angle if id == s.node else 0
	if not is_equal_approx(last_lamp,s.lamp):
		for edge in app.core.graph.edges:
			if edge.requiresLamp: update_ink(edge,s.lamp)
		last_lamp = s.lamp
	lamp_root.position = app.core.shadow_position("E") + Vector3(1.0 + s.lamp*2.2,0.79,-1.6)
	for edge in app.core.graph.edges:
		ink_roots[edge.id].visible = s.node in [edge.fromNode,edge.toNode]
		var seam: MeshInstance3D = seam_nodes[edge.id]
		var other: String = edge.toNode if s.node == edge.fromNode else edge.fromNode
		seam.visible = not app.busy and s.node in [edge.fromNode,edge.toNode] and other in app.core.shadow_edges(s.node,int(s.view),s.lamp)
		if seam.visible:
			var points: Dictionary = app.core.shadow_edge_points(edge,s.lamp)
			var p: Vector3 = points.a if s.node == edge.fromNode else points.b
			# Thin gold across the ink width, never outlining the entire solid bridge.
			seam.position = p+Vector3(0,0.02,0)

func crossing_eye(from_id: String, to_id: String, start: Vector3, finish: Vector3, t: float) -> Vector3:
	var edge: Dictionary = {}
	for candidate in app.core.graph.edges:
		if from_id in [candidate.fromNode,candidate.toNode] and to_id in [candidate.fromNode,candidate.toNode]:
			edge = candidate
			break
	var p: Dictionary = app.core.shadow_edge_points(edge,app.core.state.shadow.lamp)
	var eye_height = Vector3(0,app.core.graph.spatial.eyeHeight,0)
	var a: Vector3 = p.a
	var b: Vector3 = p.b
	var side: Vector3 = p.lateral
	if from_id != edge.fromNode:
		a = p.b; b = p.a; side = -side
	# Walk on the supported ink strips; only the registered seam permits a depth transfer.
	var first = [start,app.core.shadow_position(from_id)+eye_height,a-side*2.5+eye_height,a+eye_height]
	var second = [b+eye_height,b+side*2.5+eye_height,app.core.shadow_position(to_id)+eye_height,finish]
	var points: Array = first if t < 0.5 else second
	var fraction = clampf(t*2 if t < 0.5 else (t-0.5)*2,0,1) * 3
	var segment = mini(2,floori(fraction))
	return points[segment].lerp(points[segment+1],fraction-segment)
