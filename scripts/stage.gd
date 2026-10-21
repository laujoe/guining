extends Control
## Ink-paper stage. Gameplay geometry is drawn from the same state as interaction.
const INK = Color("25393b")
const PAPER = Color("efe6d2")
const JADE = Color("839784")
const GOLD = Color("d1a567")
const RED = Color("9c4637")
const JadeVisual = preload("res://scripts/jade_visual.gd")
var app
var cinema = preload("res://scripts/cinema.gd").new()
var lantern_scene = preload("res://scripts/lantern_scene.gd").new()
var lantern_maze = preload("res://scripts/lantern_maze.gd").new()
var shadow_library = preload("res://scripts/shadow_library.gd").new()
const DingStory = preload("res://scripts/ding_story.gd")
var ding_story
const StudentStory = preload("res://scripts/student_story.gd")
var student_story
const WifeArrival = preload("res://scripts/wife_arrival.gd")
var wife_arrival
const WifeFarewell = preload("res://scripts/wife_farewell.gd")
var wife_farewell
const EndingSequence = preload("res://scripts/ending_sequence.gd")
var ending_sequence
var hub_points = [Vector2(430, 535), Vector2(820, 390), Vector2(1180, 270)]
const PaperCharacter = preload("res://scripts/paper_character.gd")
const MemoryGamesArt = preload("res://scripts/memory_games_art.gd")
const StudyDesk = preload("res://scripts/study_desk.gd")
const YeSheng = preload("res://scripts/ye_sheng.gd")
var clock = 0.0
var font: Font
var title_font: Font
var small_font: Font
var ferry: Texture2D = preload("res://assets/ferry-v2.png")
var dinner: Texture2D = preload("res://assets/dinner-v2.png")
var backgrounds: Texture2D = preload("res://assets/backgrounds.png")
var seasons: Texture2D = preload("res://assets/seasons.png")
var portraits: Texture2D
var wife: Texture2D = preload("res://assets/wife-reference-v3.png")
var bg_index = 0
var dim = 0.0
var mode = "menu"
var positions = {"A": Vector2(280, 600), "B": Vector2(580, 455), "C": Vector2(840, 590), "D": Vector2(580, 245), "E": Vector2(1100, 400), "F": Vector2(1350, 245)}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	lantern_maze.app = app
	add_child(lantern_maze)
	lantern_scene.app = app
	add_child(lantern_scene)
	shadow_library.app = app
	add_child(shadow_library)
	cinema.setup(self)
	ding_story = DingStory.new()
	ding_story.name = "DingStory"
	add_child(ding_story)
	ding_story.sync(app)
	student_story = StudentStory.new()
	student_story.name = "StudentStory"
	add_child(student_story)
	student_story.sync(app)
	wife_arrival = WifeArrival.new()
	wife_arrival.name = "WifeArrival"
	add_child(wife_arrival)
	wife_arrival.sync(app)
	wife_farewell = WifeFarewell.new()
	wife_farewell.name = "WifeFarewell"
	add_child(wife_farewell)
	wife_farewell.sync(app)
	ending_sequence = EndingSequence.new()
	ending_sequence.name = "EndingSequence"
	add_child(ending_sequence)
	ending_sequence.sync(app)
	if ResourceLoader.exists("res://assets/portraits.png"):
		portraits = load("res://assets/portraits.png")

func _process(delta: float) -> void:
	lantern_maze.sync(delta)
	shadow_library.sync()
	if app != null and not app.paused:
		clock += delta
	if ending_sequence != null:
		ending_sequence.sync(app)
	if ding_story != null:
		ding_story.sync(app)
	if student_story != null:
		student_story.sync(app)
	if wife_arrival != null:
		wife_arrival.sync(app)
	if wife_farewell != null:
		wife_farewell.sync(app)
	queue_redraw()

func text_at(value: String, pos: Vector2, size_px = 24, color = INK, literary = false) -> void:
	draw_string(title_font if literary else font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, color)

