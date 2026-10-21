extends RefCounted
## Reusable, pause-aware ink, light and foreground staging. No gameplay rewards.
const INK = Color("25393b")
const PAPER = Color("efe6d2")
const GOLD = Color("d1a567")
const JADE = Color("839784")
var s
var app

func setup(stage) -> void:
	s = stage
	app = stage.app

func line(points: Array, color: Color, width: float = 2.0) -> void:
	s.draw_polyline(PackedVector2Array(points), color, width, true)

func glow(p: Vector2, radius: float, color: Color, strength = 0.03) -> void:
	for i in range(12, 0, -1):
		s.draw_circle(p, radius * i / 12.0, Color(color, strength))

func atmosphere() -> void:
	var t: float = 0 if app.core.settings.reduced_motion else s.clock
	if s.bg_index == 0:
		for j in range(12):
			var y = 390.0 + j * 38
			var pts = PackedVector2Array()
			for x in range(0, 1640, 32): pts.append(Vector2(x, y + sin(x * 0.012 + t * 0.6 + j) * (2 + j * 0.3)))
			s.draw_polyline(pts, Color(PAPER, 0.05 + j * 0.002), 1.4, true)
		for i in range(8):
			var p = Vector2(fposmod(i * 265.0 + t * 7, 1800) - 100, 280 + i * 57)
			s.draw_set_transform(p, 0, Vector2(4.5, 0.3))
			s.draw_circle(Vector2.ZERO, 95, Color(PAPER, 0.018))
			s.draw_set_transform(Vector2.ZERO)
	elif s.bg_index in [1, 2]:
		glow(Vector2(1180, 340), 240 + sin(t * 3) * 9, GOLD, 0.008)
		for i in range(22):
			var p = Vector2(300 + fposmod(i * 83 + t * 8, 1050), 180 + fposmod(i * 47 - t * 5, 460))
			s.draw_circle(p, 1.4, Color(GOLD, 0.16))
	else:
		var winter = app.core.state.dialogue.get("id", "") == "WifeReflection"
		weather(3 if winter else int(app.core.state.season), t)

func weather(season: int, t: float) -> void:
	for i in range(52):
		var p = Vector2(fposmod(i * 137.0 + t * (19 if season == 3 else 37), 1660) - 30, fposmod(i * 83.0 + t * (28 if season == 3 else 52), 900))
		match season:
			0:
				s.draw_set_transform(p, sin(t + i), Vector2(1.8, 0.65))
				s.draw_circle(Vector2.ZERO, 3, Color("d9aaa4") * Color(1, 1, 1, 0.65))
				s.draw_set_transform(Vector2.ZERO)
			1: s.draw_line(p, p + Vector2(-8, 26), Color(PAPER, 0.24), 1, true)
			2:
				s.draw_set_transform(p, t + i, Vector2(1.5, 0.6))
				s.draw_circle(Vector2.ZERO, 4, Color(GOLD, 0.65))
				s.draw_set_transform(Vector2.ZERO)
			3: s.draw_circle(p + Vector2(sin(t + i) * 18, 0), 1.5 + i % 3, Color(PAPER, 0.7))

func portrait(id: String, rect: Rect2, alpha = 1.0) -> void:
	if id == "Wife" and s.wife != null:
		s.draw_texture_rect(s.wife, rect, false, Color(1, 1, 1, alpha))
		return
	var index = ["Ye", "Ding", "Student", "Wife"].find(id)
	if index < 0 or s.portraits == null: return
	var cell = Vector2(s.portraits.get_width() / 4.0, s.portraits.get_height())
	s.draw_texture_rect_region(s.portraits, rect, Rect2(index * cell.x, 0, cell.x, cell.y), Color(1, 1, 1, alpha))

func draw() -> void:
	match app.mode:
		"ding_table", "ding_place", "ding_seat": table(app.scene_age, false)
		"wife_arrival": arrival()
		"dialogue":
			if app.core.state.dialogue.id == "WifeReflection": wife_farewell()
		"reply", "dinner_call": table(5, false)
		"finale": finale()
		"release_echo": echoes()
		"body": body()
		"credits": river_lights(1)

