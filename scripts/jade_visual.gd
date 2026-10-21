extends RefCounted
## Canonical reference texture and shared fracture map for every jade clue.
const FRONT = preload("res://assets/jade/front.png")
const BACK = preload("res://assets/jade/back.png")
const RADIUS = 140.0
const HOLE_RATIO = 0.267
const SOURCE = Rect2(0.05, 0.042, 0.90, 0.916)
const ARC_STEPS = 64

static func fracture(boundary: int, radius: float = RADIUS) -> PackedVector2Array:
	var angle = -PI / 2 + posmod(boundary, 3) * TAU / 3
	var radial = Vector2.from_angle(angle)
	var tangent = radial.orthogonal()
	var points = PackedVector2Array([radial * radius])
	for step in range(3):
		points.append(radial * radius * [0.83, 0.65, 0.47][step] + tangent * [-5.0, 8.0, -4.0][step] * (1.0 + posmod(boundary, 3) * 0.25) * radius / RADIUS)
	points.append(radial * radius * HOLE_RATIO)
	return points

static func polygon(id: int, radius: float = RADIUS) -> PackedVector2Array:
	var points = PackedVector2Array()
	var start = -PI / 2 + id * TAU / 3
	for i in range(ARC_STEPS + 1):
		points.append(Vector2.from_angle(start + i / float(ARC_STEPS) * TAU / 3) * radius)
	var right = fracture(id + 1, radius)
	for i in range(1, right.size()): points.append(right[i])
	for i in range(ARC_STEPS - 1, -1, -1):
		points.append(Vector2.from_angle(start + i / float(ARC_STEPS) * TAU / 3) * radius * HOLE_RATIO)
	var left = fracture(id, radius)
	for i in range(left.size() - 2, 0, -1): points.append(left[i])
	return points

static func piece_center(id: int) -> Vector2:
	return Vector2.from_angle(-PI / 2 + (id + 0.5) * TAU / 3) * RADIUS * 0.56

static func paint_piece(canvas: CanvasItem, center: Vector2, id: int, scale_value: Vector2, filled: bool = true, back: bool = false, seam_alpha: float = 0.65) -> void:
	canvas.draw_set_transform(center, 0, scale_value)
	var points = polygon(id)
	if filled:
		var uv = PackedVector2Array()
		for point in points:
			uv.append(SOURCE.position + (point / (RADIUS * 2) + Vector2(0.5, 0.5)) * SOURCE.size)
		canvas.draw_polygon(points, PackedColorArray([Color.WHITE]), uv, BACK if back else FRONT)
		for boundary in [id, id + 1]:
			var crack = fracture(boundary)
			canvas.draw_polyline(crack, Color(0.27, 0.26, 0.17, seam_alpha), 0.7, true)
	else:
		canvas.draw_polyline(points + PackedVector2Array([points[0]]), Color(0.75, 0.78, 0.65, 0.48), 1.0 / maxf(scale_value.y, 0.1), true)
	canvas.draw_set_transform(Vector2.ZERO)

static func paint_whole(canvas: CanvasItem, center: Vector2, scale_value: float) -> void:
	# The gift predates the accident: no fracture seams in this shot.
	for id in range(3):
		paint_piece(canvas, center, id, Vector2.ONE * scale_value, true, false, 0.0)
