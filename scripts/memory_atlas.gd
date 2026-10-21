extends Control
const Card = preload("res://scenes/memory_scroll_card.tscn")
var app
var list: VBoxContainer
var scroll: ScrollContainer
var message: Label
var back_button: Button
var load_more: Button
var entries: Array = []
var rendered = 0
var modal: ConfirmationDialog
var pending_id = ""
var pending_delete = false
var working = false
var last_focus: Control

func setup(owner_app) -> void:
	app = owner_app
	var shade = ColorRect.new()
	shade.color = Color(0.06, 0.12, 0.13, 0.86)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	var margin = MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right"]: margin.add_theme_constant_override("margin_" + edge, 110)
	for edge in ["top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 38)
	add_child(margin)
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var heading = HBoxContainer.new()
	column.add_child(heading)
	var title = Label.new()
	title.text = "记忆图谱"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_override("font", app.title_font)
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", app.PAPER)
	heading.add_child(title)
	back_button = app.button("BackFromAtlas", "返回主菜单", Rect2(), app.show_menu, heading, true)
	back_button.custom_minimum_size = Vector2(250, 60)
	var description = Label.new()
	description.text = "把走过的片刻，留在纸上。" + ("   ·   测试记忆 · 独立目录" if app.memory_test_mode else "")
	description.add_theme_font_size_override("font_size", roundi(22 * app.core.settings.text_scale))
	description.add_theme_color_override("font_color", app.GOLD)
	column.add_child(description)
	scroll = ScrollContainer.new()
	scroll.name = "MemoryScroll"
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	column.add_child(scroll)
	list = VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 22)
	scroll.add_child(list)
	message = Label.new()
	message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	message.add_theme_font_size_override("font_size", roundi(21 * app.core.settings.text_scale))
	message.add_theme_color_override("font_color", app.PAPER)
	column.add_child(message)
	var tools_row = HBoxContainer.new()
	tools_row.add_theme_constant_override("separation", 16)
	column.add_child(tools_row)
	app.button("RefreshMemories", "刷新记忆", Rect2(), refresh, tools_row, true).custom_minimum_size = Vector2(210, 50)
	if app.memory_test_mode:
		app.button("GenerateTestMemory", "生成测试记忆", Rect2(), generate_test, tools_row, true).custom_minimum_size = Vector2(270, 50)
	modal = ConfirmationDialog.new()
	modal.name = "MemoryConfirmation"
	modal.title = "记忆图谱"
	modal.ok_button_text = "确认"
	modal.cancel_button_text = "取消"
	modal.dialog_autowrap = true
	modal.min_size = Vector2i(640, 240)
	modal.theme = app.theme
	modal.add_theme_font_size_override("font_size", roundi(24 * app.core.settings.text_scale))
	var dialog_paper = StyleBoxFlat.new()
	dialog_paper.bg_color = app.PAPER
	dialog_paper.border_color = app.GOLD
	dialog_paper.set_border_width_all(2)
	dialog_paper.set_content_margin_all(24)
	modal.add_theme_stylebox_override("panel", dialog_paper)
	modal.get_label().add_theme_color_override("font_color", app.INK)
	modal.get_label().add_theme_font_size_override("font_size", roundi(24 * app.core.settings.text_scale))
	for control in [modal.get_ok_button(), modal.get_cancel_button()]:
		control.custom_minimum_size = Vector2(180, 55)
		control.add_theme_font_size_override("font_size", roundi(24 * app.core.settings.text_scale))
		for state in ["normal", "hover", "pressed", "focus"]:
			var button_paper = dialog_paper.duplicate()
			button_paper.set_content_margin_all(10)
			button_paper.bg_color = Color("e5d3ac") if state in ["hover", "focus"] else app.PAPER
			control.add_theme_stylebox_override(state, button_paper)
		for state in ["font_color", "font_focus_color", "font_hover_color", "font_pressed_color"]:
			control.add_theme_color_override(state, app.INK)
	add_child(modal)
	modal.confirmed.connect(confirm_action)
	modal.canceled.connect(restore_focus)
	refresh()
	back_button.call_deferred("grab_focus")

