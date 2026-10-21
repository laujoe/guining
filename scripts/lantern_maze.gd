extends SubViewportContainer
## Real perspective, opaque architecture and one finite, shadow-casting lamp.
const Core = preload("res://scripts/game_core.gd")
const SURFACE = preload("res://scripts/lantern_surface.gdshader")
const ECHO = preload("res://scripts/lantern_echo.gdshader")
var app
var view: SubViewport
var world: Node3D
var camera: Camera3D
var lamp: OmniLight3D
var echo: MeshInstance3D
var echo_material: ShaderMaterial
var materials: Dictionary = {}
var stride = 0.0
var walking = false
var sway = Vector2.ZERO
var shown = false
var built = false

func _ready() -> void:
	name = "LanternMaze"
	position = Vector2.ZERO
	size = Vector2(1600, 900)
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = false

func material(color: String, kind: int) -> ShaderMaterial:
	var key = color + str(kind)
	if materials.has(key): return materials[key]
	var mat = ShaderMaterial.new()
	mat.shader = SURFACE
	mat.set_shader_parameter("pigment", Color(color))
	mat.set_shader_parameter("kind", kind)
	mat.set_shader_parameter("atlas", preload("res://assets/lantern-materials-v1.png"))
	materials[key] = mat
	return mat

func box(parent: Node3D, p: Vector3, dimensions: Vector3, mat: Material) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	var mesh = BoxMesh.new()
	mesh.size = dimensions
	node.mesh = mesh
	node.material_override = mat
	node.position = p
	parent.add_child(node)
	return node

