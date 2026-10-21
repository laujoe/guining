extends Control
## Illustrated ending. All motion is driven by the paused story clock, never TIME.
## This presentation owns no rewards, saves, or narrative events.
const ACCIDENT_DURATION = 35.0
const REVEAL_DURATION = 18.0
const MEMORY_SHOT_DURATION = 8.0
const MEMORY_DURATION = MEMORY_SHOT_DURATION * 4
const BODY_DURATION = REVEAL_DURATION
const ART = [
	preload("res://assets/ending/01-crossing.png"),
	preload("res://assets/ending/02-overboard.png"),
	preload("res://assets/ending/03-shore-jade.png"),
	preload("res://assets/ending/04-soul-jade.png"),
	preload("res://assets/ending/05-supper-arrives.png"),
	preload("res://assets/ending/06-student-scroll.png"),
	preload("res://assets/ending/07-old-friend.png"),
	preload("res://assets/ending/08-home-supper.png"),
	preload("res://assets/ending/09-first-person-river.png")
]
const EFFECT = preload("res://scripts/ending_sequence.gdshader")
var screen: ColorRect
var caption: Label
var chapter: Label
var shader_material: ShaderMaterial
var shot_a = -1
var shot_b = -1
var film_time = 0.0
var rain_strength = 0.0
var still = false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	show_behind_parent = true
	screen = ColorRect.new()
	screen.size = Vector2(1600, 900)
	screen.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shader_material = ShaderMaterial.new()
	shader_material.shader = EFFECT
	screen.material = shader_material
	add_child(screen)
	chapter = make_label(Rect2(68, 21, 1100, 40), 20)
	chapter.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	chapter.add_theme_color_override("font_color", Color("cdbb9d"))
	caption = make_label(Rect2(180, 775, 1240, 100), 29)
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER

func make_label(rect: Rect2, font_size: int) -> Label:
	var node = Label.new()
	node.position = rect.position
	node.size = rect.size
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	node.add_theme_color_override("font_color", Color("eee8dc"))
	node.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	node.add_theme_constant_override("shadow_offset_y", 2)
	node.add_theme_font_size_override("font_size", font_size)
	add_child(node)
	return node

func handles(route: String) -> bool:
	return route in ["accident_prompt", "accident", "body", "release", "release_echo", "finale"]