func _draw() -> void:
	if app == null:
		return
	if mode == "ding_lamp":
		draw_rect(Rect2(0, 0, 1600, 900), Color.BLACK)
		return
	if mode == "ding_graph":
		draw_rect(Rect2(0, 0, 1600, 900), Color("bfc3b8"))
		return
	if student_story != null and student_story.handles(app):
		student_story.draw_foreground(self)
		return
	if wife_farewell != null and wife_farewell.handles(app):
		if mode in ["wife_shard", "fragment"]:
			draw_jade_fragment_at(Vector2(520, 370), 2, 1.20, true)
		return
	if wife_arrival != null and wife_arrival.handles(app):
		if mode == "wife_arrival":
			var title_alpha = smoothstep(0.7, 1.8, app.scene_age) * (1.0 - smoothstep(4.0, 5.3, app.scene_age))
			text_at("若 如 初 见", Vector2(80, 135), 48, Color(PAPER, title_alpha))
			text_at("第三段记忆 · 第一幕", Vector2(84, 178), 22, Color(PAPER, title_alpha * 0.8))
		return
	if ding_story != null and ding_story.handles(app):
		if mode in ["ding_shard", "fragment"]:
			draw_jade_fragment_at(Vector2(800, 320), 0, 1.20, true)
		return
	if ending_sequence != null and ending_sequence.handles(mode):
		if mode == "release": draw_release()
		if mode == "release_echo": cinema.echoes()
		if mode == "finale" and app.scene_age > 25:
			draw_rect(Rect2(0, 0, 1600, 900), Color(INK, smoothstep(25, 28, app.scene_age)))
			cinema.river_lights(smoothstep(26, 29, app.scene_age))
		return
	var half = backgrounds.get_size() / 2.0
	var source = Rect2(Vector2((bg_index % 2) * half.x, floori(bg_index / 2.0) * half.y), half)
	var drift = Vector2.ZERO if app.core.settings.reduced_motion else Vector2(sin(clock * 0.12) * 7, cos(clock * 0.16) * 4)
	draw_texture_rect_region(backgrounds, Rect2(Vector2(-12, -8) + drift, Vector2(1624, 916)), source)
	if mode == "dialogue" and app.core.state.dialogue.get("id", "") == "WifeReflection":
		var cell = seasons.get_size() / 2.0
		draw_texture_rect_region(seasons, Rect2(0, 0, 1600, 900), Rect2(cell, cell))
	cinema.atmosphere()
	if mode == "runner":
		var season: int = int(app.core.state.season)
		var cell = seasons.get_size() / 2.0
		var previous: int = maxi(0, season - 1)
		draw_texture_rect_region(seasons, Rect2(0, 0, 1600, 900), Rect2(Vector2(previous % 2, floori(previous / 2.0)) * cell, cell))
		var blend = 1.0 if app.core.settings.reduced_motion else clampf(app.season_time / 1.8, 0, 1)
		draw_texture_rect_region(seasons, Rect2(0, 0, 1600, 900), Rect2(Vector2(season % 2, floori(season / 2.0)) * cell, cell), Color(1, 1, 1, blend))
	if mode == "menu":
		for x in range(0, 1000, 5):
			draw_rect(Rect2(x, 0, 5, 900), Color(0.07, 0.12, 0.13, 0.8 * pow(1.0 - x / 1000.0, 0.6)))
	else:
		draw_rect(Rect2(0, 0, 1600, 900), Color(0.09, 0.14, 0.15, dim))
	# Subtle motes across the water, disabled in reduced motion mode.
	if not app.core.settings.reduced_motion:
		for i in range(14):
			var p = Vector2(fmod(i * 137.0 + clock * 6, 1650), 210 + fmod(i * 81.0, 480))
			draw_circle(p, 1.8, Color(0.94, 0.90, 0.82, 0.12 + 0.08 * sin(clock + i)))
	StudyDesk.backdrop(self)
	match mode:
		"hub": draw_hub()
		"ding_lamp": draw_lamp()
		"ding_graph": draw_graph()
		"board": draw_board()
		"army", "dragon": draw_battle()
		"runner": draw_runner()
		"jade", "flip": draw_jade()
		"accident": draw_accident()
		"release": draw_release()
		"report":
			draw_report(Vector2(800, 410), 1.0)
		"review", "literacy": draw_stroke()
		"fragment", "ding_shard", "student_shard", "wife_shard":
			draw_jade_fragment_at(Vector2(800, 360), app.fragment_index(), 1.45, true)
		"body": pass
	StudyDesk.dressing(self)
	cinema.draw()
	if mode == "dialogue" and app.core.state.dialogue.id != "WifeLetter":
		draw_dialogue_portraits()
		if app.core.state.dialogue.get("id", "") == "BodyReveal":
			draw_body()
	if mode in ["hub", "ding_lamp", "army", "dragon", "runner"]:
		for i in range(3):
			draw_jade_fragment_at(Vector2(1330 + i * 57, 56), i, 0.19, app.core.MEMORY_IDS[i] in app.core.state.completed)