func table(t: float, _ending: bool) -> void:
	var reveal = smoothstep(0, 4, t)
	var z = 1.0 if app.core.settings.reduced_motion else lerpf(1.045, 1.0, reveal)
	s.draw_texture_rect(s.dinner, Rect2(Vector2(800, 450) * (1 - z), Vector2(1600, 900) * z), false)
	glow(Vector2(1370, 445), 235 + sin(s.clock * 3) * 5, GOLD, 0.008)
	steam(Vector2(1035, 500), 0.15)
	steam(Vector2(810, 660), 0.08)
	if app.mode == "ding_table":
		s.draw_rect(Rect2(0, 0, 1600, 900), Color(0.03, 0.04, 0.04, 1 - reveal))
		s.text_at("灯下，还留着一副碗筷。", Vector2(520, 230), 42, Color(PAPER, smoothstep(1.6, 4.5, t)))

func bowl(p: Vector2, scale_value: float, alpha: float) -> void:
	s.draw_set_transform(p, 0, Vector2.ONE * scale_value)
	s.draw_set_transform(p + Vector2(0, 24), 0, Vector2(scale_value, scale_value * 0.3))
	s.draw_circle(Vector2.ZERO, 58, Color(INK, 0.2 * alpha))
	s.draw_set_transform(p, 0, Vector2.ONE * scale_value)
	s.draw_colored_polygon(PackedVector2Array([Vector2(-52, 0), Vector2(-29, 34), Vector2(29, 34), Vector2(52, 0)]), Color("b1b9a4") * Color(1, 1, 1, alpha))
	s.draw_line(Vector2(-25, 34), Vector2(25, 34), Color(PAPER, alpha), 4, true)
	s.draw_set_transform(p, 0, Vector2(scale_value, scale_value * 0.3))
	s.draw_circle(Vector2.ZERO, 52, Color(PAPER, alpha))
	s.draw_arc(Vector2.ZERO, 46, 0, TAU, 48, Color(JADE, alpha), 2, true)
	s.draw_set_transform(Vector2.ZERO)
	for i in range(3):
		var pts = PackedVector2Array()
		for j in range(18):
			var v = j / 17.0
			pts.append(p + Vector2((i - 1) * 20 + sin(v * 7 + s.clock + i) * 7, -v * 90 - 8))
		s.draw_polyline(pts, Color(PAPER, 0.16 * alpha), 2, true)

func arrival() -> void:
	var t: float = app.scene_age
	s.draw_rect(Rect2(0, 0, 1600, 900), Color("10191b"))
	if t < 2.2:
		var z = 1 + pow(t / 2.2, 3) * 3
		s.draw_set_transform(Vector2(800, 420), 0, Vector2.ONE * z)
		s.text_at("若如初见", Vector2(-124, 0), 62, Color(PAPER, 1 - t / 2.5), true)
		s.draw_set_transform(Vector2.ZERO)
	else:
		var travel = smoothstep(2.2, 5.5, t)
		var p = Vector2(210 + travel * 770, 570 + sin(t * 12) * 6 * (1 - travel))
		# Ink tail grows out of the departing title, then horse and station emerge.
		for i in range(12):
			line([p + Vector2(-65, -50), p + Vector2(-150, -20 + i), Vector2(90, 470 + i * 6)], Color(PAPER, 0.13 * (1 - travel)), 3)
		s.draw_set_transform(p, 0, Vector2(1.9, 0.8))
		s.draw_circle(Vector2(0, -30), 48, JADE)
		s.draw_set_transform(Vector2.ZERO)
		line([p + Vector2(55, -40), p + Vector2(80, -115), p + Vector2(112, -100)], JADE, 25)
		for i in range(4):
			var step = sin(t * 13 + i * PI / 2) * 22 * (1 - travel)
			line([p + Vector2(-55 + i * 30, -16), p + Vector2(-60 + i * 30 + step, 65)], JADE, 10)
		s.draw_person(p + Vector2(0, -50), 0.8, "brace")
		line([Vector2(1130, 590), Vector2(1130, 290), Vector2(1430, 290), Vector2(1430, 590)], Color(PAPER, travel * 0.6), 12)
		line([Vector2(1080, 310), Vector2(1280, 210), Vector2(1480, 310)], Color(JADE, travel), 15)
		s.text_at("驿  站", Vector2(1210, 345), 34, Color(PAPER, travel))
		if t > 5.8: s.draw_rect(Rect2(0, 0, 1600, 900), Color(PAPER, smoothstep(5.8, 7, t)))

