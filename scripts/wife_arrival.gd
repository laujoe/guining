extends Control
## Third memory, act one. Original illustrations plus pause-aware local motion.
## Presentation only: narrative events and rewards remain in the existing flow.
const DURATION = 18.0
const ART = [
	preload("res://assets/wife-arrival/01-homeward.png"),
	preload("res://assets/wife-arrival/02-reunion.png"),
	preload("res://assets/wife-arrival/03-wind.png")
]
const EFFECT = preload("res://scripts/wife_arrival.gdshader")
var film: ShaderMaterial
var shot_state: Dictionary = {}

static func handles_route(route: String, dialogue_id: String) -> bool:
	return route == "wife_arrival" or (route == "dialogue" and dialogue_id == "WifeDeparture")

func handles(app) -> bool:
	return handles_route(app.mode, app.core.state.dialogue.get("id", ""))

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
	var dialogue: bool = app.mode == "dialogue"
	var age: float = DURATION + app.scene_age if dialogue else app.scene_age
	var still: bool = app.core.settings.reduced_motion
	var a = 0
	var b = 1
	var blend = smoothstep(5.5, 6.7, age)
	if age >= 6.7:
		a = 1
		b = 2
		blend = smoothstep(11.4, 12.4, age)
	if age >= 12.4:
		a = 2
		b = 2
		blend = 0.0
	if still: blend = 1.0 if blend >= 0.5 else 0.0
	shot_state = {"a":a, "b":b, "blend":blend, "time":age, "still":still}
	film.set_shader_parameter("image_a", ART[a])
	film.set_shader_parameter("image_b", ART[b])
	film.set_shader_parameter("shot_a", float(a))
	film.set_shader_parameter("shot_b", float(b))
	film.set_shader_parameter("blend_amount", blend)
	film.set_shader_parameter("film_time", age)
	film.set_shader_parameter("motion_amount", 0.0 if still else 1.0)
	film.set_shader_parameter("darkness", 0.0 if dialogue else 1.0 - smoothstep(0.0, 0.8, age))
	film.set_shader_parameter("footer", 0.8 if dialogue else 0.28)
