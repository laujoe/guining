extends PanelContainer
signal read_requested(id: String)
signal delete_requested(id: String)
var entry: Dictionary
var app
var read_button: Button

func setup(data: Dictionary, owner_app) -> void:
	entry = data
	app = owner_app
	name = "Memory_" + data.id
	var paper = StyleBoxFlat.new()
	paper.bg_color = Color("efe5cd")
	paper.border_color = Color("b8a17b")
	paper.set_border_width_all(1)
	paper.content_margin_left = 40
	paper.content_margin_right = 40
	paper.content_margin_top = 20
	paper.content_margin_bottom = 20
	paper.shadow_size = 6
	paper.shadow_color = Color(0, 0, 0, 0.18)
	add_theme_stylebox_override("panel", paper)
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", 30)
	add_child(row)
	var content = VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", 7)
	row.add_child(content)
	add_text(content, data.title, 30, app.INK)
	if not data.get("error", "").is_empty():
		add_text(content, data.error, 22, app.RED)
	else:
		var source = {"auto": "自动记忆", "manual": "手动记忆", "legacy": "旧档记忆", "test": "测试记忆", "preserved": "读取前保留", "current": "当前进度"}.get(data.source, "记忆")
		var story = "" if data.get("story_id", "").is_empty() else " · 故事 " + data.story_id.substr(0, 6)
		add_text(content, data.chapter + " · " + source + story, 19, Color("5c6857"))
		add_text(content, "故事时辰：" + data.story_time + "    已寻回记忆 %d / 3" % int(data.completed), 21, app.INK)
		add_text(content, "保存于：" + app.memory_saves.local_time(data.saved_at_utc) + "（本机时间）", 19, Color("646b62"))
		add_text(content, app.memory_saves.resume_hint(data.route), 19, Color("646b62"))
	var actions = VBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.custom_minimum_size.x = 170
	actions.add_theme_constant_override("separation", 14)
	row.add_child(actions)
	read_button = app.button("ReadMemory", "读取", Rect2(), func(): read_requested.emit(data.id), actions)
	read_button.custom_minimum_size = Vector2(170, 54)
	read_button.disabled = not data.get("error", "").is_empty()
	if data.id != "current":
		var remove = app.button("DeleteMemory", "删除", Rect2(), func(): delete_requested.emit(data.id), actions)
		remove.custom_minimum_size = Vector2(170, 48)
		remove.add_theme_color_override("font_color", Color("85584a"))
	queue_redraw()

func add_text(parent: Control, value: String, px: int, color: Color) -> void:
	var text = Label.new()
	text.text = value
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.add_theme_font_size_override("font_size", roundi(px * app.core.settings.text_scale))
	text.add_theme_color_override("font_color", color)
	parent.add_child(text)

func _draw() -> void:
	for x in [10.0, size.x - 18.0]:
		draw_style_box(axis_style(), Rect2(x, 7, 8, size.y - 14))
		for y in [4.0, size.y - 12.0]:
			draw_circle(Vector2(x + 4, y + 4), 6, Color("7f6950"))

func axis_style() -> StyleBoxFlat:
	var style = StyleBoxFlat.new()
	style.bg_color = Color("a88b62")
	style.set_corner_radius_all(4)
	return style
