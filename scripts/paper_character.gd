extends RefCounted
## Fixed folded-paper model for paper soldiers and anonymous background figures.
## Regions are deliberately wider than grid cells for the brush's full tip.
const ATLAS: Texture2D = preload("res://assets/paper-people.png")
const REGIONS = [
	Rect2(100, 38, 240, 398), Rect2(505, 38, 305, 398),
	Rect2(940, 38, 320, 398), Rect2(1435, 30, 300, 370),
	Rect2(60, 548, 350, 294), Rect2(490, 473, 380, 370),
	Rect2(918, 473, 490, 370), Rect2(1435, 465, 300, 380),
]
const FEET = [
	Vector2(224, 424), Vector2(660, 425), Vector2(1090, 426), Vector2(1585, 382),
	Vector2(245, 831), Vector2(656, 832), Vector2(1070, 832), Vector2(1580, 832),
]
const PIXEL_SCALE = 0.30

static func frame_for(pose: String, time: float, reduced_motion: bool) -> int:
	match pose:
		"run": return 1 if reduced_motion else [1, 0, 2, 0][int(time * 10.0) % 4]
		"jump": return 3
		"slide", "dodge": return 4
		"brace": return 5
		"brush": return 6
		"guard": return 7
	return 0

static func paint(canvas: CanvasItem, position: Vector2, scale_value: float, pose: String, time: float, facing_left: bool, tint: Color, reduced_motion: bool, shadow = true) -> void:
	var frame := frame_for(pose, time, reduced_motion)
	var region: Rect2 = REGIONS[frame]
	var moving := pose == "run"
	var bob := -absf(sin(time * 10.0 * PI / 2.0)) * 2.2 if moving and not reduced_motion else 0.0
	var lean := sin(time * 4.0) * 0.014 if pose == "stand" and not reduced_motion else 0.0
	if shadow and pose != "jump":
		canvas.draw_set_transform(position, 0, Vector2(scale_value, scale_value * 0.22))
		canvas.draw_circle(Vector2.ZERO, 28, Color(0.18, 0.16, 0.12, tint.a * 0.13))
		canvas.draw_circle(Vector2.ZERO, 19, Color(0.18, 0.16, 0.12, tint.a * 0.09))
	canvas.draw_set_transform(position + Vector2(0, bob * scale_value), lean, Vector2(-scale_value if facing_left else scale_value, scale_value))
	var destination := Rect2((region.position - FEET[frame]) * PIXEL_SCALE, region.size * PIXEL_SCALE)
	canvas.draw_texture_rect_region(ATLAS, destination, region, tint)
	canvas.draw_set_transform(Vector2.ZERO)
