extends Control
## Final act of the third memory. Follows existing dialogue cues; never grants items.
const ART = [
	preload("res://assets/wife-farewell/01-report.jpg"),
	preload("res://assets/wife-farewell/02-ink.jpg"),
	preload("res://assets/wife-farewell/03-dissolve.jpg"),
	preload("res://assets/wife-farewell/04-jade-whole.png"),
	preload("res://assets/wife-farewell/05-snow.jpg"),
	preload("res://assets/wife-farewell/06-empty.png")
]
const SHOTS = {"jade":3, "snow":4, "report":0, "eaves":0, "ink":1, "waiting":1, "dissolve":1, "vanish":2, "empty_place":5}
const EFFECT = preload("res://scripts/wife_farewell.gdshader")
var film: ShaderMaterial
var shot_state: Dictionary = {}

static func handles_route(route: String, dialogue_id: String, memory: String) -> bool:
	return (route == "dialogue" and dialogue_id == "WifeReflection") or route == "wife_shard" or (route == "fragment" and memory == "Wife")

func handles(app) -> bool:
	return handles_route(app.mode, app.core.state.dialogue.get("id", ""), app.core.state.memory)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	var screen = ColorRect.new()
	screen.size = Vector2(1600, 900)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	film = ShaderMaterial.new()
	film.shader = EFFECT
	screen.material = film
	add_child(screen)

func sync(app) -> void:
	visible = handles(app)
	if not visible: return
	var a = 5
	var b = 5
	var cue = "empty_place"
	var blend = 1.0
	var still: bool = app.core.settings.reduced_motion
	if app.mode == "dialogue":
		var lines: Array = app.core.dialogue.WifeReflection.lines
		var index: int = app.core.state.dialogue.index
		cue = lines[index].get("cue", "")
		b = int(SHOTS.get(cue, 5))
		a = int(SHOTS.get(lines[maxi(0, index - 1)].get("cue", ""), b))
		blend = smoothstep(0.0, 1.4 if cue == "empty_place" else 0.9, app.line_age)
		if still: a = b; blend = 1.0
	var clock: float = app.stage.clock
	shot_state = {"a":a, "b":b, "blend":blend, "cue":cue, "time":clock, "still":still}
	film.set_shader_parameter("image_a", ART[a])
	film.set_shader_parameter("image_b", ART[b])
	film.set_shader_parameter("shot_a", float(a))
	film.set_shader_parameter("shot_b", float(b))
	film.set_shader_parameter("blend_amount", blend)
	film.set_shader_parameter("film_time", clock)
	film.set_shader_parameter("motion_amount", 0.0 if still else 1.0)
	film.set_shader_parameter("ink_strength", 1.0 if cue == "dissolve" else 0.4)
	film.set_shader_parameter("footer", 0.75 if app.mode == "dialogue" else 0.35)