func draw_hub() -> void:
	var drift = Vector2.ZERO if app.core.settings.reduced_motion else Vector2(sin(clock * 0.12) * 5, cos(clock * 0.16) * 3)
	draw_texture_rect(ferry, Rect2(Vector2(-8, -5) + drift, Vector2(1616, 910)), false)
	draw_rect(Rect2(0, 0, 1600, 900), Color(INK, 0.12))
	cinema.atmosphere()
	for i in range(3):
		var center: Vector2 = hub_points[i]
		cinema.glow(center, 100, GOLD, 0.012)
		draw_circle(center, 48, Color(INK, 0.72))
		draw_arc(center, 54, 0, TAU, 64, Color(GOLD, 0.7), 1.2, true)
		draw_symbol(["Lamp", "Brush", "Letter"][i], center, 0.8, PAPER)

func draw_symbol(kind: String, p: Vector2, s = 1.0, col = INK) -> void:
	if kind == "Soldier":
		# Cards and living paper guards use the same body, with a vermilion wash.
		PaperCharacter.paint(self, p + Vector2(0, 44 * s), s * 0.82, "guard", clock, true, Color(0.78, 0.57, 0.43, col.a), true, false)
		draw_set_transform(p, 0, Vector2.ONE * s)
		draw_line(Vector2(-34, -43), Vector2(-34, 42), Color("70543c", col.a), 3, true)
		draw_colored_polygon(PackedVector2Array([Vector2(-34, -52), Vector2(-40, -36), Vector2(-28, -36)]), Color("9c4637", col.a))
		draw_set_transform(Vector2.ZERO)
		return
	draw_set_transform(p, 0, Vector2.ONE * s)
	match kind:
		"Lamp":
			for radius in range(48, 8, -4):
				draw_circle(Vector2(0, -15), radius, Color(GOLD, 0.018))
			draw_colored_polygon(PackedVector2Array([Vector2(-23, 25), Vector2(23, 25), Vector2(12, 13), Vector2(8, -6), Vector2(-8, -6), Vector2(-12, 13)]), col)
			draw_circle(Vector2(0, -20), 15, GOLD)
			draw_circle(Vector2(1, -25), 7, PAPER)
			draw_line(Vector2(-25, 31), Vector2(25, 31), col, 4, true)
		"Brush":
			draw_line(Vector2(18, -38), Vector2(-11, 19), Color("8b6648"), 9, true)
			draw_colored_polygon(PackedVector2Array([Vector2(-17, 12), Vector2(-4, 21), Vector2(-29, 43)]), col)
			draw_line(Vector2(19, -36), Vector2(30, -18), RED, 3, true)
		"InkArrow":
			draw_line(Vector2(-27, 35), Vector2(28, -34), col, 4, true)
			for j in range(4):
				draw_line(Vector2(-19 + j * 7, 23 - j * 9), Vector2(-30 + j * 7, 9 - j * 9), col, 4, true)
			draw_colored_polygon(PackedVector2Array([Vector2(28, -38), Vector2(24, -15), Vector2(10, -25)]), col)
		"Kite":
			var pts = PackedVector2Array([Vector2(0, -36), Vector2(35, -5), Vector2(0, 28), Vector2(-35, -5)])
			draw_colored_polygon(pts, JADE)
			draw_polyline(pts + PackedVector2Array([pts[0]]), col, 2, true)
			draw_line(Vector2(0, -36), Vector2(0, 28), RED, 2, true)
			draw_line(Vector2(-35, -5), Vector2(35, -5), col, 2, true)
			draw_polyline(PackedVector2Array([Vector2(0, 28), Vector2(12, 40), Vector2(-2, 48), Vector2(13, 55)]), RED, 3, true)
		"Inkstone":
			draw_set_transform(p, 0, Vector2(s, s * 0.65))
			draw_circle(Vector2.ZERO, 39, col)
			draw_arc(Vector2.ZERO, 28, 0, TAU, 40, JADE, 3, true)
			draw_circle(Vector2(-5, 2), 19, Color("182528"))
		"Dragon":
			var pts = PackedVector2Array()
			for j in range(30):
				var t = j / 29.0
				pts.append(Vector2(sin(t * TAU * 1.4) * 26, 34 - t * 65))
			draw_polyline(pts, JADE, 13, true)
			draw_polyline(pts, col, 2, true)
			draw_circle(pts[-1], 12, col)
			draw_circle(pts[-1] + Vector2(5, -2), 3, RED)
			draw_line(pts[-1] + Vector2(-5, -4), pts[-1] + Vector2(-15, -20), col, 3, true)
		"Letter":
			draw_rect(Rect2(-43, -28, 86, 56), PAPER)
			draw_rect(Rect2(-43, -28, 86, 56), col, false, 2)
			draw_polyline(PackedVector2Array([Vector2(-41, -26), Vector2(0, 7), Vector2(41, -26)]), col, 2, true)
			draw_circle(Vector2(0, 7), 8, RED)
	draw_set_transform(Vector2.ZERO)