func refresh() -> void:
	for child in list.get_children():
		list.remove_child(child)
		child.queue_free()
	rendered = 0
	entries = []
	load_more = null
	var result: Dictionary = app.memory_saves.list_memories()
	if not result.ok:
		message.text = result.error
		return
	entries = result.entries
	if app.has_save:
		var state: Dictionary = app.core.state
		var stamp = null
		if state.get("updated_utc") is String: stamp = Time.get_unix_time_from_datetime_string(state.updated_utc)
		add_card({"id": "current", "title": "当前进度", "chapter": app.memory_saves.chapter_for(state), "source": "current", "story_time": "未记", "saved_at_utc": stamp, "completed": state.completed.size(), "route": state.route, "error": "", "story_id": state.get("story_id", "")})
	append_batch()
	message.text = "共 %d 卷记忆 · 最新保存的片刻在前" % entries.size()
	if entries.size() > 100: message.text += " · 可以删除不再需要的卷轴整理图谱"
	if entries.is_empty(): message.text = "这里还没有留下记忆。走过一段故事后，卷轴会在此展开。"
	if not app.memory_notice.is_empty(): message.text += "\n" + app.memory_notice

func add_card(entry: Dictionary) -> void:
	var card = Card.instantiate()
	list.add_child(card)
	card.setup(entry, app)
	card.read_requested.connect(request_read)
	card.delete_requested.connect(request_delete)
	if rendered < 3 and not app.core.settings.reduced_motion:
		card.modulate.a = 0
		card.create_tween().tween_property(card, "modulate:a", 1.0, 0.2)

func append_batch() -> void:
	if is_instance_valid(load_more):
		list.remove_child(load_more)
		load_more.queue_free()
	var limit = mini(rendered + 20, entries.size())
	while rendered < limit:
		add_card(entries[rendered])
		rendered += 1
	if rendered < entries.size():
		load_more = app.button("MoreMemories", "展开更多记忆", Rect2(), append_batch, list)
		load_more.custom_minimum_size.y = 56

func request_read(id: String) -> void:
	if working: return
	if id == "current":
		app.resume_game()
		return
	var candidate: Dictionary = app.memory_saves.prepare_load(id)
	if not candidate.ok:
		message.text = candidate.error
		return
	pending_id = id
	pending_delete = false
	last_focus = get_viewport().gui_get_focus_owner()
	modal.dialog_text = "将从这卷记忆继续。\n当前进度会先保留，原卷轴不会被改写。\n" + app.memory_saves.resume_hint(candidate.state.route)
	modal.ok_button_text = "读取记忆"
	modal.popup_centered(Vector2i(700, 280))
	modal.get_cancel_button().grab_focus()

func request_delete(id: String) -> void:
	if working: return
	pending_id = id
	pending_delete = true
	last_focus = get_viewport().gui_get_focus_owner()
	modal.dialog_text = "删除这卷记忆？\n删除后无法从图谱恢复，当前故事进度不受影响。"
	modal.ok_button_text = "删除记忆"
	modal.popup_centered(Vector2i(700, 260))
	modal.get_cancel_button().grab_focus()

func confirm_action() -> void:
	if working: return
	working = true
	if pending_delete:
		var position_before = scroll.scroll_vertical
		var index = 0
		for i in entries.size():
			if entries[i].id == pending_id: index = i
		var result: Dictionary = app.memory_saves.delete_memory(pending_id)
		if result.ok:
			app.memory_notice = ""
			refresh()
			while rendered <= index and rendered < entries.size(): append_batch()
			scroll.set_deferred("scroll_vertical", position_before)
			if not entries.is_empty():
				var next_card = list.get_node_or_null("Memory_" + entries[mini(index, entries.size() - 1)].id)
				if next_card != null: next_card.read_button.call_deferred("grab_focus")
			else: back_button.call_deferred("grab_focus")
		else: message.text = result.error
		if not result.ok: restore_focus()
	else:
		var result: Dictionary = app.memory_saves.load_memory(pending_id)
		if result.ok:
			app.has_save = true
			app.memory_notice = ""
			app.resume_game()
		else:
			message.text = result.error
			restore_focus()
	working = false

func restore_focus() -> void:
	if is_instance_valid(last_focus): last_focus.call_deferred("grab_focus")
	else: back_button.call_deferred("grab_focus")

func generate_test() -> void:
	if not app.memory_test_mode or not app.memory_test_generator.is_valid(): return
	var result: Dictionary = app.memory_test_generator.call(app)
	refresh()
	message.text = "测试记忆已写入独立目录。可重启后读取、删除。" if result.ok else result.error