func wife_farewell() -> void:
	var cue: String = app.core.dialogue.WifeReflection.lines[int(app.core.state.dialogue.index)].get("cue", "")
	var t: float = app.line_age
	# The far eave and an empty place remain in frame after the observer vanishes.
	line([Vector2(860, 140), Vector2(1510, 140), Vector2(1510, 650)], Color(INK, 0.65), 14)
	for x in range(860, 1500, 24): s.draw_line(Vector2(x, 140), Vector2(x + 12, 155), Color(PAPER, 0.4), 3, true)
	if cue in ["report", "ink", "waiting", "dissolve", "vanish"]:
		var alpha = 1.0 - smoothstep(0, 3.5, t) if cue == "vanish" else 1.0
		s.draw_set_transform(Vector2(460, 475), -0.07, Vector2.ONE)
		s.draw_rect(Rect2(-160, -110, 320, 245), Color(PAPER, alpha))
		for i in range(15):
			var spread = 3 + smoothstep(0, 2.8, t) * 15 if cue != "report" else 3.0
			glow(Vector2(-90 + (i % 4) * 54, -60 + floori(i / 4.0) * 39), spread * 1.5, INK, alpha * 0.05)
		s.draw_set_transform(Vector2.ZERO)
		hands(Vector2(460, 630), alpha)
		if cue in ["dissolve", "vanish"]:
			for i in range(46):
				var q = Vector2(270 + fposmod(i * 41 + t * 48, 450), 580 - fposmod(i * 29 + t * 42, 270))
				s.draw_rect(Rect2(q, Vector2(2 + i % 4, 3)), Color(INK, alpha * 0.45))
	if cue == "jade":
		s.draw_jade_whole(Vector2(555, 520), 0.55)
		hands(Vector2(555, 630), 1)

func hands(p: Vector2, alpha = 1.0) -> void:
	for sign_value in [-1, 1]:
		var sign_f = float(sign_value)
		s.draw_colored_polygon(PackedVector2Array([p + Vector2(sign_f * 110, -42), p + Vector2(sign_f * 170, -26), p + Vector2(sign_f * 240, 150), p + Vector2(sign_f * 110, 150)]), Color("34494d") * Color(1, 1, 1, alpha))
		line([p + Vector2(sign_f * 150, -20), p + Vector2(sign_f * 130, -60), p + Vector2(sign_f * 100, -72)], Color("c7ac89") * Color(1, 1, 1, alpha), 23)

func finale() -> void:
	var t: float = app.scene_age
	table(5, true)
	var seated = smoothstep(0, 4, t)
	portrait("Ding", Rect2(240, 130 + (1 - seated) * 60, 300, 450), seated)
	var student_in = smoothstep(8, 11, t)
	portrait("Student", Rect2(980 - student_in * 170, 160, 270, 405), student_in)
	var wife_in = smoothstep(17, 21, t)
	portrait("Wife", Rect2(1400 - wife_in * 300, 120, 320, 480), wife_in)
	# Redraw only the table foreground, so guests sit behind it instead of floating above it.
	var source_size = s.dinner.get_size()
	s.draw_texture_rect_region(s.dinner, Rect2(0, 525, 1600, 375), Rect2(0, source_size.y * 525 / 900.0, source_size.x, source_size.y * 375 / 900.0))
	steam(Vector2(1035, 500), 0.15)
	if t < 4:
		s.draw_rect(Rect2(0, 0, 1600, 900), Color(INK, (1 - seated) * 0.5))
		hands(Vector2(800, 930), 1 - seated)
	if t > 10 and t < 19:
		var handover = smoothstep(11, 15, t)
		s.draw_report(Vector2(800, 780).lerp(Vector2(940, 540), handover), lerpf(0.65, 0.25, handover))
	if t > 17 and t < 24:
		bowl(Vector2(1400, 545).lerp(Vector2(1180, 605), wife_in), 0.85, wife_in * (1 - smoothstep(22, 24, t)))
	if t > 23:
		s.draw_rect(Rect2(0, 0, 1600, 900), Color(INK, smoothstep(23, 27, t)))
		river_lights(smoothstep(24, 28, t))

func river_lights(alpha: float) -> void:
	for i in range(22):
		var depth = i / 21.0
		var p = Vector2(170 + fposmod(i * 137 + sin(s.clock * 0.3 + i) * 18, 1270), 280 + depth * 560)
		var radius = 5 + depth * 15
		glow(p, radius * 4, GOLD, alpha * 0.018)
		s.draw_colored_polygon(PackedVector2Array([p + Vector2(-radius, 0), p + Vector2(0, radius * 0.5), p + Vector2(radius, 0), p + Vector2(0, -radius * 0.4)]), Color(GOLD, alpha))
		s.draw_circle(p + Vector2(0, -radius * 0.5), radius * 0.22, Color(PAPER, alpha))
		for j in range(8):
			var w = radius * (1.0 - j / 9.0)
			var y = p.y + 12 + j * 9
			var x = p.x + sin(j + s.clock) * 5
			s.draw_line(Vector2(x - w, y), Vector2(x + w, y), Color(GOLD, alpha * 0.14), 2, true)