func draw_person(p: Vector2, scale_value = 1.0, pose = "stand", alpha = 1.0, facing_left = false) -> void:
	YeSheng.paint(self, p, scale_value, pose, clock, facing_left, alpha, app.core.settings.reduced_motion)

func draw_paper_person(p: Vector2, scale_value = 1.0, pose = "stand", alpha = 1.0, facing_left = false) -> void:
	PaperCharacter.paint(self, p, scale_value, pose, clock, facing_left, Color(1, 1, 1, alpha), app.core.settings.reduced_motion)

func draw_lamp() -> void:
	pass # Dedicated 3D viewport and foreground own this route.

func draw_graph() -> void:
	MemoryGamesArt.graph(self)

func card_rect(id: String) -> Rect2:
	return MemoryGamesArt.card_rect(self, id)

func draw_board() -> void:
	MemoryGamesArt.board(self)

func draw_battle() -> void:
	draw_rect(Rect2(140, 155, 1320, 550), Color(PAPER, 0.97))
	for side in [170, 1430]: draw_line(Vector2(side, 160), Vector2(side, 700), Color("806e52"), 18)
	for j in range(12):
		var y = 280 + j * j * 2.8
		draw_line(Vector2(180, y), Vector2(1420, y), Color(INK, 0.07), 1)
	if mode == "army":
		for i in range(5):
			var p = Vector2(400 + i * 200, 295 + (i % 2) * 45)
			draw_symbol("Soldier", p, 1.2 + (i % 2) * 0.4)
	else:
		var body = PackedVector2Array()
		for i in range(45): body.append(Vector2(330 + i * 21, 300 + sin(i * 0.22 + clock * 0.5) * 60))
		draw_polyline(body, JADE, 48, true)
		draw_polyline(body, INK, 2, true)
		for i in range(0, 45, 2): draw_arc(body[i], 23, 0, PI, 15, Color(PAPER, 0.6), 2, true)
		draw_symbol("Dragon", body[0] - Vector2(0, 15), 1.8)
	var count = 5 if mode == "dragon" else 4
	for i in range(count):
		var p = Vector2(430 + i * 180, 205)
		draw_circle(p, 24, RED if i == app.battle_hits else Color(JADE, 0.5))
		draw_arc(p, 30, 0, TAU, 32, GOLD if i < app.battle_hits else INK, 2, true)
		if i < app.battle_hits: draw_polyline(PackedVector2Array([p + Vector2(-8, 0), p + Vector2(-1, 8), p + Vector2(12, -9)]), PAPER, 3, true)
	if app.attack_warning > 0:
		var target = battle_screen(Vector2(1200, app.battle_aim.y))
		draw_dashed_line(target, Vector2(800, 680), Color(RED, 0.5), 2, 15, true)
		draw_arc(target, 35 + app.attack_warning * 18, 0, TAU, 40, RED, 2, true)
	if app.hazard_warning > 0 or app.hazard_active > 0:
		if app.hazard_kind == "charge":
			var p = battle_screen(app.charge_pos)
			draw_symbol("Soldier", p, clampf(700.0 / maxf(150, app.charge_pos.x - app.player_pos.x + 120), 0.7, 3))
			draw_arc(p, 65, PI, TAU, 30, RED, 3, true)
		else:
			var center = battle_screen(Vector2(app.hazard_x, app.hazard_y))
			draw_line(Vector2(190, center.y), Vector2(center.x - 115, center.y), Color(INK, 0.65), 28, true)
			draw_line(Vector2(center.x + 115, center.y), Vector2(1410, center.y), Color(INK, 0.65), 28, true)
	for bullet in app.bullets:
		var p = battle_screen(bullet.p)
		var size_value = clampf(650.0 / maxf(100, bullet.p.x - app.player_pos.x + 120), 0.5, 4)
		draw_symbol("InkArrow", p, size_value * 0.55, RED if bullet.reflected else INK)
	var hand = Vector2(980, 685) + Vector2(app.move_dir.x * 40, app.move_dir.y * 15)
	if app.brush_time > 0:
		var stroke = PackedVector2Array()
		for i in range(32):
			var angle = lerpf(-PI * 0.9, -0.1, i / 31.0)
			stroke.append(Vector2(800, 690) + Vector2.from_angle(angle) * 230)
		draw_polyline(stroke, Color(RED, 0.65), 10, true)
		hand += Vector2(-150, -100)
	draw_symbol("Brush", hand, 2.3)
	cinema.hands(Vector2(815, 790), 0.45 if app.invincible > 0 else 1)

