extends RefCounted
## Reference-based presentation only. All availability comes from GameCore.
const LIBRARY = preload("res://assets/shadow-library-v2.png")
const DESK = preload("res://assets/manuscript-desk-v2.png")
const TILES = preload("res://assets/manuscript-tiles-v2.png")
const INK = Color("243438")
const PAPER = Color("eee0c4")
const GOLD = Color("edbe77")
const TILE_TYPES = ["Soldier", "InkArrow", "Dragon", "Brush", "Kite", "Inkstone"]
# Tight atlas regions deliberately omit the generated inter-cell backdrop.
const REGIONS = [Rect2(90, 46, 404, 448), Rect2(564, 46, 408, 448), Rect2(1043, 46, 407, 448), Rect2(90, 527, 404, 450), Rect2(564, 527, 408, 450), Rect2(1043, 527, 407, 450)]
const POSITIONS = {"A":Vector2(730, 388), "B":Vector2(1370, 416), "C":Vector2(1350, 735), "D":Vector2(188, 373), "E":Vector2(375, 721), "F":Vector2(1335, 213)}
const NAMES = {"A":"书楼入口", "B":"中央转台", "C":"交错回廊", "D":"侧架尽头", "E":"高台移灯处", "F":"暖灯门前"}
static var bottom_fade: GradientTexture2D

static func paper(s, rect: Rect2) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = PAPER
	style.border_color = Color("9b8160")
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.shadow_color = Color(0.09, 0.06, 0.04, 0.32)
	style.shadow_size = 7
	style.shadow_offset = Vector2(3, 6)
	s.draw_style_box(style, rect)
	s.draw_texture_rect_region(DESK, rect.grow(-3), Rect2(480, 130, 650, 440), Color(1, 1, 1, 0.50))
	s.draw_rect(rect.grow(-7), Color(0.39, 0.29, 0.17, 0.28), false, 1)
	for side in [rect.position, rect.end - Vector2(21, 21)]:
		s.draw_line(side + Vector2(9, 9), side + Vector2(20, 9), Color("9b8160"), 1, true)
		s.draw_line(side + Vector2(9, 9), side + Vector2(9, 20), Color("9b8160"), 1, true)

static func tile(s, kind: String, rect: Rect2, tint = Color.WHITE) -> void:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("806345")
	style.set_corner_radius_all(5)
	style.shadow_color = Color(0.10, 0.07, 0.04, 0.35)
	style.shadow_size = 7
	style.shadow_offset = Vector2(4, 8)
	s.draw_style_box(style, Rect2(rect.position + Vector2(0, 4), rect.size))
	s.draw_texture_rect_region(TILES, rect, REGIONS[TILE_TYPES.find(kind)], tint)

static func card_rect(s, id: String) -> Rect2:
	var card: Dictionary = s.app.core.cards[id]
	var board: Dictionary = s.app.core.state.board
	var order: Array = board.get("layout_order", ["A", "D", "B", "E", "C", "F"])
	var col: int = order.find(card.stackId)
	var seed_value: int = int(board.get("layout_seed", 1))
	var piles = [Vector2(440, 110), Vector2(700, 125), Vector2(960, 110), Vector2(480, 350), Vector2(740, 365), Vector2(1000, 350)]
	var offset = Vector2(posmod(seed_value * (col + 3), 19) - 9, posmod(seed_value * (col + 7), 13) - 6)
	return Rect2(piles[col] + offset + Vector2(19 if col % 2 == 0 else -19, 12) * int(card.depth), Vector2(148, 166))

