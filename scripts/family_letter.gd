extends Control
## Presentation only: narrative text and progression remain owned by the app/core.
const ART = preload("res://assets/family-letter-v1.png")
const HAND = preload("res://assets/fonts/LXGWWenKai-Regular.ttf")
const INK = Color("4b352c")
const MUTED = Color("8b715b")
const VERMILION = Color("814539")
var envelope: TextureRect
var paper: TextureRect
var address: Control
var writing: Control
var opened = 0.0:
	set(value):
		opened = value
		if is_instance_valid(envelope):
			envelope.position = Vector2(270, 118).lerp(Vector2(440, 390), value)
			envelope.scale = Vector2.ONE.lerp(Vector2(0.68, 0.68), value)
			envelope.modulate.a = 1.0 - smoothstep(0.12, 0.42, value)
			address.modulate.a = 1.0 - value
		if is_instance_valid(paper):
			paper.visible = value > 0
			paper.scale = Vector2(lerpf(0.78, 1.0, value), lerpf(0.16, 1.0, value))
			paper.modulate.a = smoothstep(0.10, 0.30, value)
		if is_instance_valid(writing):
			writing.modulate.a = smoothstep(0.72, 1.0, value)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1600, 900)

func _draw() -> void:
	# Warm, quiet close-up after the moving four-season chase.
	draw_rect(Rect2(0, 0, 1600, 900), Color("e8ddcd"))
	for i in range(90):
		var edge = absf(i - 40.0) / 55.0
		draw_rect(Rect2(0, i * 10, 1600, 10), Color(0.46, 0.34, 0.23, edge * 0.075))
	for i in range(1800):
		var p = Vector2(fposmod(i * 179.37, 1600), fposmod(i * 97.13, 900))
		draw_line(p, p + Vector2(1.3, 0.5), Color(0.45, 0.31, 0.2, 0.045), 1, true)
	draw_line(Vector2(64, 103), Vector2(270, 103), Color(MUTED, 0.25), 1, true)
	draw_line(Vector2(1330, 103), Vector2(1536, 103), Color(MUTED, 0.25), 1, true)

func art_tile(index: int, rect: Rect2) -> TextureRect:
	var atlas = AtlasTexture.new()
	atlas.atlas = ART
	var cell = ART.get_size() * Vector2(1, 0.5)
	atlas.region = Rect2(Vector2(0, index * cell.y), cell)
	atlas.filter_clip = true
	var node = TextureRect.new()
	node.texture = atlas
	node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	node.position = rect.position
	node.size = rect.size
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(node)
	return node

func words(value: String, rect: Rect2, px: int, color: Color, parent: Control = self) -> Label:
	var node = Label.new()
	node.text = value
	node.position = rect.position
	node.size = rect.size
	node.add_theme_font_override("font", HAND)
	node.add_theme_font_size_override("font_size", px)
	node.add_theme_color_override("font_color", color)
	node.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	node.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func setup(reading: bool, folding: bool, body: String, text_scale: float) -> void:
	words("若 如 初 见   /   家 书", Rect2(530, 32, 540, 40), 21, MUTED)
	words("见字如晤" if reading else ("把牵挂，收进怀里" if folding else "有一封信，为你而来"), Rect2(430, 73, 740, 54), 34, INK)
	envelope = art_tile(0, Rect2(270, 118, 1060, 650))
	envelope.name = "Envelope"
	address = Control.new()
	address.mouse_filter = Control.MOUSE_FILTER_IGNORE
	envelope.add_child(address)
	words("叶 生", Rect2(400, 430, 260, 76), 52, INK, address)
	words("亲  启", Rect2(455, 507, 150, 35), 21, MUTED, address)
	paper = art_tile(1, Rect2(160, 116, 1280, 690))
	paper.name = "Paper"
	paper.pivot_offset = paper.size * 0.5
	writing = Control.new()
	writing.name = "Writing"
	writing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(writing)
	if reading or folding:
		write_vertical(body, text_scale)
	opened = 1.0 if reading or folding else 0.0
	var step = 2 if folding else (1 if reading else 0)
	for i in range(3):
		words(["一 · 信至", "二 · 展信", "三 · 珍藏"][i], Rect2(560 + i * 160, 857, 160, 30), 18, VERMILION if i == step else Color(MUTED, 0.65))

func write_vertical(body: String, text_scale: float) -> void:
	# Split the authored text at punctuation; punctuation stays with its phrase.
	# The original string remains available in main.dialogue_label for history.
	var columns: Array[String] = []
	var phrase = ""
	for ch in body:
		if ch in ["\n", "\r"]: continue
		phrase += ch
		if ch in ["，", "；", "。", "！", "？"]:
			columns.append(phrase)
			phrase = ""
	if not phrase.is_empty(): columns.append(phrase)
	var px = roundi(35 * text_scale)
	var row_step = 40.0 * text_scale
	var column_gap = minf(103, 810.0 / maxf(1, columns.size() - 1))
	for col in range(columns.size()):
		var x = 1175.0 - col * column_gap
		for row in range(columns[col].length()):
			var ch = columns[col][row]
			var punctuation = ch in ["，", "；", "。", "！", "？"]
			var node = words(ch, Rect2(x, 213 + row * row_step, 64, row_step + 8), px, INK, writing)
			node.name = "Glyph_%d_%d" % [col, row]
			if punctuation:
				node.position += Vector2(13, -row_step * 0.48)
	words("妻\n书", Rect2(335, 510, 60, 108), roundi(29 * text_scale), INK, writing)
	var seal = Panel.new()
	seal.position = Vector2(348, 630)
	seal.size = Vector2(34, 34)
	seal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(VERMILION, 0.07)
	style.border_color = Color(VERMILION, 0.7)
	style.set_border_width_all(1)
	seal.add_theme_stylebox_override("panel", style)
	writing.add_child(seal)
	words("安", Rect2(0, 0, 34, 34), 22, VERMILION, seal)

func style_button(node: Button, primary: bool = true) -> void:
	node.add_theme_font_override("font", HAND)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = VERMILION if primary else Color(1, 1, 1, 0.08)
		if state in ["hover", "focus"]: style.bg_color = Color("a1664e") if primary else Color("d7c5aa")
		if state == "pressed": style.bg_color = Color("61372e")
		style.border_color = Color("c3a178")
		style.set_border_width_all(2 if state == "focus" else 1)
		style.set_corner_radius_all(3)
		node.add_theme_stylebox_override(state, style)
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color"]:
		node.add_theme_color_override(state, Color("fff1da") if primary else INK)