func draw_runner() -> void:
	var season: int = int(app.core.state.season)
	cinema.weather(season, 0 if app.core.settings.reduced_motion else clock)
	draw_season_details(season)
	for i in range(20):
		var x = fposmod(i * 103 - app.runner_scroll * 40, 1700) - 50
		draw_line(Vector2(x, 708), Vector2(x + 35, 708), Color(INK, 0.15), 2, true)
	for obstacle in app.obstacles:
		var x: float = obstacle.x
		if obstacle.action == "Slide":
			draw_line(Vector2(x + 45, 705), Vector2(x + 45, 540), INK, 9, true)
			draw_line(Vector2(x - 65, 608), Vector2(x + 45, 608), INK, 14, true)
			text_at("↓ 低身", Vector2(x - 55, 525), 25, INK)
		else:
			draw_colored_polygon(PackedVector2Array([Vector2(x - 33, 705), Vector2(x - 25, 661), Vector2(x + 22, 660), Vector2(x + 40, 705)]), INK)
			text_at("↑ 跳", Vector2(x - 40, 630), 25, INK)
	var pose = "jump" if app.jump_height > 0 else "slide" if app.slide_time > 0 else "brace" if app.bracing else "run"
	if app.stumble_protect > 0.8:
		pose = "hit"
	draw_person(Vector2(448, 701 - app.jump_height), 1.08, pose, 0.6 if app.stumble_protect > 0 else 1.0)
	var letter_pos = Vector2(1088 + (app.letter_distance / 0.8) * 224 + sin(clock * 1.3) * 8, 380 + sin(clock * 2) * 15)
	if season == 3 and app.season_time > 24:
		letter_pos = letter_pos.lerp(Vector2(500, 530), (app.season_time - 24) / 6.0)
	draw_symbol("Letter", letter_pos, 1.0 - 0.35 * app.letter_distance)
	if app.in_wind():
		for i in range(45):
			var x = fposmod(i * 73 - clock * 460, 1700)
			var y = 190 + fposmod(i * 47, 430)
			draw_line(Vector2(x, y), Vector2(x + 30, y - 7), Color(PAPER, 0.8), 2, true)

