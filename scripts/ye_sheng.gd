extends RefCounted
## Fixed Ye Sheng identity with authored action frames and feet-aligned playback.
const ATLAS: Texture2D = preload("res://assets/ye-sheng-actions.png")
const REGIONS = [
	Rect2(18, 0, 300, 364), Rect2(380, 0, 340, 364),
	Rect2(764, 0, 326, 364), Rect2(1115, 0, 333, 364),
	Rect2(12, 364, 340, 360), Rect2(380, 364, 340, 360),
	Rect2(740, 410, 368, 314), Rect2(1115, 380, 333, 344),
	Rect2(0, 724, 350, 362), Rect2(362, 724, 456, 362),
	Rect2(768, 724, 324, 362), Rect2(1115, 724, 333, 362),
]
const FEET = [
	Vector2(207, 359), Vector2(556, 359), Vector2(940, 359), Vector2(1290, 359),
	Vector2(210, 718), Vector2(565, 708), Vector2(946, 715), Vector2(1295, 715),
	Vector2(181, 1072), Vector2(535, 1072), Vector2(938, 1072), Vector2(1290, 1072),
]
const PIXEL_SCALE = 0.35
const SWEEP_POLYGON = [Vector2(362, 724), Vector2(724, 724), Vector2(724, 888), Vector2(818, 888), Vector2(818, 950), Vector2(724, 950), Vector2(724, 1086), Vector2(362, 1086)]
const RECOVER_POLYGON = [Vector2(768, 724), Vector2(1092, 724), Vector2(1092, 1086), Vector2(768, 1086), Vector2(768, 950), Vector2(818, 950), Vector2(818, 888), Vector2(768, 888)]

static func frame_for(pose: String, time: float, reduced_motion: bool) -> int:
	match pose:
		"run": return 1 if reduced_motion else [1, 2, 3, 4][int(time * 9.0) % 4]
		"jump": return 5
		"slide", "dodge": return 6
		"brace": return 7
		"brush_prepare": return 8
		"brush": return 9
		"brush_recover": return 10
		"hit": return 11
	return 0

static func paint(canvas: CanvasItem, position: Vector2, scale_value: float, pose: String, time: float, facing_left: bool, alpha: float, reduced_motion: bool) -> void:
	var frame := frame_for(pose, time, reduced_motion)
	var region: Rect2 = REGIONS[frame]
	var bob := -absf(sin(time * 9.0 * PI / 2.0)) * 1.5 if pose == "run" and not reduced_motion else 0.0
	var breath := sin(time * 2.2) * 0.004 if pose == "stand" and not reduced_motion else 0.0
	if pose != "jump":
		canvas.draw_set_transform(position, 0, Vector2(scale_value, scale_value * 0.21))
		canvas.draw_circle(Vector2.ZERO, 27, Color(0.14, 0.17, 0.17, alpha * 0.15))
		canvas.draw_circle(Vector2.ZERO, 18, Color(0.14, 0.17, 0.17, alpha * 0.10))
	canvas.draw_set_transform(position + Vector2(0, bob * scale_value), 0, Vector2(-scale_value if facing_left else scale_value, scale_value * (1.0 + breath)))
	var destination := Rect2((region.position - FEET[frame]) * PIXEL_SCALE, region.size * PIXEL_SCALE)
	if frame in [9, 10]:
		# Follow the brush silhouette between the two adjacent atlas frames.
		# A rectangular crop here would include part of the neighboring figure.
		var outline := SWEEP_POLYGON if frame == 9 else RECOVER_POLYGON
		var points := PackedVector2Array()
		var uv := PackedVector2Array()
		for vertex in outline:
			points.append((vertex - FEET[frame]) * PIXEL_SCALE)
			uv.append(vertex / ATLAS.get_size())
		canvas.draw_polygon(points, PackedColorArray([Color(1, 1, 1, alpha)]), uv, ATLAS)
	else:
		canvas.draw_texture_rect_region(ATLAS, destination, region, Color(1, 1, 1, alpha))
	canvas.draw_set_transform(Vector2.ZERO)