func build() -> void:
	built = true
	view = SubViewport.new()
	view.size = Vector2i(1600, 900)
	view.own_world_3d = true
	view.msaa_3d = Viewport.MSAA_2X
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	world = Node3D.new()
	view.add_child(world)
	var env = WorldEnvironment.new()
	var settings = Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color.BLACK
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_DISABLED
	# Default reflection samples the pure black background; there is no sky or probe.
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	world.add_child(env)
	var stone = material("65706e", 1)
	var brick = material("64716f", 0)
	var wood = material("492b21", 2)
	var darkwood = material("281b16", 2)
	var gold = material("998053", 3)
	var carved = material("806348", 4)
	var c: float = Core.MAZE_CELL
	box(world, Vector3(18.2, -0.12, 15.4), Vector3(36.4, 0.24, 30.8), stone)
	for z in range(Core.MAZE.size()):
		for x in range(Core.MAZE[z].length()):
			if not app.core.maze_wall(Vector2i(x, z)):
				var p = Vector3((x + 0.5) * c, 3.68, (z + 0.5) * c)
				var horizontal: bool = app.core.maze_wall(Vector2i(x, z - 1)) or app.core.maze_wall(Vector2i(x, z + 1))
				box(world, p, Vector3(0.22, 0.24, c) if horizontal else Vector3(c, 0.24, 0.22), wood)
				continue
			var exposed = false
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if not app.core.maze_wall(Vector2i(x, z) + direction): exposed = true
			if not exposed: continue
			var center = Vector3((x + 0.5) * c, 1.95, (z + 0.5) * c)
			box(world, center, Vector3(c, 3.9, c), brick)
			for direction in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
				if app.core.maze_wall(Vector2i(x, z) + direction): continue
				var facade = Node3D.new()
				facade.position = Vector3(center.x, 0, center.z) + Vector3(direction.x, 0, direction.y) * c * 0.5
				facade.rotation.y = atan2(direction.x, direction.y)
				world.add_child(facade)
				# All decoration protrudes <0.2 m: protected by the core's 0.28 m body radius.
				box(facade, Vector3(0, 0.18, 0.035), Vector3(c, 0.36, 0.07), stone)
				box(facade, Vector3(0, 3.25, 0.08), Vector3(c, 0.28, 0.16), carved)
				box(facade, Vector3(0, 3.63, 0.10), Vector3(c, 0.12, 0.2), darkwood)
				for side in [-1, 1]:
					var p = side * (c * 0.5 - 0.17)
					var pillar = MeshInstance3D.new()
					var mesh = CylinderMesh.new()
					mesh.top_radius = 0.16
					mesh.bottom_radius = 0.18
					mesh.height = 3.35
					mesh.radial_segments = 16
					pillar.mesh = mesh
					pillar.material_override = wood
					pillar.position = Vector3(p, 1.85, 0)
					facade.add_child(pillar)
					box(facade, Vector3(p, 0.22, 0), Vector3(0.36, 0.44, 0.36), stone)
					box(facade, Vector3(p, 3.04, 0.07), Vector3(0.5, 0.12, 0.16), gold)
				# Fitted wooden screens alternate with intact brick courtyard walls.
				if (x + z) % 3 == 0 and Vector2i(x, z) != Core.MAZE_EXIT + Vector2i.DOWN:
					box(facade, Vector3(0, 1.75, 0.02), Vector3(2.12, 2.35, 0.04), darkwood)
					for side in [-1, 1]:
						box(facade, Vector3(side * 1.04, 1.75, 0.08), Vector3(0.09, 2.4, 0.12), gold)
					for row in range(7):
						box(facade, Vector3(0, 0.8 + row * 0.32, 0.07), Vector3(2.04, 0.035, 0.07), wood)
					for column in range(7):
						box(facade, Vector3(-0.96 + column * 0.32, 1.75, 0.07), Vector3(0.035, 2.2, 0.07), wood)
				# Carved geometric frieze under the heavy eaves.
				for ornament in range(5):
					var ornament_node = box(facade, Vector3(-0.88 + ornament * 0.44, 3.46, 0.11), Vector3(0.16, 0.16, 0.045), gold)
					ornament_node.rotation.z = PI / 4
	camera = Camera3D.new()
	camera.fov = 67
	camera.near = 0.06
	camera.far = 25
	world.add_child(camera)
	camera.current = true
	lamp = OmniLight3D.new()
	lamp.name = "OnlyLight_LotusFlame"
	lamp.light_color = Color("ffc477")
	lamp.light_energy = 1.9
	lamp.omni_range = 4.8
	lamp.omni_attenuation = 1.55
	lamp.shadow_enabled = true
	lamp.shadow_bias = 0.025
	camera.add_child(lamp)
	echo = MeshInstance3D.new()
	var quad = QuadMesh.new()
	quad.size = Vector2(2.45, 2.45)
	echo.mesh = quad
	echo.position = Vector3((Core.MAZE_EXIT.x + 0.5) * c, 1.85, (Core.MAZE_EXIT.y + 1) * c - 0.12)
	echo.rotation.y = PI
	echo_material = ShaderMaterial.new()
	echo_material.shader = ECHO
	echo_material.set_shader_parameter("frames", preload("res://assets/lantern-echo-v1.png"))
	echo.material_override = echo_material
	echo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	world.add_child(echo)
	var vignette = ColorRect.new()
	vignette.size = Vector2(1600, 900)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fade = ShaderMaterial.new()
	fade.shader = preload("res://scripts/lantern_vignette.gdshader")
	vignette.material = fade
	# Child Controls of a SubViewportContainer are independent of its 3D world.
	add_child(vignette)

func sync(delta: float) -> void:
	var active: bool = app.mode == "ding_lamp"
	visible = active
	if not active:
		if built: view.render_target_update_mode = SubViewport.UPDATE_DISABLED
		return
	if not built: build()
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var m: Dictionary = app.core.state.lantern_maze
	var reduced: bool = app.core.settings.reduced_motion
	if not app.paused and walking: stride += delta * 6.3
	var target_sway = Vector2(sin(stride) * 0.018, cos(stride * 2) * 0.012) if walking and not reduced else Vector2.ZERO
	if not app.paused: sway = sway.lerp(target_sway, minf(1, delta * 9))
	var yaw: float = m.yaw
	if m.phase != "explore":
		# Turn gently to the wall after crossing; reduced motion uses a cut.
		yaw = lerp_angle(yaw, PI, 1.0 if reduced else smoothstep(0, 0.6, m.echo_time))
	camera.position = Vector3(m.x, 1.68 + sway.y, m.z)
	camera.rotation = Vector3(-0.035, -yaw + sway.x * 0.4, 0)
	lamp.position = Vector3(0.44 + sway.x * 1.8, -0.32 + sway.y * 1.5, -0.5)
	lamp.light_energy = 1.9 if reduced else 1.9 + sin(app.scene_age * 4.1) * 0.035
	echo.visible = m.phase == "echo"
	echo_material.set_shader_parameter("age", m.echo_time)