func jade_polygon(id: int, radius = 140.0) -> PackedVector2Array:
	return JadeVisual.polygon(id, radius)

func draw_jade_piece(p: Vector2, id: int, s: float, filled: bool) -> void:
	var assembling = mode in ["jade", "flip"]
	var flip_scale = maxf(0.025, absf(cos(app.jade_flip * PI))) if assembling else 1.0
	var back = assembling and app.core.state.inscription and app.jade_flip >= 0.5
	var seam_alpha = 0.24 if assembling and app.core.state.jade.size() == 3 else 0.70
	JadeVisual.paint_piece(self, p, id, Vector2(s * flip_scale, s), filled, back, seam_alpha)

func draw_jade_fragment_at(p: Vector2, id: int, s: float, filled: bool = true) -> void:
	draw_jade_piece(p - JadeVisual.piece_center(id) * s, id, s, filled)

func draw_jade_whole(p: Vector2, s: float) -> void:
	JadeVisual.paint_whole(self, p, s)

func draw_jade() -> void:
	draw_rect(Rect2(210, 170, 1180, 540), Color(INK, 0.76))
	for id in range(3):
		draw_jade_piece(Vector2(800, 430), id, 1.35, false)
	for id in range(3):
		draw_jade_piece(app.jade_positions[id], id, 1.35, true)
	if app.core.state.jade.size() == 3:
		cinema.glow(Vector2(800, 430), 225, GOLD, 0.005 + sin(clock) * 0.002)
		if app.jade_flip > 0.65 and app.core.state.inscription:
			var a = smoothstep(0.65, 1.0, app.jade_flip)
			var words = "中举之后·陪妻归宁·与友饮酒·教儿识字"
			for i in range(words.length()):
				var angle = -PI / 2 + i / float(words.length()) * TAU
				var p = Vector2(800, 430) + Vector2.from_angle(angle) * 126
				text_at(words[i], p + Vector2(-12, 12), 27, Color(PAPER, a * 0.65), true)
				text_at(words[i], p + Vector2(-13, 11), 27, Color(INK, a), true)
			for i in range(4):
				text_at(["中举之后", "陪妻归宁", "与友饮酒", "教儿识字"][i], Vector2(1080, 345 + i * 56), 30, Color(PAPER, a))

	if mode == "jade" and app.selected_jade >= 0:
		draw_arc(app.jade_positions[app.selected_jade], 210, 0, TAU, 64, Color(GOLD, 0.4), 1.5, true)