static func board(s) -> void:
	s.draw_texture_rect(DESK, Rect2(0, 0, 1600, 900), false)
	s.draw_line(Vector2(54, 98), Vector2(265, 98), Color(INK, 0.4), 1, true)
	var b: Dictionary = s.app.core.state.board
	for depth in range(5, -1, -1):
		for id in b.table:
			if int(s.app.core.cards[id].depth) != depth: continue
			var rect = card_rect(s, id)
			var active: bool = s.app.core.can_pick(id)
			var hit = s.app.ui.get_node_or_null("Card_" + id)
			var highlighted: bool = active and hit != null and (hit.is_hovered() or hit.has_focus())
			tile(s, s.app.core.card_type(id), rect, Color.WHITE if active else Color("b9ac92"))
			if highlighted or id == s.app.hint_card:
				s.draw_rect(rect.grow(2), GOLD, false, 3, true)
				s.draw_rect(rect.grow(-4), Color(GOLD, 0.65), false, 1, true)
			if s.app.core.card_type(id) == "Dragon" and not s.app.core.dragon_open():
				var ribbon = Rect2(rect.position + Vector2(13, 132), Vector2(122, 25))
				s.draw_rect(ribbon, Color("6c5943"))
				s.text_at("待正文理清", ribbon.position + Vector2(10, 18), 18, PAPER)
	paper(s, Rect2(400, 690, 735, 139))
	paper(s, Rect2(1190, 690, 325, 139))
	s.text_at("暂", Vector2(1205, 747), 23, INK)
	s.text_at("存", Vector2(1205, 779), 23, INK)
	for i in range(7):
		var rect = Rect2(422 + i * 99, 708, 88, 100)
		s.draw_rect(rect, Color(0.30, 0.23, 0.15, 0.35), false, 1, true)
		if i < b.tray.size(): tile(s, s.app.core.card_type(b.tray[i]), rect)
		else: s.draw_arc(rect.get_center() + Vector2(0, 25), 18, PI, TAU, 24, Color(0.41, 0.35, 0.23, 0.15), 1, true)
	for i in range(3):
		var rect = reserve_rect(i)
		s.draw_rect(rect, Color(0.30, 0.23, 0.15, 0.35), false, 1, true)
		if i < b.reserve.size(): tile(s, s.app.core.card_type(b.reserve[i]), rect)

static func reserve_rect(i: int) -> Rect2:
	return Rect2(1240 + i * 88, 712, 78, 92)

static func path_points(from_id: String, to_id: String) -> PackedVector2Array:
	var a: Vector2 = POSITIONS[from_id]
	var b: Vector2 = POSITIONS[to_id]
	# The final bridge bends out over the mist before climbing to the lit room.
	if from_id == "E" and to_id == "F": return PackedVector2Array([a, Vector2(1085, 630), Vector2(1210, 400), b])
	return PackedVector2Array([a, a.lerp(b, 0.5) + Vector2(0, -20), b])

static func ink_path(s, points: PackedVector2Array, joined: bool, moving_lamp = -1.0) -> void:
	var seam: Vector2 = points[-2].lerp(points[-1], 0.77)
	var end: Vector2 = points[-1]
	var tip: Vector2 = seam
	if not joined:
		tip -= (end - seam).normalized() * 48
		if moving_lamp >= 0: tip += Vector2((moving_lamp - 0.52) * 180, (moving_lamp - 0.52) * 180)
	var route = points.duplicate()
	route[-1] = tip
	brush_stroke(s, route, 0.94 if joined else 0.38)
	brush_stroke(s, PackedVector2Array([seam, end]), 0.94 if joined else 0.38)
	if joined:
		s.cinema.glow(seam, 31, GOLD, 0.022)
		var normal = (end - seam).normalized().orthogonal()
		s.draw_line(seam - normal * 15, seam + normal * 15, GOLD, 2, true)
		s.draw_line(seam, end, Color(GOLD, 0.8), 1.5, true)
	else:
		s.draw_circle(tip, 3, Color(PAPER, 0.7))

static func brush_stroke(s, route: PackedVector2Array, alpha: float) -> void:
	var upper = PackedVector2Array()
	var lower = PackedVector2Array()
	for segment in range(route.size() - 1):
		var a: Vector2 = route[segment]
		var b: Vector2 = route[segment + 1]
		var normal = (b - a).normalized().orthogonal()
		var steps = maxi(2, ceili(a.distance_to(b) / 8.0))
		for i in range(steps + 1):
			var p = a.lerp(b, float(i) / steps)
			var grain = sin(i * 4.1 + segment) * 1.6 + cos(i * 1.7) * 1.2
			upper.append(p + normal * (15 + grain))
			lower.append(p - normal * (17 + grain * 0.6))
	lower.reverse()
	s.draw_colored_polygon(upper + lower, Color(INK, alpha))
	s.draw_polyline(upper, Color(INK, alpha * 0.38), 2, true)
	s.draw_polyline(lower, Color(INK, alpha * 0.3), 2, true)