func echoes() -> void:
	var t: float = app.scene_age
	s.draw_rect(Rect2(0, 0, 1600, 900), Color(INK, 0.5))
	for i in range(20):
		var q = Vector2(800 + sin(i * 2.1) * t * 36, 440 + t * 18 + cos(i) * 30)
		s.draw_set_transform(q, sin(i + t) * 0.5, Vector2.ONE)
		s.draw_rect(Rect2(-14, -9, 28, 18), Color(PAPER, 1 - smoothstep(0, 6, t)))
		s.draw_set_transform(Vector2.ZERO)
	var a = smoothstep(2, 5, t) * (1 - smoothstep(7, 9, t))
	# The three specified echoes: paired shoes, an empty cup, unfinished literacy paper.
	for i in range(2):
		s.draw_set_transform(Vector2(450 + i * 55, 460), -0.15, Vector2(0.6, 1))
		s.draw_circle(Vector2.ZERO, 30, Color(PAPER, a))
		s.draw_set_transform(Vector2.ZERO)
	bowl(Vector2(800, 460), 0.65, a)
	s.draw_rect(Rect2(1070, 385, 165, 140), Color(PAPER, a))
	s.text_at("家", Vector2(1100, 485), 65, Color(INK, a * 0.55), true)
	s.draw_line(Vector2(1185, 485), Vector2(1240, 535), Color(INK, a), 6, true)

func body() -> void:
	var t: float = app.scene_age
	s.draw_rect(Rect2(0, 0, 1600, 900), Color("a5b3ad") * Color(1, 1, 1, 0.65))
	var lift = smoothstep(0, 5, t)
	for i in range(2):
		s.draw_paper_person(Vector2(525 + i * 570, 610 - lift * 45), 1.5, "brace")
	s.draw_colored_polygon(PackedVector2Array([Vector2(590, 600), Vector2(670, 530), Vector2(1040, 550), Vector2(1110, 620)]), Color("c3c5b4"))
	line([Vector2(595, 598), Vector2(740, 565), Vector2(890, 605), Vector2(1100, 616)], Color(INK, 0.3), 3)
	s.draw_report(Vector2(885, 565), 0.32)
	var fall = smoothstep(3, 5, t)
	for i in range(3): s.draw_jade_piece(Vector2(1000 + i * 33, 575 + fall * (88 + i * 12)), i, 0.24, true)
	s.text_at("村民把叶生的遗体捞上岸。", Vector2(520, 760), 34, Color(INK, smoothstep(4, 6, t)))
	s.text_at("捷报糊在他怀中，玉佩从衣袋滑落。", Vector2(425, 810), 28, Color(INK, smoothstep(5, 7, t)))

func steam(p: Vector2, alpha: float) -> void:
	var time: float = 0 if app.core.settings.reduced_motion else s.clock
	for i in range(4):
		var points = PackedVector2Array()
		for j in range(20):
			var v = j / 19.0
			points.append(p + Vector2((i - 1.5) * 16 + sin(v * 8 + time + i) * 9, -v * 90))
		s.draw_polyline(points, Color(PAPER, alpha), 1.5, true)

func accident_foreground() -> void:
	var t: float = app.accident_time
	if t < 10 or t > 30: return
	var weight = clampf((t - 10) / 16, 0, 1)
	var entry = smoothstep(10, 12, t) * (1 - smoothstep(28, 30, t))
	var p = Vector2(800 + app.accident_x * 0.55, 660 + weight * 60)
	s.draw_set_transform(p, sin(s.clock * 1.5) * 0.025, Vector2.ONE)
	s.draw_rect(Rect2(-160, -110, 320, 180 + weight * 26), Color(PAPER.darkened(weight * 0.35), entry))
	s.text_at("捷  报", Vector2(-67, -35), 42, Color(INK, entry * (1 - weight * 0.8)), true)
	for i in range(12): glow(Vector2(-100 + i % 4 * 65, -70 + floori(i / 4.0) * 55), 8 + weight * 28, INK, 0.03 * entry)
	s.draw_set_transform(Vector2.ZERO)
	hands(p + Vector2(0, 100), entry)
	if t < 21:
		line([Vector2(1560, 350), Vector2(1170, 585)], Color("b09a76") * Color(1, 1, 1, entry), 14)
	else:
		line([Vector2(40, 260), Vector2(240, 420), Vector2(480, 570)], Color(GOLD, entry), 4)