func draw_report(p: Vector2, s: float) -> void:
	draw_set_transform(p, -0.06, Vector2.ONE * s)
	draw_rect(Rect2(-160, -125, 320, 250), PAPER)
	draw_rect(Rect2(-150, -115, 300, 230), GOLD, false, 2)
	text_at("捷  报", Vector2(-73, -30), 54, INK, true)
	text_at("叶 生", Vector2(-45, 53), 34, INK)
	draw_rect(Rect2(85, 54, 30, 38), RED, false, 3)
	draw_set_transform(Vector2.ZERO)

func draw_accident() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color(0.04, 0.1, 0.12, 0.8))
	for j in range(18):
		var pts = PackedVector2Array()
		for x in range(0, 1640, 40):
			pts.append(Vector2(x, 280 + j * 30 + sin(x / 110.0 + clock * 1.7 + j) * 14))
		draw_polyline(pts, Color(JADE, 0.2), 3, true)
	var weight = clampf(app.accident_time / 20, 0, 1)
	draw_report(Vector2(800 + app.accident_x, 510 + weight * 140 + sin(clock * 2) * 9), 0.8 + weight * 0.22)
	cinema.hands(Vector2(800 + app.accident_x, 690 + weight * 50), 1)
	for i in range(14):
		cinema.glow(Vector2(680 + app.accident_x + i % 4 * 72, 450 + floori(i / 4.0) * 70 + weight * 130), weight * 35, INK, 0.035)
	draw_colored_polygon(PackedVector2Array([Vector2(280, 470), Vector2(410, 300), Vector2(600, 350), Vector2(680, 480)]), Color("3c4a48"))
	draw_line(Vector2(315, 440), Vector2(590, 355), Color(JADE, 0.55), 4, true)
	if app.accident_time >= 8 and app.accident_time < 18:
		draw_line(Vector2(1450, 300), Vector2(1040, 520), Color("a08d67"), 14, true)
	if app.accident_time >= 18 and app.accident_time < 28:
		draw_polyline(PackedVector2Array([Vector2(80, 210), Vector2(290, 460), Vector2(540, 550)]), GOLD, 4, true)
	if not app.core.settings.reduced_motion:
		for i in range(100):
			var p = Vector2(fposmod(i * 137 + clock * 60, 1600), fposmod(i * 67 + clock * 330, 900))
			draw_line(p, p + Vector2(8, 25), Color(PAPER, 0.12), 1, true)
	if app.accident_time > 28:
		draw_rect(Rect2(0, 0, 1600, 900), Color(0.03, 0.07, 0.08, (app.accident_time - 28) / 7))

func draw_body() -> void:
	draw_rect(Rect2(0, 0, 1600, 650), Color(PAPER, 0.5))
	draw_paper_person(Vector2(600, 450), 0.8)
	draw_paper_person(Vector2(950, 450), 0.8)
	draw_colored_polygon(PackedVector2Array([Vector2(650, 450), Vector2(690, 415), Vector2(870, 420), Vector2(920, 454)]), Color("c8cec4"))
	draw_line(Vector2(665, 452), Vector2(910, 452), INK, 3, true)
	draw_report(Vector2(880, 468), 0.13)

func draw_release() -> void:
	draw_rect(Rect2(0, 0, 1600, 900), Color(INK, 0.5))
	draw_report(Vector2(800 + app.hold_progress * 65, 410), 0.85)
	draw_arc(Vector2(800, 410), 210, -PI / 2, -PI / 2 + TAU * clampf(app.hold_progress / 1.5, 0, 1), 80, GOLD, 5, true)

func draw_stroke() -> void:
	draw_rect(Rect2(310, 235, 980, 350), PAPER)
	if mode == "literacy":
		text_at("家", Vector2(710, 490), 190, Color(INK, 0.4), true)
	else:
		text_at("写清自己所见", Vector2(530, 378), 52)
		text_at("比把别人的句子背熟更要紧。", Vector2(480, 454), 30, Color(INK, 0.7))
	if app.stroke_points.size() > 1:
		draw_polyline(app.stroke_points, RED, 7, true)

