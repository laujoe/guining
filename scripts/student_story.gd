extends Control
## Chapter two illustration staging; no narrative events or rewards are issued here.
const ART = [
	preload("res://assets/student-story/01-intro.png"),
	preload("res://assets/student-story/02-review.jpg"),
	preload("res://assets/student-story/03-unroll.jpg"),
	preload("res://assets/student-story/04-farewell.png")
]
const EFFECT = preload("res://scripts/student_story.gdshader")
# The complete reference frame occupies 1344 x 756, leaving room for dialogue.
const PAPER_RECT = Rect2(795, 674, 350, 35)
var screen: ColorRect
var film: ShaderMaterial
var shot_state: Dictionary = {}

static func dialogue_handles(id: String) -> bool:
	return id in ["StudentIntro", "StudentReview", "StudentReflection", "StudentShardEcho"]

static func handles_route(route: String, id: String, memory: String) -> bool:
	return (route == "dialogue" and dialogue_handles(id)) or (memory == "Student" and route in ["review", "student_shard", "fragment"])

static func title_for(id: String) -> String:
	return {"StudentIntro":"门前递卷", "StudentReview":"灯下批改", "StudentReflection":"卷中真意", "StudentShardEcho":"门前回望"}.get(id, "灯下批改")

func handles(app) -> bool:
	return handles_route(app.mode, app.core.state.dialogue.get("id", ""), app.core.state.memory)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	screen = ColorRect.new()
	screen.size = Vector2(1600, 900)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film = ShaderMaterial.new()
	film.shader = EFFECT
	screen.material = film
	add_child(screen)

func sync(app) -> void:
	visible = handles(app)
	if not visible: return
	var id: String = app.core.state.dialogue.get("id", "")
	var still: bool = app.core.settings.reduced_motion
	var a = 0
	var b = 0
	var blend = 0.0
	if app.mode == "review" or id == "StudentReview":
		a = 1; b = 1
	elif id == "StudentReflection":
		a = 1; b = 2
		blend = smoothstep(0.0, 1.1, app.scene_age)
	elif app.mode == "student_shard":
		a = 2; b = 2
	elif id == "StudentShardEcho":
		a = 2; b = 3
		blend = smoothstep(0.0, 1.1, app.scene_age)
	elif app.mode == "fragment":
		a = 3; b = 3
	if still: blend = 1.0
	var clock: float = app.stage.clock
	# Keep the actual paper stationary during mouse interaction.
	var zoom = 1.0 if still or app.mode == "review" else 1.006 + sin(clock * 0.045) * 0.004
	shot_state = {"a":a, "b":b, "blend":blend, "clock":clock, "still":still, "zoom":zoom}
	film.set_shader_parameter("image_a", ART[a])
	film.set_shader_parameter("image_b", ART[b])
	film.set_shader_parameter("shot_a", float(a))
	film.set_shader_parameter("shot_b", float(b))
	film.set_shader_parameter("blend_amount", blend)
	film.set_shader_parameter("film_time", clock)
	film.set_shader_parameter("motion_amount", 0.0 if still else 1.0)
	film.set_shader_parameter("zoom", zoom)

func draw_foreground(s) -> void:
	if s.app.mode == "review":
		var r: Rect2 = PAPER_RECT
		# A quiet underline shows the part of the paper that accepts a brush stroke.
		s.draw_line(Vector2(r.position.x, r.end.y), r.end, Color("d1a567", 0.7), 2, true)
		if s.app.stroke_points.size() > 1:
			s.draw_polyline(s.app.stroke_points, Color("9c4637"), 3, true)
	elif s.app.mode in ["student_shard", "fragment"]:
		s.draw_jade_fragment_at(Vector2(1490, 560), 1, 0.7, true)