static func graph(s) -> void:
	s.draw_texture_rect(LIBRARY, Rect2(0, 0, 1600, 900), false)
	s.draw_line(Vector2(54, 98), Vector2(265, 98), Color(GOLD, 0.7), 1, true)
	var state: Dictionary = s.app.core.state.shadow
	var edges: Array = s.app.core.shadow_edges(state.node, int(state.view), state.lamp)
	var t: float = 0.0 if s.app.core.settings.reduced_motion else s.clock
	for edge in s.app.core.graph.edges:
		var relevant: bool = edge.fromNode == state.node or edge.toNode == state.node
		var aligned: bool = int(edge.viewIndex) == int(state.view)
		if not relevant: continue
		var joined: bool = aligned and (not edge.requiresLamp or (state.lamp >= edge.lampMin and state.lamp <= edge.lampMax))
		ink_path(s, path_points(edge.fromNode, edge.toNode), joined, state.lamp if edge.requiresLamp else -1.0)
	# Amber motes move only over the distant mist, leaving hit targets registered.
	for i in range(12):
		var p = Vector2(690 + fposmod(i * 71.0 + t * 4, 500), 260 + fposmod(i * 47.0 - t * 6, 420))
		s.draw_circle(p, 1.2, Color(PAPER, 0.34))
	s.cinema.glow(Vector2(1295, 68), 110 + sin(t * 2) * 3, GOLD, 0.006)
	for id in POSITIONS:
		var p: Vector2 = POSITIONS[id]
		var current: bool = id == state.node
		var reachable: bool = id in edges
		if current or reachable:
			s.draw_set_transform(p + Vector2(0, 3), 0, Vector2(1, 0.24))
			s.draw_arc(Vector2.ZERO, 40, 0, TAU, 48, Color(GOLD, 0.9), 3, true)
			s.draw_set_transform(Vector2.ZERO)
		var tag = Rect2(p + Vector2(-69, 22), Vector2(138, 29))
		s.draw_rect(tag, Color(INK, 0.86 if current or reachable else 0.64))
		s.text_at(id + " · " + NAMES[id], tag.position + Vector2(10, 21), 18, GOLD if current or reachable else PAPER)
	var player: Vector2 = POSITIONS[state.node]
	if not s.app.travel_target.is_empty():
		var points = path_points(state.node, s.app.travel_target)
		var fraction: float = s.app.travel_t * (points.size() - 1)
		var segment: int = mini(floori(fraction), points.size() - 2)
		player = points[segment].lerp(points[segment + 1], fraction - segment)
	s.draw_person(player, 0.64, "run" if s.app.busy and not s.app.travel_target.is_empty() else "stand")
	# A physical light on the foreground rail follows the same value as Lamp2.
	if state.node == "E":
		var lamp = Vector2(160 + state.lamp * 360, 706)
		s.draw_line(Vector2(160, 712), Vector2(520, 712), Color(GOLD, 0.72), 2, true)
		s.draw_symbol("Lamp", lamp - Vector2(0, 24), 0.7, INK)
		s.cinema.glow(lamp - Vector2(0, 39), 65, GOLD, 0.012)
	if bottom_fade == null:
		bottom_fade = GradientTexture2D.new()
		bottom_fade.width = 4
		bottom_fade.height = 256
		bottom_fade.fill_from = Vector2(0, 0)
		bottom_fade.fill_to = Vector2(0, 1)
		bottom_fade.gradient = Gradient.new()
		bottom_fade.gradient.colors = PackedColorArray([Color(0.045, 0.068, 0.07, 0), Color(0.045, 0.068, 0.07, 0.94)])
	s.draw_texture_rect(bottom_fade, Rect2(0, 660, 1600, 240), false)
