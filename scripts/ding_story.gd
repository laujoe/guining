extends Control
## Authored first-memory shots. Presentation only; dialogue and rewards stay in core.
const ART = [
	preload("res://assets/ding-story/01-offer.jpg"),
	preload("res://assets/ding-story/02-rest.jpg"),
	preload("res://assets/ding-story/03-empty.png"),
	preload("res://assets/ding-story/04-rain.jpg")
]
const EFFECT = preload("res://scripts/ding_story.gdshader")
var screen: ColorRect
var film: ShaderMaterial
var shot_state: Dictionary = {}

static func dialogue_handles(id: String) -> bool:
	return id in ["DingDinner", "DingPastChoice", "DingReflection", "DingShardEcho"]

static func handles_route(route: String, dialogue_id: String, memory: String) -> bool:
	return route in ["ding_table", "ding_place", "ding_seat", "ding_shard"] or (route == "dialogue" and dialogue_handles(dialogue_id)) or (route == "fragment" and memory == "Ding")

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
	var still: bool = app.core.settings.reduced_motion
	var age: float = app.scene_age
	var id: String = app.core.state.dialogue.get("id", "")
	var a = 2
	var b = 2
	var blend = 0.0
	var darkness = 0.0
	match app.mode:
		"ding_table":
			a = 2
			b = 0
			blend = smoothstep(4.6, 5.8, age)
			darkness = 1.0 - smoothstep(0.0, 1.5 if not still else 0.25, age)
		"ding_place": a = 0; b = 0
		"ding_seat": a = 1; b = 1
		"fragment": a = 3; b = 3
		"dialogue":
			match id:
				"DingDinner":
					a = 0
					b = 1
					blend = 1.0 if int(app.core.state.dialogue.index) > 0 else smoothstep(0.35, 1.4, age)
				"DingPastChoice": a = 1; b = 1
				"DingReflection":
					a = 1
					b = 2
					blend = smoothstep(0.0, 1.2, age)
				"DingShardEcho":
					a = 2
					b = 3
					blend = smoothstep(0.0, 1.2, age)
	if still:
		blend = 1.0 if blend >= 0.5 else 0.0
	# The clock is stage-owned and pauses with menus; no shader TIME is used.
	var clock: float = app.stage.clock
	var zoom = 1.0 if still else 1.015 + sin(clock * 0.035) * 0.008
	shot_state = {"a":a, "b":b, "blend":blend, "clock":clock, "still":still, "zoom":zoom}
	film.set_shader_parameter("image_a", ART[a])
	film.set_shader_parameter("image_b", ART[b])
	film.set_shader_parameter("shot_a", float(a))
	film.set_shader_parameter("shot_b", float(b))
	film.set_shader_parameter("blend_amount", blend)
	film.set_shader_parameter("film_time", clock)
	film.set_shader_parameter("motion_amount", 0.0 if still else 1.0)
	film.set_shader_parameter("zoom", zoom)
	film.set_shader_parameter("darkness", darkness)
	film.set_shader_parameter("footer", 0.84 if app.mode == "dialogue" else 0.40)
