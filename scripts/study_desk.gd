extends RefCounted
## Chapter two's reference-based desk art; visual only, no input or game state.
const PROPS = preload("res://assets/study-props.png")
const MODES = ["army", "dragon", "review"]

static func backdrop(s: Control) -> void:
	if not s.mode in MODES:
		return
	s.draw_rect(Rect2(0, 145, 1600, 755), Color("695748"))
	for i in range(16):
		var y = 155 + i * 49
		s.draw_line(Vector2(0, y), Vector2(1600, y + 5), Color("4d4239"), 2, true)
		for j in range(4):
			var x = 40 + j * 430 + (i % 3) * 19
			s.draw_polyline(PackedVector2Array([Vector2(x, y + 13), Vector2(x + 95, y + 17), Vector2(x + 270, y + 14)]), Color(0.85, 0.72, 0.53, 0.07), 1, true)
	s.draw_rect(Rect2(195, 150, 1210, 695), Color("657366"))
	s.draw_rect(Rect2(204, 157, 1192, 681), Color("acb39a"), false, 1)
	# Fine woven edges keep the central gameplay area quiet.
	for x in range(215, 1390, 18):
		s.draw_line(Vector2(x, 831), Vector2(x + 6, 839), Color(0.85, 0.85, 0.7, 0.25), 1)

static func prop(s: Control, index: int, rect: Rect2) -> void:
	var cell = PROPS.get_size() / 2.0
	var source = Rect2(Vector2(index % 2, floori(index / 2.0)) * cell, cell)
	s.draw_texture_rect_region(PROPS, rect, source)

static func dressing(s: Control) -> void:
	if not s.mode in MODES:
		return
	if s.mode == "board":
		prop(s, 0, Rect2(0, 195, 225, 225))
		prop(s, 1, Rect2(0, 440, 225, 225))
		prop(s, 2, Rect2(1380, 190, 220, 220))
		prop(s, 3, Rect2(1370, 445, 230, 230))
	elif s.mode == "review":
		prop(s, 0, Rect2(15, 210, 285, 285))
		prop(s, 1, Rect2(230, 555, 280, 280))
		prop(s, 2, Rect2(1295, 185, 280, 280))
		prop(s, 3, Rect2(1190, 540, 300, 300))
	else:
		prop(s, 0, Rect2(0, 370, 170, 170))
		prop(s, 1, Rect2(0, 650, 200, 200))
		prop(s, 2, Rect2(1425, 365, 175, 175))
		prop(s, 3, Rect2(1330, 620, 240, 240))