func draw_dialogue_portraits() -> void:
	var id: String = app.current_speaker
	var seq: String = app.core.state.dialogue.id
	if seq in ["Inscription", "BodyReveal"]: return
	# Speaker identity must never be substituted with the current memory's host.
	id = app.dialogue_portrait_id()
	if id not in ["Ye", "Ding", "Student", "Wife"]: return
	var amount = 1.0 if app.core.settings.reduced_motion else smoothstep(0, 1, app.dialogue_entrance)
	var breath = 0.0 if app.core.settings.reduced_motion else sin(clock * 1.4) * 2.2
	var rect = Rect2(1010 + (1 - amount) * 18, 110 + breath, 350, 535)
	if id == "Wife": rect = Rect2(1010 + (1 - amount) * 18, 85 + breath, 380, 570)
	cinema.portrait(id, rect, lerpf(0.4, 1.0, amount))

func draw_corridor() -> void:
	draw_rect(Rect2(150, 155, 1300, 550), Color(INK, 0.82))
	for side in [-1, 1]:
		for depth in range(6):
			var z = 1.0 / (1 + depth * 0.38)
			var x = 800 + side * 680 * z
			draw_line(Vector2(x, 160 + (1 - z) * 150), Vector2(x, 700 - (1 - z) * 250), Color(GOLD, z * 0.45), 6 * z, true)
			for shelf in range(3):
				var y = 260 + shelf * 120 * z
				draw_line(Vector2(x, y), Vector2(800 + side * 150, 300 + shelf * 40), Color(PAPER, 0.1), 3, true)
	draw_polyline(PackedVector2Array([Vector2(160, 700), Vector2(690, 410), Vector2(910, 410), Vector2(1440, 700)]), Color(JADE, 0.5), 3, true)

func battle_screen(p: Vector2) -> Vector2:
	var depth = maxf(120, p.x - app.player_pos.x + 180)
	var perspective = 650 / depth
	return Vector2(clampf(800 + (p.y - app.player_pos.y) * perspective, 180, 1420), clampf(330 + 100 * perspective, 250, 680))

func draw_season_details(season: int) -> void:
	var t: float = app.runner_scroll
	for i in range(3):
		var p = Vector2(fposmod(400 + i * 680 - t * 18, 2000) - 100, 615)
		match season:
			0:
				draw_rect(Rect2(p, Vector2(35, 30)), Color("9c7160"))
				for j in range(5):
					var tip = p + Vector2(18 + sin(j * 2) * 20, -28 - j * 7)
					draw_line(p + Vector2(18, 5), tip, JADE, 2, true)
					draw_circle(tip, 6, Color("d8b3af"))
			1:
				for j in range(2):
					var c = p + Vector2(j * 60, 0)
					draw_polyline(PackedVector2Array([c + Vector2(0, 30), c + Vector2(0, -35), c + Vector2(35, -35), c + Vector2(35, 30)]), Color("8f8b5f"), 4, true)
					draw_line(c, c + Vector2(35, 0), INK, 5, true)
			2:
				for j in range(3):
					draw_circle(p + Vector2(j * 35, 0), 21, GOLD)
					draw_arc(p + Vector2(j * 35, 0), 23, 0, TAU, 30, INK, 2, true)
			3:
				for j in range(2):
					var c = p + Vector2(j * 35, 0)
					draw_line(c + Vector2(20, -75), c, Color("8b7960"), 4, true)
					for k in range(7): draw_line(c, c + Vector2(-15 + k * 5, 30), GOLD, 2, true)
	if app.season_time < 3 and not app.runner_tutorial:
		var a = sin(clampf(app.season_time / 3, 0, 1) * PI)
		text_at(["春", "夏", "秋", "冬"][season], Vector2(760, 340), 100, Color(PAPER, a), true)