func sync(app) -> void:
	visible = handles(app.mode)
	if not visible: return
	still = app.core.settings.reduced_motion
	var age: float = app.scene_age
	var a = 0
	var b = 0
	var blend = 0.0
	var camera_a = Vector3(0.5, 0.5, 1.04)
	var camera_b = camera_a
	var darkness = 0.0
	var words = ""
	var caption_alpha = 1.0
	film_time = age
	rain_strength = 0.18
	chapter.text = "终章  /  水中捷报"
	match app.mode:
		"accident_prompt":
			darkness = 0.6
			words = ""
			caption_alpha = smoothstep(0.0, 0.8, age)
		"accident":
			age = app.accident_time
			film_time = age
			a = 0
			b = 8
			blend = smoothstep(9.0, 11.5, age)
			camera_a = Vector3(lerpf(0.5, 0.465, clampf(age / 11.5, 0, 1)), 0.5, lerpf(1.04, 1.12, clampf(age / 11.5, 0, 1)))
			var fall = clampf((age - 9) / 24, 0, 1)
			camera_b = Vector3(0.5 + app.accident_x * 0.00012, lerpf(0.49, 0.46, fall), lerpf(1.04, 1.11, fall))
			rain_strength = lerpf(0.18, 0.42, blend)
			darkness = maxf(0.6 * (1 - smoothstep(0.0, 1.5, age)), smoothstep(29.0, ACCIDENT_DURATION, age))
			if age < 8.5:
				words = ""
				caption_alpha = cue_alpha(age, 1.5, 8.5)
			elif age < 18:
				words = ""
				caption_alpha = cue_alpha(age, 11.5, 18)
			elif age < 27:
				words = ""
				caption_alpha = cue_alpha(age, 19, 27)
			else:
				words = ""
				caption_alpha = cue_alpha(age, 28, 34)
		"body":
			film_time = ACCIDENT_DURATION + age
			a = 2
			b = 3
			blend = smoothstep(7.0, 10.0, age)
			camera_a = Vector3(0.5, 0.5, lerpf(1.035, 1.09, clampf(age / 10, 0, 1)))
			camera_b = Vector3(0.5, 0.5, lerpf(1.10, 1.035, clampf((age - 7) / 11, 0, 1)))
			darkness = 1 - smoothstep(0.0, 1.8, age)
			rain_strength = lerpf(0.18, 0.07, blend)
			if age < 7:
				words = "村民把叶生的遗体捞上岸。"
				caption_alpha = cue_alpha(age, 1.8, 7)
			elif age < 12.5:
				words = "捷报糊在他怀中，玉佩从衣袋滑落。"
				caption_alpha = cue_alpha(age, 7.5, 12.5)
			else:
				words = ""
				caption_alpha = cue_alpha(age, 13, REVEAL_DURATION)
		"release", "release_echo":
			a = 0
			b = 0
			film_time = ACCIDENT_DURATION + BODY_DURATION + age
			camera_a = Vector3(0.68, 0.48, 1.6)
			camera_b = camera_a
			darkness = 0.28
			rain_strength = 0.0
			chapter.text = ""
		"finale":
			# The supplied script puts these scenes AFTER the player's active reply.
			# Ding shares a meal, Zaichang receives the report, then wife joins him.
			var cuts = [0.0, 8.0, 16.0, 21.0]
			var shots = [6, 5, 4, 7]
			var index = 0
			for i in range(1, cuts.size()):
				if age >= cuts[i]: index = i
			var local_age: float = age - cuts[index]
			a = shots[maxi(0, index - 1)]
			b = shots[index]
			blend = 1.0 if index == 0 else smoothstep(0.0, 1.8, local_age)
			camera_a = memory_camera(a, MEMORY_SHOT_DURATION)
			camera_b = memory_camera(b, local_age)
			darkness = 0.4 * (1 - smoothstep(0.0, 2.0, age))
			rain_strength = 0.0
			chapter.text = ""
	if still:
		camera_a = Vector3(0.5, 0.5, 1.035)
		camera_b = camera_a
	if a != shot_a:
		shader_material.set_shader_parameter("image_a", ART[a])
		shot_a = a
	if b != shot_b:
		shader_material.set_shader_parameter("image_b", ART[b])
		shot_b = b
	shader_material.set_shader_parameter("shot_a", float(a))
	shader_material.set_shader_parameter("shot_b", float(b))
	shader_material.set_shader_parameter("camera_a", camera_a)
	shader_material.set_shader_parameter("camera_b", camera_b)
	shader_material.set_shader_parameter("blend_amount", blend)
	shader_material.set_shader_parameter("film_time", film_time)
	shader_material.set_shader_parameter("motion_amount", 0.0 if still else 1.0)
	shader_material.set_shader_parameter("darkness", darkness)
	shader_material.set_shader_parameter("rain_strength", rain_strength)
	caption.text = words
	caption.modulate.a = caption_alpha
	caption.add_theme_font_size_override("font_size", roundi(29 * app.core.settings.text_scale))
	queue_redraw()

func cue_alpha(t: float, start: float, end: float) -> float:
	return smoothstep(start, start + 0.8, t) * (1 - smoothstep(end - 0.8, end, t))

func memory_camera(shot: int, age: float) -> Vector3:
	var progress = smoothstep(0.0, MEMORY_SHOT_DURATION, age)
	match shot:
		4: return Vector3(lerpf(0.51, 0.49, progress), 0.49, lerpf(1.035, 1.09, progress))
		5: return Vector3(lerpf(0.49, 0.52, progress), 0.5, lerpf(1.035, 1.085, progress))
		6: return Vector3(lerpf(0.51, 0.49, progress), 0.5, lerpf(1.035, 1.075, progress))
		_: return Vector3(0.5, 0.49, lerpf(1.035, 1.08, progress))
