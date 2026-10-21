extends Control

const Core = preload("res://scripts/game_core.gd")
const Stage = preload("res://scripts/stage.gd")
const FamilyLetter = preload("res://scripts/family_letter.gd")
const MemorySaves = preload("res://scripts/memory_save_system.gd")
const MemoryAtlas = preload("res://scenes/memory_atlas.tscn")
const MusicLibrary = preload("res://scripts/music_library.gd")
var memory_saves
var memory_notice = ""
var memory_test_mode = false
var memory_test_generator: Callable
var memory_test_fixture: RefCounted
var pending_manual_id = ""
const INK = Color("25393b")
const PAPER = Color("efe6d2")
const JADE = Color("839784")
const GOLD = Color("d1a567")
const RED = Color("9c4637")
const NAMES = {"Ye": "叶生", "Ding": "丁乘鹤", "Student": "丁再昌", "Wife": "叶妻", "Letter": "家书", "Object": "玉上旧字", "Villager": "村民", "Child": "孩子"}
const CARD_NAMES = {"Soldier": "纸兵", "InkArrow": "墨箭", "Brush": "毛笔", "Kite": "纸鸢", "Inkstone": "砚台", "Dragon": "纸龙"}
var card_names = CARD_NAMES
var core = Core.new()
var stage
var ui: Control
var overlay: Control
var font: Font
var title_font: Font
var mode = "menu"
var paused = false
var busy = false
var has_save = false
var current_speaker = ""
var music_key = ""
var music_fade: Tween
var music_gain = 1.0
var music_track = ""
var music_target = ""
var dialogue_label: RichTextLabel
var reveal = 0.0
var current_text = ""
var hint_card = ""
var idle_time = 0.0
var status_label: Label
var subtitle: Label
var travel_t = 0.0
var travel_target = ""
var dragging_lamp = false
var maze_forward = 0.0
var maze_turn = 0.0
var maze_save_clock = 0.0
var graph_rotating = false
var graph_rotation = 0.0
var graph_from_view = 0
var graph_turn_dir = 1
var active_tween: Tween
var tween_was_running = false
var audio_player: AudioStreamPlayer
var note_player: AudioStreamPlayer
var ambient_index = -1
var scene_age = 0.0
var line_age = 0.0
var dialogue_entrance = 0.0
var transition_view: TextureRect
var transition_left = 0.0
var transition_duration = 0.85
var jade_flip = 0.0
var cinematic_step = 0
var auto_dialogue = false

# Battle has no shared physics with the runner or the shadow puzzle.
var player_pos = Vector2(510, 440)
var move_dir = Vector2.ZERO
var facing = Vector2.RIGHT
var bullets: Array = []
var battle_hits = 0
var battle_mistakes = 0
var battle_elapsed = 0.0
var shot_timer = 1.0
var attack_warning = 0.0
var battle_aim = Vector2.ZERO
var brush_time = 0.0
var brush_cooldown = 0.0
var dodge_time = 0.0
var dodge_cooldown = 0.0
var invincible = 0.0
var hazard_warning = 0.0
var hazard_active = 0.0
var hazard_y = 430.0
var hazard_x = 1300.0
var hazard_kind = "charge"
var charge_pos = Vector2.ZERO
var charge_end = Vector2.ZERO
var charge_from = Vector2.ZERO
var charge_progress = 0.0
var folded_time = 0.0
var between_attack_used = false

var season_time = 0.0
var jump_height = 0.0
var jump_velocity = 0.0
var jump_buffer = 0.0
var slide_time = 0.0
var slide_cooldown = 0.0
var stumble_protect = 0.0
var bracing = false
var obstacles: Array = []
var spawned: Array = []
var runner_tutorial = false
var tutorial_time = 0.0
var letter_distance = 0.35
var runner_scroll = 0.0

var jade_positions: Array = [Vector2(420, 420), Vector2(1180, 320), Vector2(1120, 590)]
var selected_jade = 0
var dragging_jade = false
var drag_offset = Vector2.ZERO
var jade_time = 0.0
var hold_progress = 0.0
var hold_delay = 0.0
var mouse_hold = false
var accident_time = 0.0
var accident_x = 0.0
var stroke_points = PackedVector2Array()
var drawing_stroke = false
var stroke_done = false
var release_armed = true
var touch_controls = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available() or "--touch-controls" in OS.get_cmdline_user_args()
var touch_actions: Dictionary = {}

func _ready() -> void:
	font = preload("res://assets/fonts/LXGWWenKai-Regular.ttf").duplicate()
	font.allow_system_fallback = false
	title_font = font.duplicate()
	title_font.allow_system_fallback = false
	title_font.fallbacks = [font]
	var theme_value = Theme.new()
	theme_value.default_font = font
	theme_value.default_font_size = 24
	for slot in ["normal_font", "bold_font", "italics_font", "bold_italics_font", "mono_font"]:
		theme_value.set_font(slot, "RichTextLabel", font)
	theme = theme_value
	stage = Stage.new()
	stage.app = self
	stage.font = font
	stage.title_font = title_font
	stage.small_font = font
	stage.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(stage)
	ui = Control.new()
	ui.name = "Interface"
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui)
	overlay = Control.new()
	overlay.name = "Overlay"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	transition_view = TextureRect.new()
	transition_view.size = Vector2(1600, 900)
	transition_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	transition_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(transition_view)
	move_child(overlay, -1)
	audio_player = AudioStreamPlayer.new()
	add_child(audio_player)
	audio_player.finished.connect(func(): audio_player.play())
	note_player = AudioStreamPlayer.new()
	add_child(note_player)
	if OS.is_debug_build() and "--memory-atlas-test" in OS.get_cmdline_user_args() and FileAccess.file_exists("res://tests/memory_fixture.gd"):
		var fixture = load("res://tests/memory_fixture.gd").new()
		fixture.configure(self)
	core.load_settings()
	has_save = core.load_game()
	memory_saves = MemorySaves.new(core)
	var imported = memory_saves.import_legacy_once()
	if not imported.ok: memory_notice = imported.error
	get_window().focus_exited.connect(_on_focus_lost)
	get_tree().auto_accept_quit = false
	show_menu()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if paused: close_modal()
		elif mode != "menu": open_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		if mode in ["menu", "memory_atlas"] or core.save_game():
			get_tree().quit()
		else:
			open_pause()

func _on_focus_lost() -> void:
	if not mode in ["menu", "memory_atlas"] and not paused:
		open_pause()

func clear_layer(layer: Control) -> void:
	if layer == ui:
		touch_actions.clear()
	for child in layer.get_children():
		layer.remove_child(child)
		child.queue_free()

func panel(rect: Rect2, parent: Control = ui, color = PAPER, border = Color(INK, 0.22)) -> Panel:
	var p = Panel.new()
	p.position = rect.position
	p.size = rect.size
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(1)
	style.shadow_color = Color(0, 0, 0, 0.12)
	style.shadow_size = 9
	p.add_theme_stylebox_override("panel", style)
	parent.add_child(p)
	return p

func label(value: String, rect: Rect2, size_px = 24, color = INK, parent: Control = ui, literary = false) -> Label:
	var l = Label.new()
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.text = value
	l.position = rect.position
	l.size = rect.size
	l.add_theme_color_override("font_color", color)
	l.add_theme_font_size_override("font_size", roundi(size_px * core.settings.text_scale))
	# Reserve the expressive brush face for large literary headings.
	# Names, captions and small text keep WenKai's readable, consistent rhythm.
	if literary and size_px >= 34:
		l.add_theme_font_override("font", title_font)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	l.size = rect.size
	return l

func button(id: String, value: String, rect: Rect2, action: Callable, parent: Control = ui, dark = false) -> Button:
	var b = Button.new()
	b.name = id
	b.text = value
	b.position = rect.position
	b.size = rect.size
	b.add_theme_font_size_override("font_size", roundi(24 * core.settings.text_scale))
	b.add_theme_color_override("font_color", PAPER if dark else INK)
	b.add_theme_color_override("font_hover_color", INK)
	b.add_theme_color_override("font_focus_color", INK)
	b.add_theme_color_override("font_pressed_color", INK)
	b.add_theme_color_override("font_disabled_color", Color(JADE, 0.7))
	for state_name in ["normal", "hover", "pressed", "focus", "disabled"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(INK, 0.82) if dark else Color(PAPER, 0.96)
		if state_name in ["hover", "focus"]:
			style.bg_color = Color("e5d3ac")
		if state_name == "pressed":
			style.bg_color = GOLD
		if state_name == "disabled":
			style.bg_color = Color(INK, 0.18)
		style.border_color = GOLD if state_name in ["hover", "focus"] else Color(JADE, 0.7)
		style.set_border_width_all(2 if state_name == "focus" else 1)
		style.set_content_margin_all(8)
		if mode in ["board", "ding_graph"] and parent == ui:
			style.set_corner_radius_all(3)
			style.shadow_color = Color(0.08, 0.05, 0.02, 0.26)
			style.shadow_size = 4
			style.shadow_offset = Vector2(1, 3)
			if state_name == "disabled":
				style.bg_color = Color("b9ae96")
				b.add_theme_color_override("font_disabled_color", Color("6f6858"))
		b.add_theme_stylebox_override(state_name, style)
	b.pressed.connect(func():
		if busy and parent != overlay and id != "Pause":
			return
		play_note()
		action.call()
		if mode in ["army", "dragon", "runner", "jade", "ding_lamp"]:
			get_viewport().gui_release_focus())
	parent.add_child(b)
	return b

func slider(id: String, value: float, rect: Rect2, changed: Callable, parent: Control = ui) -> HSlider:
	var s = HSlider.new()
	s.name = id
	s.position = rect.position
	s.size = rect.size
	s.min_value = 0
	s.max_value = 1
	s.step = 0.005
	s.value = value
	s.value_changed.connect(changed)
	parent.add_child(s)
	return s

func touch_button(id: String, caption: String, rect: Rect2, action: String, triggered: Callable = Callable()) -> Node2D:
	# TouchScreenButton tracks individual fingers, allowing movement + action together.
	var holder = Node2D.new()
	holder.name = id
	holder.position = rect.position
	ui.add_child(holder)
	var visual = Panel.new()
	visual.size = rect.size
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style = StyleBoxFlat.new()
	style.bg_color = Color(INK, 0.88)
	style.border_color = GOLD
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	visual.add_theme_stylebox_override("panel", style)
	holder.add_child(visual)
	var caption_label = Label.new()
	caption_label.text = caption
	caption_label.size = rect.size
	caption_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_label.add_theme_font_override("font", font)
	caption_label.add_theme_font_size_override("font_size", 28)
	caption_label.add_theme_color_override("font_color", PAPER)
	holder.add_child(caption_label)
	var touch = TouchScreenButton.new()
	touch.name = "Touch"
	var shape = RectangleShape2D.new()
	shape.size = rect.size
	touch.shape = shape
	touch.position = rect.size / 2
	touch.pressed.connect(func():
		if paused or busy: return
		touch_actions[action] = true
		visual.modulate = Color("d1a567")
		if triggered.is_valid(): triggered.call())
	touch.released.connect(func():
		touch_actions.erase(action)
		visual.modulate = Color.WHITE)
	holder.add_child(touch)
	return holder

func touch_axis(positive: String, negative: String) -> float:
	return float(touch_actions.has(positive)) - float(touch_actions.has(negative))

func set_touch_input(enabled: bool) -> void:
	for child in ui.get_children():
		if child is Node2D and child.has_node("Touch"):
			child.get_node("Touch").set_process_input(enabled)

func header(title: String, caption: String) -> void:
	panel(Rect2(42, 29, 690, 105), ui, Color(INK, 0.83), Color(GOLD, 0.4))
	label(title, Rect2(67, 34, 620, 54), 36, PAPER, ui, true)
	label(caption, Rect2(70, 90, 620, 32), 18, Color("cbd2c8"))
	button("Pause", "Ⅱ", Rect2(1480, 34, 66, 54), open_pause, ui, true)
	status_label = label("", Rect2(175, 825, 1250, 55), 21, PAPER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func cinematic_controls() -> void:
	button("Pause", "Ⅱ", Rect2(1480, 18, 66, 42), open_pause, ui, true)
	status_label = label("", Rect2(175, 825, 1250, 55), 21, PAPER)

func show_menu() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()
	busy = false
	paused = false
	audio_player.stream_paused = false
	clear_layer(overlay)
	clear_layer(ui)
	scene_age = 0
	transition_left = 0
	transition_view.visible = false
	mode = "menu"
	stage.mode = mode
	stage.bg_index = 0
	stage.dim = 0.0
	dialogue_label = null
	set_ambience(0)
	label("一段关于归途的故事", Rect2(130, 135, 470, 40), 21, Color("d1b68d"))
	label("归 宁", Rect2(115, 190, 550, 155), 112, PAPER, ui, true)
	label("纸上留人，灯下留席。", Rect2(137, 360, 500, 50), 27, Color("d9d6c6"), ui, true)
	var menu = VBoxContainer.new()
	menu.name = "MenuButtons"
	menu.position = Vector2(140, 440)
	menu.size.x = 340
	menu.add_theme_constant_override("separation", 12)
	ui.add_child(menu)
	button("NewStory", "新 的 故 事", Rect2(), request_new, menu, true).custom_minimum_size = Vector2(340, 60)
	if has_save:
		button("Continue", "续 上 一 页", Rect2(), resume_game, menu, true).custom_minimum_size.y = 60
	button("MemoryAtlasButton", "记 忆 图 谱", Rect2(), show_memory_atlas, menu, true).custom_minimum_size.y = 60
	var small_buttons = HBoxContainer.new()
	small_buttons.add_theme_constant_override("separation", 12)
	menu.add_child(small_buttons)
	for item in [["Settings", "设 定", open_settings], ["Quit", "离 开", func(): get_tree().quit()]]:
		var control = button(item[0], item[1], Rect2(), item[2], small_buttons, true)
		control.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		control.custom_minimum_size.y = 54
	if core.state.finished:
		button("Codex", "故 人", Rect2(), show_codex, menu, true).custom_minimum_size.y = 54
	label("水墨叙事 · 三段回忆 · 一次归宁", Rect2(138, 810, 710, 35), 18, Color("cbd2c8"))
	button("MusicCredits", "配乐鸣谢", Rect2(1280, 760, 220, 48), show_music_credits, ui, true)
	button("ProjectLicense", "许可与来源", Rect2(1030, 760, 220, 48), show_project_license, ui, true)
	label("G U I N I N G  /  试玩版 " + str(ProjectSettings.get_setting("application/config/version", "0.1.3")), Rect2(1150, 828, 400, 35), 16, PAPER)
	if not core.save_error.is_empty():
		label(core.save_error, Rect2(600, 750, 850, 100), 23, PAPER)
	elif not memory_notice.is_empty():
		label(memory_notice, Rect2(600, 750, 850, 100), 23, PAPER)

func show_memory_atlas() -> void:
	show_menu()
	clear_layer(ui)
	mode = "memory_atlas"
	# Leave the stage on the menu background; UI route never enters saved gameplay state.
	var atlas = MemoryAtlas.instantiate()
	ui.add_child(atlas)
	atlas.setup(self)

func modal_base(title: String, height = 510.0) -> void:
	touch_actions.clear()
	mouse_hold = false
	set_touch_input(false)
	maze_forward = 0; maze_turn = 0; dragging_lamp = false
	stage.lantern_maze.walking = false
	paused = true
	audio_player.stream_paused = true
	if music_fade != null and music_fade.is_valid(): music_fade.pause()
	tween_was_running = tween_was_running or (active_tween != null and active_tween.is_valid() and active_tween.is_running())
	if tween_was_running:
		active_tween.pause()
	clear_layer(overlay)
	var shade = ColorRect.new()
	shade.color = Color(INK, 0.65)
	shade.size = Vector2(1600, 900)
	overlay.add_child(shade)
	panel(Rect2(365, (900 - height) / 2, 870, height), overlay, PAPER)
	label(title, Rect2(410, (900 - height) / 2 + 26, 760, 64), 38, INK, overlay, true)

func close_modal() -> void:
	clear_layer(overlay)
	paused = false
	set_touch_input(true)
	audio_player.stream_paused = false
	if music_fade != null and music_fade.is_valid(): music_fade.play()
	mouse_hold = false
	dragging_jade = false
	drawing_stroke = false
	if tween_was_running and active_tween != null and active_tween.is_valid():
		active_tween.play()
	tween_was_running = false
	get_viewport().gui_release_focus()

func request_new() -> void:
	if FileAccess.file_exists(core.save_path):
		modal_base("从第一页开始")
		label("现有故事将先保留为归档文件。\n新的旅程会重新收集记忆，设定保留。", Rect2(415, 340, 760, 110), 26, INK, overlay)
		button("ConfirmNew", "开始新故事", Rect2(420, 540, 330, 65), start_new, overlay)
		button("CancelNew", "留在此页", Rect2(830, 540, 330, 65), close_modal, overlay)
	else:
		start_new()

func start_new() -> void:
	if not core.new_story():
		show_menu()
		return
	has_save = true
	pending_manual_id = ""
	close_modal()
	go("report")

func resume_game() -> void:
	close_modal()
	go(core.state.route, false)

func commit() -> bool:
	var success = core.save_game()
	if success and memory_saves != null:
		var recorded = memory_saves.save_checkpoint()
		memory_notice = "" if recorded.ok else "当前进度已保存，收入图谱失败。" + recorded.error
	if not success and is_instance_valid(status_label):
		status_label.text = core.save_error
	return success

func save_manual_memory() -> void:
	if not commit():
		label(core.save_error, Rect2(420, 680, 760, 85), 22, RED, overlay)
		return
	if pending_manual_id.is_empty(): pending_manual_id = core.new_id()
	var recorded = memory_saves.save_memory(core.state, {"id": pending_manual_id})
	if recorded.ok:
		pending_manual_id = ""
		close_modal()
		if is_instance_valid(status_label): status_label.text = "这一刻，已收入记忆图谱。"
	else:
		label("当前进度已保存，收入图谱失败，可重试。\n" + recorded.error, Rect2(420, 680, 760, 95), 22, RED, overlay)

func say(id: String, next: String) -> void:
	if core.dialogue[id].requiresInscriptionSeen and not core.state.inscription:
		push_error("Inscription sequence was gated.")
		return
	core.state.dialogue = {"id": id, "index": 0, "next": next}
	go("dialogue")

func go(next: String, save = true) -> void:
	if active_tween != null and active_tween.is_valid(): active_tween.kill()
	var continuous_ding: bool = stage.ding_story.visible and Stage.DingStory.handles_route(next, core.state.dialogue.get("id", ""), core.state.memory)
	var continuous_student: bool = stage.student_story.visible and Stage.StudentStory.handles_route(next, core.state.dialogue.get("id", ""), core.state.memory)
	var continuous_letter: bool = ui.has_node("FamilyLetter") and (next in ["letter_open", "letter_fold"] or (next == "dialogue" and core.state.dialogue.get("id", "") == "WifeLetter"))
	var continuous_wife: bool = stage.wife_arrival.handles(self) and Stage.WifeArrival.handles_route(next, core.state.dialogue.get("id", ""))
	var continuous_farewell: bool = stage.wife_farewell.visible and Stage.WifeFarewell.handles_route(next, core.state.dialogue.get("id", ""), core.state.memory)
	if continuous_ding or continuous_letter or continuous_wife or continuous_farewell or continuous_student:
		transition_left = 0
		transition_view.visible = false
		transition_view.texture = null
	else:
		begin_transition()
	scene_age = 0
	cinematic_step = 0
	auto_dialogue = false
	busy = false
	travel_t = 0
	travel_target = ""
	idle_time = 0
	graph_rotating = false
	dragging_lamp = false
	dialogue_label = null
	stroke_points.clear()
	stroke_done = false
	drawing_stroke = false
	mouse_hold = false
	mode = next
	core.state.route = next
	if save:
		commit()
	clear_layer(ui)
	stage.mode = mode
	stage.dim = 0.2
	stage.bg_index = background_for_route(next)
	match next:
		"hub": build_hub()
		"report":
			header("序 · 雾中醒来", "一纸喜讯，尚未送到家中。")
			button("OpenReport", "展开怀中的纸卷", Rect2(610, 680, 380, 66), func(): core.state.prologue = true; say("Prologue", "hub"))
		"dialogue": build_dialogue()
		"ding_lamp": build_lamp()
		"ding_graph": build_graph()
		"ding_table":
			cinematic_controls()
			label("淡饭余温  /  灯下留席", Rect2(68, 30, 950, 44), 24, PAPER, ui, true)
		"wife_arrival":
			cinematic_controls()
			button("SkipArrival", "跳过演出 ›", Rect2(1310, 824, 235, 48), func(): say("WifeDeparture", "runner"), ui, true)
		"release_echo", "finale": cinematic_controls()
		"ding_place":
			build_ding_controls("灯下，还留着一副碗筷。")
			button("PlaceManuscript", "递上书稿", Rect2(1110, 793, 400, 62), func(): core.event("ManuscriptPlaced"); say("DingDinner", "ding_seat"))
		"ding_seat":
			build_ding_controls("文章已经放下。那一次，他却仍没有坐下。")
			button("RememberDinner", "想起那次饭约", Rect2(1110, 793, 400, 62), func(): say("DingPastChoice", "ding_reflection"))
		"ding_reflection": say("DingReflection", "ding_shard")
		"ding_shard", "student_shard", "wife_shard": build_shard()
		"fragment": build_fragment()
		"board": build_board()
		"army", "dragon": start_battle()
		"review": build_stroke(false)
		"runner": start_runner()
		"letter_open":
			build_letter_arrival()
		"wife_reflection": say("WifeReflection", "wife_shard")
		"letter_fold":
			build_letter_fold()
		"jade", "flip": build_jade()
		"accident_prompt":
			cinematic_controls()
		"accident": start_accident()
		"body":
			cinematic_controls()
		"release": build_release()
		"dinner_call":
			say("DinnerCall", "reply")
			auto_dialogue = true
		"reply":
			header("灯下留席", "她在等一个回答。")
			button("Reply", "来了", Rect2(650, 690, 300, 80), func(): core.event("ReplyChosen"); go("seat"))
		"seat", "literacy":
			go("finale")
		"credits": build_credits()
	set_ambience(stage.bg_index)
	if is_instance_valid(status_label):
		if not core.save_error.is_empty(): status_label.text = core.save_error
		elif not memory_notice.is_empty(): status_label.text = memory_notice

func background_for_route(route: String) -> int:
	if route.begins_with("ding"):
		return 1 if route in ["ding_lamp", "ding_graph"] else 2
	if route in ["board", "army", "dragon", "review", "student_shard", "reply", "seat", "literacy", "dinner_call", "credits", "finale"]:
		return 2
	if route.begins_with("wife") or route in ["runner", "letter_open", "letter_fold", "wife_arrival"]:
		return 3
	if route == "dialogue":
		var seq: String = core.state.dialogue.id
		if seq.begins_with("Ding"):
			return 1 if seq in ["DingIntro", "DingLampEcho"] else 2
		if seq.begins_with("Student") or seq in ["DinnerCall", "FinalDinner", "FinalLiteracy"]:
			return 2
		if seq.begins_with("Wife"):
			return 3
	return 0

func build_hub() -> void:
	header("雾中渡口", ["走近一件旧物，唤起一段记忆。", "记起一人", "记起两人", "归路渐明 · 三段记忆已经归来"][core.state.completed.size()])
	var hints = ["一盏灯，一顿未赴的饭。", "旧稿里的笔迹，仍有余温。", "风起时，有一封信未读。"]
	for i in range(3):
		var id: String = core.MEMORY_IDS[i]
		var done = id in core.state.completed
		button("Memory_" + id, core.narrative.titles[id] + (" · 重温" if done else ""), Rect2(stage.hub_points[i] + Vector2(-150, 72), Vector2(300, 60)), func(): preview_memory(id))
		label(hints[i], Rect2(stage.hub_points[i] + Vector2(-170, 135), Vector2(340, 45)), 20, PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	if core.state.completed.size() == 3:
		button("JadeTable", "玉佩已齐 · 前往木桌", Rect2(560, 240, 480, 66), func(): go("jade" if not core.state.inscription else "accident_prompt"))
	if core.state.finished:
		button("Codex", "故人", Rect2(1115, 40, 130, 52), show_codex, ui, true)

func preview_memory(id: String) -> void:
	modal_base(core.narrative.titles[id])
	var captions = {"Ding": "丁乘鹤｜知我文章，督我勤学。\n\n书楼深处，一盏灯始终亮着。", "Student": "丁再昌｜丁公之子，我的学生。\n\n旧日的习作里，藏着自己的意思。", "Wife": "叶妻｜将玉佩交给我的人。\n\n那封没来得及读的信，被风轻轻掀起。"}
	if id == "Wife": captions[id] = core.narrative.subtitles.Wife + "\n\n" + core.narrative.wife_question
	label(captions[id], Rect2(415, 315, 760, 180), 26, INK, overlay)
	button("EnterMemory", "重温这段记忆" if id in core.state.completed else "走进记忆", Rect2(420, 540, 330, 65), func(): close_modal(); enter_memory(id), overlay)
	button("ClosePreview", "留在渡口", Rect2(830, 540, 330, 65), close_modal, overlay)

func enter_memory(id: String) -> void:
	core.state.memory = id
	match id:
		"Ding":
			core.state.shadow = {"node": "A", "view": 0, "lamp": 0.15}
			core.state.lamp1 = 0.15
			core.reset_lantern_maze()
			say("DingIntro", "ding_lamp")
		"Student":
			core.new_board()
			say("StudentIntro", "board")
		"Wife":
			core.state.season = 0
			core.state.stumbles = 0
			go("wife_arrival")

func build_dialogue() -> void:
	var d: Dictionary = core.state.dialogue
	var line: Dictionary = core.dialogue[d.id].lines[int(d.index)]
	current_speaker = line.speakerId
	current_text = line.text
	reveal = 0
	line_age = 0
	dialogue_entrance = 0
	if d.id == "WifeLetter":
		build_full_letter()
		return
	if Stage.StudentStory.dialogue_handles(d.id):
		build_student_dialogue(line)
		return
	if Stage.DingStory.dialogue_handles(d.id) or d.id in ["WifeDeparture", "WifeReflection"]:
		build_ding_dialogue(line)
		return
	header(core.narrative.titles.get(core.state.memory, "归宁") if not d.id in ["Prologue", "Inscription", "AccidentEcho", "BodyReveal", "DinnerCall", "FinalDinner", "FinalLiteracy"] else "归宁", "旧事，在此停留片刻。")
	panel(Rect2(165, 650, 1270, 214), ui, Color(PAPER, 0.97))
	label(NAMES.get(line.speakerId, ""), Rect2(205, 668, 300, 40), 27, RED, ui, true)
	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(205, 721)
	dialogue_label.size = Vector2(1165, 115)
	dialogue_label.text = current_text
	dialogue_label.add_theme_color_override("default_color", INK)
	dialogue_label.add_theme_font_size_override("normal_font_size", roundi(29 * core.settings.text_scale))
	dialogue_label.scroll_active = false
	dialogue_label.visible_characters = 0
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dialogue_label)
	button("DialogueNext", "继续 ›", Rect2(1250, 586, 185, 55), advance_dialogue)
	button("History", "回看", Rect2(165, 586, 120, 55), show_history, ui, true)
	label("点击继续 / 空格 / E · 首次按下显示全文", Rect2(350, 598, 700, 40), 19, PAPER)
	if d.id == "WifeLetter":
		pass

func dialogue_portrait_id() -> String:
	if mode != "dialogue" or core.state.dialogue.is_empty(): return ""
	var d: Dictionary = core.state.dialogue
	var line: Dictionary = core.dialogue[d.id].lines[int(d.index)]
	return line.speakerId if line.speakerId in ["Ye", "Ding", "Student", "Wife"] else ""

func build_ding_controls(caption: String) -> void:
	cinematic_controls()
	label("淡饭余温  /  灯下留席", Rect2(68, 30, 950, 44), 24, PAPER, ui, true)
	panel(Rect2(42, 755, 1516, 126), ui, Color(0.045, 0.055, 0.05, 0.80), Color(GOLD, 0.25))
	label(caption, Rect2(72, 777, 990, 80), 26, PAPER, ui, true)
	status_label.visible = false

func build_ding_dialogue(line: Dictionary) -> void:
	cinematic_controls()
	var shot_title = "若如初见  /  风起家书" if core.state.dialogue.id == "WifeDeparture" else "淡饭余温  /  " + ("雨中余音" if core.state.dialogue.id == "DingShardEcho" else "灯下留席")
	if core.state.dialogue.id == "WifeReflection": shot_title = "若如初见  /  檐下落雪"
	label(shot_title, Rect2(68, 30, 950, 44), 23, PAPER, ui, true)
	panel(Rect2(42, 744, 1516, 142), ui, Color(0.045, 0.055, 0.05, 0.86), Color(GOLD, 0.3))
	var portrait = TextureRect.new()
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.name = "SpeakingPortrait"
	portrait.set_meta("speaker_id", dialogue_portrait_id())
	var atlas = AtlasTexture.new()
	atlas.atlas = stage.portraits
	var cell = stage.portraits.get_width() / 4.0
	atlas.region = Rect2(["Ye", "Ding", "Student", "Wife"].find(dialogue_portrait_id()) * cell, 0, cell, stage.portraits.get_height())
	portrait.texture = stage.wife if line.speakerId == "Wife" else atlas
	portrait.position = Vector2(63, 758)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.size = Vector2(79, 119)
	portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(portrait)
	label(NAMES.get(line.speakerId, ""), Rect2(160, 751, 560, 42), 24, GOLD, ui, true)
	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(160, 800)
	dialogue_label.size = Vector2(1100, 80)
	dialogue_label.text = current_text
	dialogue_label.add_theme_color_override("default_color", PAPER)
	dialogue_label.add_theme_font_size_override("normal_font_size", roundi(26 * core.settings.text_scale))
	dialogue_label.scroll_active = false
	dialogue_label.visible_characters = 0
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dialogue_label)
	button("DialogueNext", "继续  ›", Rect2(1320, 805, 210, 58), advance_dialogue, ui, true)
	button("History", "回看", Rect2(1320, 752, 210, 45), show_history, ui, true)
	status_label.visible = false

func student_story_controls(caption: String) -> void:
	cinematic_controls()
	panel(Rect2(42, 762, 1516, 124), ui, Color(0.045, 0.055, 0.05, 0.9), Color(GOLD, 0.3))
	label(caption, Rect2(70, 772, 1000, 58), 25, PAPER)
	status_label.position = Vector2(70, 837)
	status_label.size = Vector2(1000, 40)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	status_label.add_theme_color_override("font_color", PAPER)
	ui.move_child(status_label, -1)

func build_student_dialogue(line: Dictionary) -> void:
	cinematic_controls()
	panel(Rect2(42, 762, 1516, 124), ui, Color(0.045, 0.055, 0.05, 0.92), Color(GOLD, 0.3))
	label(NAMES.get(line.speakerId, "") + "  /  " + Stage.StudentStory.title_for(core.state.dialogue.id), Rect2(70, 764, 1150, 36), 21, GOLD)
	dialogue_label = RichTextLabel.new()
	dialogue_label.position = Vector2(70, 803)
	dialogue_label.size = Vector2(1200, 78)
	dialogue_label.text = current_text
	dialogue_label.add_theme_color_override("default_color", PAPER)
	dialogue_label.add_theme_font_size_override("normal_font_size", roundi(25 * core.settings.text_scale))
	dialogue_label.scroll_active = false
	dialogue_label.visible_characters = 0
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dialogue_label)
	button("DialogueNext", "继续  ›", Rect2(1320, 817, 210, 54), advance_dialogue, ui, true)
	button("History", "回看", Rect2(1320, 768, 210, 42), show_history, ui, true)
	status_label.visible = false

func advance_dialogue() -> void:
	if paused or mode != "dialogue" or busy:
		return
	if is_instance_valid(dialogue_label) and dialogue_label.visible_characters < current_text.length():
		reveal = current_text.length()
		dialogue_label.visible_characters = current_text.length()
		return
	var d: Dictionary = core.state.dialogue
	var line: Dictionary = core.dialogue[d.id].lines[int(d.index)]
	var min_time = 3.5 if line.get("cue", "") in ["dissolve", "vanish", "empty_place"] else 1.5
	if line_age < min_time: return
	core.event(line.eventAfter)
	if not core.state.log.has(line.lineId):
		core.state.log.append(line.lineId)
	d.index += 1
	if d.index >= core.dialogue[d.id].lines.size():
		var next: String = d.next
		core.state.dialogue = {}
		go(next)
	else:
		commit()
		clear_layer(ui)
		build_dialogue()

func show_letter() -> void:
	modal_base("一封家书", 680)
	label(core.dialogue.WifeLetter.lines[0].text, Rect2(420, 230, 760, 390), 28, INK, overlay)
	button("CloseLetter", "收好家书", Rect2(580, 680, 440, 60), close_modal, overlay)

func show_history() -> void:
	modal_base("听过的话", 700)
	var log_text = ""
	for seq in core.dialogue.values():
		for line in seq.lines:
			if line.lineId in core.state.log:
				log_text += NAMES.get(line.speakerId, "") + "：" + line.text + "\n\n"
	var rich = RichTextLabel.new()
	rich.position = Vector2(420, 220)
	rich.size = Vector2(760, 470)
	rich.text = log_text if not log_text.is_empty() else "故事刚刚开始。"
	rich.add_theme_color_override("default_color", INK)
	rich.add_theme_font_size_override("normal_font_size", roundi(24 * core.settings.text_scale))
	overlay.add_child(rich)
	button("CloseHistory", "回到此刻", Rect2(650, 720, 300, 60), close_modal, overlay)

func build_lamp() -> void:
	if not core.state.has("lantern_maze"): core.reset_lantern_maze()
	maze_forward = 0.0
	maze_turn = 0.0
	maze_save_clock = 0.0
	label("借 光", Rect2(62, 32, 240, 65), 42, Color("d3bd94"), ui, true)
	label("丁府 · 回廊深处", Rect2(66, 101, 400, 36), 20, Color("96836b"))
	button("Pause", "Ⅱ", Rect2(1480, 24, 66, 48), open_pause, ui, true)
	button("MazeMap", "鸟瞰图" if touch_controls else "鸟瞰图 · M", Rect2(1220, 24, 235, 48), show_maze_map, ui, true)
	status_label = label("提灯寻路，走出回廊。", Rect2(64, 715, 900, 42), 23, Color("d0bea1"))
	label("按住下方按钮行走或转向，可双指组合操作。" if touch_controls else "W / ↑ 前行　S / ↓ 后退　A D / ← → 转向　拖动画面转头", Rect2(64, 764, 1000, 38), 19, Color("988772"))
	for item in [["MazeLeft", "↶", -1.0, 0.0], ["MazeForward", "前行", 0.0, 1.0], ["MazeRight", "↷", 1.0, 0.0], ["MazeBack", "后退", 0.0, -1.0]]:
		var index: int = ["MazeLeft", "MazeForward", "MazeRight", "MazeBack"].find(item[0])
		if touch_controls:
			touch_button(item[0], item[1], Rect2(64 + index * 148, 802, 132, 80), item[0])
			continue
		var b = button(item[0], item[1], Rect2(64 + index * 112, 818, 100, 48), func(): pass, ui, true)
		b.button_down.connect(func():
			if not paused and core.state.lantern_maze.phase == "explore":
				maze_turn = item[2]; maze_forward = item[3])
		b.button_up.connect(func(): maze_turn = 0; maze_forward = 0)
	var next = button("LeaveMaze", "循着余温，进入书楼  ·  E", Rect2(64, 812, 520, 54), cross_lamp)
	next.visible = false
	refresh_lamp_feedback()

func show_maze_map() -> void:
	if mode != "ding_lamp" or paused: return
	modal_base("丁府回廊 · 鸟瞰图", 820)
	var map = preload("res://scripts/maze_map.gd").new()
	map.name = "MazeMapView"
	map.core = core
	map.position = Vector2(449, 155)
	map.size = Vector2(702, 594)
	overlay.add_child(map)
	label("金色箭头：你的位置与朝向    青色：入口    朱红：出口", Rect2(410, 754, 790, 32), 19, INK, overlay)
	button("MazeRoute", "显示路线", Rect2(420, 798, 330, 52), func():
		map.show_route = not map.show_route
		overlay.get_node("MazeRoute").text = "隐藏路线" if map.show_route else "显示路线"
		map.queue_redraw(), overlay)
	button("CloseMazeMap", "继续提灯 · M", Rect2(830, 798, 330, 52), close_modal, overlay)

func refresh_lamp_feedback() -> void:
	var phase: String = core.state.lantern_maze.phase
	var recovered = phase == "recovered"
	ui.get_node("LeaveMaze").visible = recovered
	for id in ["MazeLeft", "MazeForward", "MazeRight", "MazeBack"]:
		ui.get_node(id).visible = phase == "explore"
	status_label.text = "提灯寻路 · 打开鸟瞰图，迷路时可显示出口路线。" if phase == "explore" else ("影像散去，手中仍是一盏暖灯。" if recovered else "墙上浮起旧影——丁公默默添了灯油。")

func update_lantern_maze(delta: float) -> void:
	var old_phase: String = core.state.lantern_maze.phase
	var forward = maze_forward + float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)) - float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN))
	var turn = maze_turn + float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	forward += touch_axis("MazeForward", "MazeBack")
	turn += touch_axis("MazeRight", "MazeLeft")
	stage.lantern_maze.walking = core.step_lantern_maze(forward, turn, delta)
	core.tick_lantern_echo(delta)
	maze_save_clock += delta
	if old_phase != core.state.lantern_maze.phase:
		touch_actions.clear()
		maze_forward = 0; maze_turn = 0; dragging_lamp = false
		refresh_lamp_feedback()
		commit()
	elif maze_save_clock >= 4:
		maze_save_clock = 0
		commit()

func cross_lamp() -> void:
	if paused or busy or not core.finish_lantern_maze(): return
	go("ding_graph")

func memory_game_header(title: String, subtitle: String, desk = false) -> void:
	var col = INK if desk else PAPER
	label(title, Rect2(48, 28, 280, 68), 48, col, ui, true)
	label(subtitle, Rect2(54, 104, 260, 40), 28, col, ui, true)
	button("Pause", "Ⅱ", Rect2(1480, 24, 66, 48), open_pause, ui, true)
	status_label = label("", Rect2(175, 836, 1250, 55), 20, PAPER)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func build_graph() -> void:
	memory_game_header("转 镜", "悬 浮 书 楼")
	var s: Dictionary = core.state.shadow
	if not s.node in stage.positions:
		s.node = "A"
		s.view = 0
	var edges: Array = core.shadow_edges(s.node, int(s.view), s.lamp)
	label("视角 %d°   ·   %s" % [int(s.view) * 90, stage.MemoryGamesArt.NAMES[s.node]], Rect2(70, 706, 650, 40), 23, PAPER)
	var left = button("RotateLeft", "Q  左转视角", Rect2(65, 766, 195, 56), func(): rotate_graph(-1))
	var right = button("RotateRight", "E  右转视角", Rect2(280, 766, 195, 56), func(): rotate_graph(1))
	left.disabled = s.node in ["D", "F"]
	right.disabled = left.disabled
	for i in range(edges.size()):
		var target: String = edges[i]
		button("Traverse_" + target, "入影 · " + stage.MemoryGamesArt.NAMES[target], Rect2(510 + i * 250, 766, 235, 56), func(): traverse_graph(target))
	button("ShadowHint", "借一点提示", Rect2(1190, 765, 210, 56), graph_hint)
	if s.node == "E":
		panel(Rect2(820, 686, 580, 65), ui, Color(INK, 0.88), Color(GOLD, 0.45))
		label("移灯接影", Rect2(840, 695, 120, 40), 23, PAPER)
		var lamp_slider = slider("Lamp2", s.lamp, Rect2(980, 704, 385, 30), func(value):
			core.set_shadow_lamp(value)
			update_lamp_hint()
			var reachable: bool = "F" in core.shadow_edges("E", int(core.state.shadow.view), value)
			if reachable and not ui.has_node("Traverse_F"):
				button("Traverse_F", "入影 · 暖灯门前", Rect2(510, 766, 235, 56), func(): traverse_graph("F"))
			elif not reachable and ui.has_node("Traverse_F"):
				var old = ui.get_node("Traverse_F")
				ui.remove_child(old)
				old.queue_free())
		lamp_slider.drag_ended.connect(func(_changed): commit(); refresh_graph())
		update_lamp_hint()
		lamp_slider.focus_exited.connect(func(): if mode == "ding_graph": commit())
	if s.node == "D":
		status_label.text = "侧架已到尽头，没有转动把手。沿金线原路返回中央转台。"
	elif s.node == "A":
		status_label.text = "第一步 · 转动视角，接合墨影断口。木楼板的位置始终不变。"
	elif s.node == "B":
		status_label.text = "第二步 · 转动木把手寻找通路；前方墨廊是尽头，侧面书架可以返回。"
	elif s.node != "E":
		status_label.text = "金线处的墨影可以通行。继续寻找最高处的移灯平台。"

func refresh_graph() -> void:
	clear_layer(ui)
	build_graph()

func rotate_graph(direction: int) -> void:
	if paused or busy: return
	graph_from_view = int(core.state.shadow.view)
	if busy or not core.rotate_shadow(direction):
		return
	busy = true
	graph_rotating = true
	graph_rotation = 0.0
	graph_turn_dir = direction
	idle_time = 0
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "graph_rotation", 1.0, 0.05 if core.settings.reduced_motion else 1.15)
	active_tween.tween_callback(func(): graph_rotating = false; busy = false; commit(); refresh_graph())

func traverse_graph(target: String) -> void:
	var s: Dictionary = core.state.shadow
	if paused or busy or not target in core.shadow_edges(s.node, int(s.view), s.lamp):
		return
	busy = true
	travel_target = target
	travel_t = 0
	active_tween = create_tween()
	active_tween.tween_property(self, "travel_t", 1.0, 2.4 if not core.settings.reduced_motion else 0.15)
	active_tween.tween_callback(func():
		core.traverse_shadow(target)
		busy = false
		travel_target = ""
		travel_t = 0
		idle_time = 0
		commit()
		if target == "F": go("ding_table")
		else: refresh_graph())

func graph_hint() -> void:
	var s: Dictionary = core.state.shadow
	var hints = {"A": "在 A 把书楼转到 90°，墨路会通向 B。", "B": "在 B 转到 270°，先走到 C，再想下一次转动。", "C": "站在 C，把书楼转到 0°，就能上 E。", "D": "D 没有把手。沿现有墨路回到 B。", "E": "将灯移到轨道中段（42%—62%），再转到 90°。"}
	status_label.text = hints.get(s.node, "暖灯就在眼前。")

func build_board() -> void:
	if core.state.board.is_empty():
		core.new_board()
		commit()
	memory_game_header("先生之风", "理 稿", true)
	label("只取最上层\n同类三张归位", Rect2(64, 158, 245, 75), 21, INK)
	var b: Dictionary = core.state.board
	for depth in range(5, -1, -1):
		for id in b.table:
			if int(core.cards[id].depth) != depth:
				continue
			var card_button = Button.new()
			card_button.name = "Card_" + id
			card_button.position = stage.card_rect(id).position
			card_button.size = stage.card_rect(id).size
			card_button.tooltip_text = CARD_NAMES[core.card_type(id)]
			card_button.disabled = not core.can_pick(id)
			for key in ["normal", "hover", "pressed", "disabled"]:
				card_button.add_theme_stylebox_override(key, StyleBoxEmpty.new())
			var focus_style = StyleBoxFlat.new()
			focus_style.bg_color = Color(GOLD, 0.18)
			focus_style.border_color = RED
			focus_style.set_border_width_all(3)
			card_button.add_theme_stylebox_override("focus", focus_style)
			card_button.pressed.connect(func(): pick_card(id))
			ui.add_child(card_button)
	panel(Rect2(55, 596, 235, 48), ui, Color(INK, 0.82), Color(GOLD, 0.35))
	label("归位  %02d / 36" % b.cleared.size(), Rect2(72, 598, 215, 45), 22, PAPER)
	button("Undo", "撤销 %d" % b.undo_left, Rect2(40, 706, 155, 52), func(): core.undo(); board_changed()).disabled = b.undo_left <= 0 or b.history.is_empty()
	button("Reserve", "暂存三件", Rect2(210, 706, 155, 52), func(): core.reserve_cards(); board_changed()).disabled = b.reserve_used or b.tray.is_empty() or not b.reserve.is_empty()
	button("CardHint", "提示", Rect2(40, 773, 155, 48), func(): hint_card = core.next_card_hint(); status_label.text = "金边是可整理的下一张；也可以先取回备用牌。")
	button("RestartBoard", "重新理稿", Rect2(210, 773, 155, 48), confirm_board_restart)
	for i in range(b.reserve.size()):
		var id: String = b.reserve[i]
		var hit = Button.new()
		hit.name = "Return_" + id
		hit.position = stage.MemoryGamesArt.reserve_rect(i).position
		hit.size = stage.MemoryGamesArt.reserve_rect(i).size
		for key in ["normal", "hover", "pressed"]:
			hit.add_theme_stylebox_override(key, StyleBoxEmpty.new())
		hit.tooltip_text = "取回" + CARD_NAMES[core.card_type(id)]
		hit.pressed.connect(func(): core.return_card(id); board_changed())
		ui.add_child(hit)
	status_label.text = "满栏了。可以撤销、暂存，或重新理一理。" if b.tray.size() >= 7 else "七格只是暂放；同类三张便可收成文章。"

func pick_card(id: String) -> void:
	if paused or not core.pick(id):
		return
	play_note(420.0 + core.state.board.cleared.size() * 7)
	hint_card = ""
	idle_time = 0
	board_changed()

func board_changed() -> void:
	commit()
	if core.board_won():
		core.event("BoardCleared")
		say("StudentScroll", "army")
	else:
		clear_layer(ui)
		build_board()

func confirm_board_restart() -> void:
	modal_base("重新理一理")
	label("只重置当前这份文稿。已记起的人与其他进度保留。", Rect2(420, 340, 760, 120), 27, INK, overlay)
	button("ConfirmBoardRestart", "重新理稿", Rect2(430, 540, 320, 60), func(): core.new_board(); close_modal(); board_changed(), overlay)
	button("CancelBoardRestart", "继续整理", Rect2(850, 540, 320, 60), close_modal, overlay)

func start_battle() -> void:
	battle_hits = 0
	battle_mistakes = 0
	battle_elapsed = 0
	bullets.clear()
	player_pos = Vector2(510, 440)
	move_dir = Vector2.ZERO
	facing = Vector2.RIGHT
	attack_warning = 0
	shot_timer = 1.6
	brush_time = 0
	brush_cooldown = 0
	dodge_time = 0
	dodge_cooldown = 0
	invincible = 0
	hazard_warning = 0
	hazard_active = 0
	folded_time = 0
	between_attack_used = false
	header("先生之风 · " + ("纸龙" if mode == "dragon" else "纸兵"), "挥笔接住墨箭，笔锋会把它送往当前的朱批点。")
	label("左侧移动 · 右侧挥笔与闪避 · 可双指操作" if touch_controls else "A / D：侧移   W / S：进退   Space：闪避   J / 左键：挥笔", Rect2(400, 730, 680, 50) if touch_controls else Rect2(210, 730, 1050, 50), 23, PAPER)
	button("Brush", "挥笔 J", Rect2(430, 780, 230, 55), brush)
	button("Dodge", "闪避 Space", Rect2(710, 780, 280, 55), dodge)
	if touch_controls:
		ui.get_node("Brush").hide()
		ui.get_node("Dodge").hide()
		status_label.position = Vector2(400, 832)
		status_label.size = Vector2(680, 58)
		status_label.add_theme_font_size_override("font_size", 19)
		touch_button("TouchLeft", "←", Rect2(45, 778, 100, 94), "left")
		touch_button("TouchUp", "↑", Rect2(155, 680, 100, 94), "up")
		touch_button("TouchDown", "↓", Rect2(155, 778, 100, 94), "down")
		touch_button("TouchRight", "→", Rect2(265, 778, 100, 94), "right")
		touch_button("TouchBrush", "挥笔", Rect2(1100, 778, 185, 94), "brush", brush)
		touch_button("TouchDodge", "闪避", Rect2(1310, 778, 220, 94), "dodge", dodge)
	status_label.text = "接近墨箭时挥笔。每次反弹只批改一个目标。"

func brush_radius() -> float:
	return 155.0 if core.settings.assist or battle_elapsed > 35 else 120.0

func brush() -> void:
	if paused or brush_cooldown > 0 or not mode in ["army", "dragon"]:
		return
	brush_time = 0.46 if core.settings.assist or battle_elapsed > 35 else 0.38
	brush_cooldown = 0.48 if core.settings.assist else 0.42
	play_note(240)

func dodge() -> void:
	if paused or dodge_cooldown > 0:
		return
	dodge_time = 0.24
	dodge_cooldown = 0.85
	invincible = maxf(invincible, 0.18)

func update_battle(delta: float) -> void:
	battle_elapsed += delta
	brush_time = maxf(0, brush_time - delta)
	brush_cooldown = maxf(0, brush_cooldown - delta)
	dodge_cooldown = maxf(0, dodge_cooldown - delta)
	invincible = maxf(0, invincible - delta)
	folded_time = maxf(0, folded_time - delta)
	move_dir = keyboard_vector()
	if move_dir.length() > 0:
		facing = Vector2.RIGHT
	var movement = Vector2(-move_dir.y, move_dir.x) * 360.0 * delta
	if dodge_time > 0:
		movement = Vector2(0, move_dir.x if move_dir.x != 0 else -1) * (160.0 / 0.24) * delta
		dodge_time -= delta
	player_pos += movement
	player_pos = player_pos.clamp(Vector2(235, 225), Vector2(1040, 650))
	if attack_warning > 0:
		attack_warning -= delta
		if attack_warning <= 0:
			var origin = Vector2(1200, battle_aim.y)
			var speed = 208.0 if battle_hits == 0 or battle_elapsed > 35 else 272.0
			bullets.append({"p": origin, "v": (battle_aim - origin).normalized() * speed, "reflected": false, "target": battle_hits})
	else:
		shot_timer -= delta
		if shot_timer <= 0:
			if battle_hits > 0 and not between_attack_used:
				begin_secondary_attack()
				between_attack_used = true
				shot_timer = 2.0
			else:
				attack_warning = 1.2 if battle_hits == 0 else 1.0
				battle_aim = player_pos
				shot_timer = 3.2 if mode == "dragon" else 3.8
				between_attack_used = false
	var active_start = 0.40 if core.settings.assist or battle_elapsed > 35 else 0.32
	if hazard_kind == "charge" and hazard_active > 0 and folded_time <= 0 and brush_time > 0.08 and brush_time <= active_start:
		if player_pos.distance_to(charge_pos) <= 108 and (charge_pos - player_pos).normalized().dot(facing) >= 0:
			folded_time = 2.0
			hazard_active = 0
			status_label.text = "纸兵折回了纸页。再借它的箭，批开战鼓。"
	for index in range(bullets.size() - 1, -1, -1):
		var bullet: Dictionary = bullets[index]
		bullet.p += bullet.v * delta
		var distance: float = bullet.p.distance_to(player_pos)
		if not bullet.reflected and brush_time > 0.08 and brush_time <= active_start and distance <= brush_radius():
			# Reflection resolves before damage; state is consumed at a target exactly once.
			if (bullet.p - player_pos).normalized().dot(facing) >= -0.15 or core.settings.assist:
				bullet.reflected = true
				bullet.target = battle_hits
				bullet.v = (Vector2(1270, 225 + battle_hits * 85) - bullet.p).normalized() * 640
				status_label.text = "朱笔已接住这一笔。"
				play_note(680)
		if bullet.reflected:
			var target = Vector2(1270, 225 + int(bullet.target) * 85)
			if bullet.p.distance_to(target) < 26:
				if int(bullet.target) == battle_hits:
					battle_hits += 1
					bullets.clear()
					attack_warning = 0
					shot_timer = 1.6
					hazard_active = 0
					hazard_warning = 0
					between_attack_used = false
					if battle_hits >= (5 if mode == "dragon" else 4):
						battle_won()
					return
		elif distance < 25:
			bullets.remove_at(index)
			if not (mode == "army" and battle_hits == 0):
				battle_hurt()
			if paused: return
		elif bullet.p.x < 160 or bullet.p.y < 150 or bullet.p.y > 720:
			bullets.remove_at(index)
	if hazard_warning > 0:
		hazard_warning -= delta
		if hazard_warning <= 0:
			hazard_active = 6.0 if hazard_kind == "wave" else 0.6
			hazard_x = 1300
			charge_progress = 0
	if hazard_active > 0:
		hazard_active -= delta
		if hazard_kind == "wave":
			hazard_x -= 160 * delta
			if absf(player_pos.x - hazard_x) < 30 and absf(player_pos.y - hazard_y) > 80:
				battle_hurt()
		else:
			charge_progress = minf(1.0, charge_progress + delta / 0.6)
			charge_pos = charge_from.lerp(charge_end, charge_progress)
			if charge_pos.distance_to(player_pos) < 33:
				battle_hurt()

func begin_secondary_attack() -> void:
	if core.settings.assist and battle_elapsed > 90:
		return
	hazard_kind = "wave" if battle_hits % 2 == 0 else "charge"
	hazard_warning = 1.1 if hazard_kind == "wave" else 1.0
	hazard_y = clampf(player_pos.y, 275, 590)
	charge_from = (player_pos + Vector2(220, -50)).clamp(Vector2(330, 230), Vector2(1290, 640))
	charge_end = (charge_from + (player_pos - charge_from).normalized() * 240).clamp(Vector2(230, 225), Vector2(1320, 650))
	charge_pos = charge_from
	folded_time = 0

func battle_hurt() -> void:
	if invincible > 0:
		return
	invincible = 1.0
	battle_mistakes += 1
	status_label.text = "沾了些墨。让墨箭靠近，再挥笔。"
	if battle_mistakes >= 4 and not core.settings.assist:
		modal_base("再批一次")
		label("文章还可以慢慢改。\n从本阶段重新开始；已经理好的文稿保留。", Rect2(420, 330, 760, 150), 27, INK, overlay)
		button("RetryBattle", "再批一次", Rect2(425, 550, 330, 65), func(): close_modal(); go(mode), overlay)
		button("AssistBattle", "放宽笔锋，再试一次", Rect2(800, 550, 370, 65), func(): core.settings.assist = true; core.save_settings(); close_modal(); go(mode), overlay)

func battle_won() -> void:
	if mode == "army":
		core.event("ArmyCleared")
		go("dragon")
	else:
		core.event("DragonCleared")
		say("StudentReview", "review")

func start_runner() -> void:
	season_time = 0
	jump_height = 0
	jump_velocity = 0
	jump_buffer = 0
	slide_time = 0
	slide_cooldown = 0
	stumble_protect = 0
	obstacles.clear()
	spawned.clear()
	runner_tutorial = int(core.state.season) == 0 and not "RunnerTutorialDone" in core.state.events
	tutorial_time = 0
	letter_distance = 0.35
	header("若如初见 · " + ["春", "夏", "秋", "冬"][int(core.state.season)], "风把信掀起，旧日的四季从身旁掠过。")
	subtitle = label(["春来，与你种花。", "夏夜，共坐檐下。", "秋时，为你添衣。", "冬日，同扫庭前雪。"][int(core.state.season)], Rect2(480, 190, 720, 70), 38, INK, ui, true)
	panel(Rect2(240, 730, 1120, 80), ui, Color(INK, 0.83))
	button("Jump", "空格 · 跳", Rect2(280, 745, 250, 52), runner_jump)
	button("Slide", "S / ↓ · 低身", Rect2(555, 745, 290, 52), runner_slide)
	var brace = button("Brace", "按住 E · 顶风", Rect2(875, 745, 400, 52), func(): pass)
	brace.button_down.connect(func(): mouse_hold = true)
	brace.button_up.connect(func(): mouse_hold = false)
	if touch_controls:
		for id in ["Jump", "Slide", "Brace"]: ui.get_node(id).hide()
		touch_button("TouchJump", "跳", Rect2(280, 740, 250, 85), "jump", runner_jump)
		touch_button("TouchSlide", "低身", Rect2(555, 740, 290, 85), "slide", runner_slide)
		touch_button("TouchBrace", "按住 · 顶风", Rect2(875, 740, 400, 85), "brace")
	status_label.text = "信会等你。跌绊也能继续向前；不会失去这段记忆。"

func runner_jump() -> void:
	jump_buffer = 0.15

func runner_slide() -> void:
	if slide_cooldown <= 0 and jump_height <= 0:
		slide_time = 0.65
		slide_cooldown = 0.9

func in_wind() -> bool:
	return mode == "runner" and ((runner_tutorial and tutorial_time >= 7) or (int(core.state.season) == 3 and season_time >= 18 and season_time < 24))

func update_runner(delta: float) -> void:
	season_time += delta
	jump_buffer = maxf(0, jump_buffer - delta)
	slide_time = maxf(0, slide_time - delta)
	slide_cooldown = maxf(0, slide_cooldown - delta)
	stumble_protect = maxf(0, stumble_protect - delta)
	bracing = in_wind() and (Input.is_physical_key_pressed(KEY_E) or mouse_hold or touch_actions.has("brace"))
	runner_scroll += (2.4 if bracing else 1.4 if in_wind() else 4.2) * delta
	letter_distance = maxf(0.15, letter_distance - delta * 0.025)
	if jump_buffer > 0 and jump_height <= 0 and slide_time <= 0:
		jump_velocity = 7.2 * 80
		jump_buffer = 0
	if jump_velocity != 0 or jump_height > 0:
		jump_height += jump_velocity * delta
		jump_velocity -= 20 * 80 * delta
		if jump_height <= 0:
			jump_height = 0
			jump_velocity = 0
	var season: Dictionary = core.runner_config.seasons[int(core.state.season)]
	if runner_tutorial:
		tutorial_time += delta
		season = {"obstacles":[{"spawnAt":1.0,"contactAt":2.5,"requiredAction":"Jump"},{"spawnAt":4.5,"contactAt":6.0,"requiredAction":"Slide"}]}
		subtitle.text = "空格 · 迈过石坎" if tutorial_time < 4 else "S / ↓ · 从低枝下穿过" if tutorial_time < 7 else "按住 E · 迎风低身"
		status_label.text = "先试试脚步。这一段不会记录跌绊。"
	for i in range(season.obstacles.size()):
		var spec: Dictionary = season.obstacles[i]
		if season_time >= spec.spawnAt and not i in spawned:
			spawned.append(i)
			obstacles.append({"x": 448.0 + (float(spec.contactAt) - season_time) * 500, "action": spec.requiredAction, "contact": spec.contactAt, "resolved": false})
	for obstacle in obstacles:
		obstacle.x = 448.0 + (float(obstacle.contact) - season_time) * 500
		if season_time >= obstacle.contact and not obstacle.resolved:
			obstacle.resolved = true
			var safe: bool = jump_height >= 42 if obstacle.action == "Jump" else slide_time > 0
			if not safe and stumble_protect <= 0:
				if not runner_tutorial:
					core.state.stumbles += 1
					letter_distance = minf(0.8, letter_distance + 0.12)
				stumble_protect = 1.2
				status_label.text = "脚步乱了一瞬，信仍在前方。"
	if in_wind():
		status_label.text = "躬身，慢慢向前。" if bracing else "风迎面而来。按住 E 躬身，仍能继续前进。"
	if runner_tutorial and tutorial_time >= 10:
		core.event("RunnerTutorialDone")
		commit()
		clear_layer(ui)
		start_runner()
	elif not runner_tutorial and season_time >= 30:
		if int(core.state.season) < 3:
			core.state.season += 1
			commit()
			clear_layer(ui)
			start_runner()
		else:
			core.event("RunnerFinished")
			go("letter_open")

func build_stroke(final_stroke: bool) -> void:
	if not final_stroke and core.state.memory == "Student":
		student_story_controls("先生之风 · 批注  /  在笔尖旁的纸面上，补上一笔。")
		button("StrokeAccessible", "落下一笔", Rect2(1120, 803, 390, 62), complete_stroke)
		status_label.text = "沿金色细线上的纸面拖动，也可以选中按钮按回车。"
		return
	header("灯下留席" if final_stroke else "先生之风 · 批注", "在纸上拖出一笔，不论工整。")
	button("StrokeAccessible", "落下一笔（键盘辅助）", Rect2(540, 700, 520, 65), complete_stroke)
	status_label.text = "按住鼠标，在纸上划过；也可以用下方按钮。"

func complete_stroke() -> void:
	if stroke_done:
		return
	stroke_done = true
	stroke_points = PackedVector2Array([Vector2(580, 480), Vector2(670, 486), Vector2(790, 476), Vector2(920, 483)])
	if mode == "review" and core.state.memory == "Student":
		stroke_points = PackedVector2Array([Vector2(810, 688), Vector2(860, 698), Vector2(920, 680), Vector2(980, 689)])
	busy = true
	active_tween = create_tween()
	active_tween.tween_interval(0.7)
	active_tween.tween_callback(func():
		busy = false
		if mode == "literacy":
			core.event("LiteracyStroke")
			say("FinalLiteracy", "credits")
		else:
			core.event("ReviewStroke")
			say("StudentReflection", "student_shard"))

func fragment_index() -> int:
	return maxi(0, core.MEMORY_IDS.find(core.state.memory))

func build_shard() -> void:
	if core.state.memory == "Student":
		student_story_controls("旧稿旁，一封写着『丁再昌』的中举报信。")
		button("ClaimShard", "触碰旧稿上的玉纹", Rect2(1120, 803, 390, 62), claim_shard)
		return
	if core.state.memory == "Wife":
		build_wife_farewell_controls("檐下的约定已记起  ·  玉佩 %d / 3" % core.state.completed.size())
		button("ClaimShard", "收好掌心的玉佩碎片", Rect2(250, 700, 540, 65), claim_shard, ui, true)
		return
	header(core.narrative.titles.get(core.state.memory, "归宁"), "玉纹在旧物上浮现。")
	if core.state.memory == "Student":
		panel(Rect2(480, 510, 640, 75), ui, Color(PAPER, 0.94))
		label("旧稿旁，一封写着『丁再昌』的中举报信。", Rect2(500, 525, 610, 45), 24)
	button("ClaimShard", ["触碰稿袋上的玉纹", "触碰旧稿上的玉纹", "收好掌心的玉佩碎片"][fragment_index()], Rect2(520, 650, 560, 65), claim_shard)

func claim_shard() -> void:
	if core.complete_memory(core.state.memory):
		if core.state.memory == "Ding": say("DingShardEcho", "fragment")
		elif core.state.memory == "Student": say("StudentShardEcho", "fragment")
		else: go("fragment")
	else:
		status_label.text = "这段记忆尚未走完，先回到最近的检查点。"

func build_fragment() -> void:
	if core.state.memory == "Student":
		student_story_controls("记起一句被记住的教导  ·  玉佩 %d / 3" % core.state.completed.size())
		button("ReturnHub", "返回渡口", Rect2(1090, 773, 425, 45), func(): go("hub"))
		button("ContinueMemory", "拼合玉佩" if core.state.completed.size() == 3 else "继续回忆", Rect2(1090, 829, 425, 45), func():
			go("hub")
			if core.state.completed.size() == 3: go("jade"))
		return
	if core.state.memory == "Wife":
		build_wife_farewell_controls("记起一封未读的家书  ·  玉佩 %d / 3" % core.state.completed.size())
		button("ReturnHub", "返回渡口", Rect2(150, 700, 330, 65), func(): go("hub"), ui, true)
		button("ContinueMemory", "拼合玉佩" if core.state.completed.size() == 3 else "继续回忆", Rect2(520, 700, 330, 65), func(): go("jade" if core.state.completed.size() == 3 else "hub"), ui, true)
		return
	header("记忆渐明", "玉佩 %d / 3" % core.state.completed.size())
	label(["记起一顿未赴的饭", "记起一句被记住的教导", "记起一封未读的家书"][fragment_index()], Rect2(410, 540, 780, 80), 38, PAPER, ui, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button("ReturnHub", "返回渡口", Rect2(430, 700, 330, 65), func(): go("hub"))
	button("ContinueMemory", "拼合玉佩" if core.state.completed.size() == 3 else "继续回忆", Rect2(840, 700, 330, 65), func():
		go("hub")
		if core.state.completed.size() == 3:
			go("jade"))

func build_wife_farewell_controls(caption: String) -> void:
	cinematic_controls()
	label("若如初见  /  檐下落雪", Rect2(68, 30, 950, 44), 23, PAPER)
	panel(Rect2(100, 566, 820, 96), ui, Color(INK, 0.82), Color(GOLD, 0.25))
	label(caption, Rect2(130, 578, 760, 72), 26, PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func build_jade() -> void:
	if core.state.completed.size() != 3:
		go("hub")
		return
	jade_time = 0
	jade_flip = 0
	jade_positions = [Vector2(420, 420), Vector2(1180, 320), Vector2(1120, 590)]
	for id in core.state.jade:
		jade_positions[int(id)] = Vector2(800, 430)
	selected_jade = -1
	for i in range(3):
		if not i in core.state.jade:
			selected_jade = i
			break
	header("水中捷报 · 合玉", "三道裂口，仍能相认。")
	if core.state.jade.size() == 3:
		button("FlipJade", "翻 面", Rect2(620, 740, 360, 65), flip_jade)
		status_label.text = "裂痕还在，玉已完整。"
	else:
		button("SelectJade", "Tab · 换一片", Rect2(380, 740, 360, 65), select_next_jade)
		button("PlaceJade", "E · 放置", Rect2(860, 740, 360, 65), place_selected_jade)
		status_label.text = "拖动碎玉，让圆心靠近轮廓；或 Tab 选片、方向键移动、E 放置。"

func select_next_jade() -> void:
	for step in range(1, 4):
		var id = posmod(selected_jade + step, 3)
		if not id in core.state.jade:
			selected_jade = id
			return

func place_selected_jade() -> void:
	if selected_jade < 0 or selected_jade in core.state.jade:
		return
	if jade_positions[selected_jade].distance_to(Vector2(800, 430)) <= 48:
		core.place_jade(selected_jade)
		jade_positions[selected_jade] = Vector2(800, 430)
		play_note(720)
		commit()
		if core.state.jade.size() == 3:
			go("flip")
		else:
			select_next_jade()
	else:
		status_label.text = "再靠近些。让碎片的圆心与轮廓相合。"

func flip_jade() -> void:
	if busy or core.state.jade.size() != 3: return
	busy = true
	active_tween = create_tween()
	active_tween.tween_interval(0.8)
	active_tween.tween_property(self, "jade_flip", 0.5, 0.65).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	active_tween.tween_callback(func(): core.flip_jade(); commit())
	active_tween.tween_property(self, "jade_flip", 1.0, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	active_tween.tween_interval(3.5)
	active_tween.tween_callback(func(): busy = false; say("Inscription", "accident_prompt"))

func start_accident() -> void:
	if not core.state.inscription:
		go("jade")
		return
	accident_time = 0
	accident_x = 0
	cinematic_controls()
	status_label.text = "A / D 或 ← / → · 试着游向岸边"

func accident_swim_speed() -> float:
	return lerpf(112, 30, clampf((accident_time - 10) / 16, 0, 1))

func build_release() -> void:
	if not "DeathAcknowledged" in core.state.events:
		go("body")
		return
	hold_progress = 0
	hold_delay = 0
	release_armed = not Input.is_physical_key_pressed(KEY_E)
	header("静水", "那些付出，曾经都是真的。")
	var release_button = button("Release", "轻触，松开捷报" if core.settings.click_release else "按住 E / 按住此处，松开捷报", Rect2(440, 730, 720, 72), func():
		if core.settings.click_release:
			do_release())
	release_button.button_down.connect(func(): mouse_hold = true)
	release_button.button_up.connect(func(): mouse_hold = false)
	status_label.text = "松开途中可以停一停。"

func do_release() -> void:
	if not core.release_report():
		return
	go("release_echo")

func build_credits() -> void:
	core.finish_game()
	commit()
	stage.dim = 0.48
	label("中举之后，陪妻归宁，\n与友饮酒，教儿识字。", Rect2(380, 240, 880, 230), 58, PAPER, ui, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label("归 宁", Rect2(550, 500, 500, 100), 62, PAPER, ui, true).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label("根据《归宁开发执行文档》制作 · Godot 试玩版", Rect2(390, 620, 820, 50), 21, PAPER).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button("MusicCredits", "配乐鸣谢 · Kevin MacLeod", Rect2(530, 678, 540, 45), show_music_credits, ui, true)
	button("AfterHub", "回到渡口", Rect2(410, 740, 350, 65), func(): go("hub"))
	button("AfterCodex", "故 人", Rect2(840, 740, 350, 65), show_codex)

func show_project_license() -> void:
	modal_base("许可与来源 · 非商业使用", 780)
	var text = RichTextLabel.new()
	text.position = Vector2(410, 175)
	text.size = Vector2(780, 510)
	text.add_theme_color_override("default_color", INK)
	text.add_theme_font_size_override("normal_font_size", 23)
	text.text = FileAccess.get_file_as_string("res://assets/legal/NOTICE.txt")
	text.text += "\n\n" + FileAccess.get_file_as_string("res://assets/fonts/FONT-NOTICE.txt")
	text.text += "\n\n" + FileAccess.get_file_as_string("res://assets/music/MUSIC-NOTICE.txt")
	text.text += "\n\nGodot Engine — https://godotengine.org/license/\n" + Engine.get_license_text()
	for component in Engine.get_copyright_info():
		text.text += "\n" + str(component.get("name", ""))
		for part in component.get("parts", []):
			text.text += "\n" + str(part.get("license", "")) + "\n" + "\n".join(part.get("copyright", []))
	for license_name in Engine.get_license_info():
		text.text += "\n\n" + str(license_name) + "\n" + str(Engine.get_license_info()[license_name])
	overlay.add_child(text)
	button("CloseProjectLicense", "合上", Rect2(650, 740, 300, 60), close_modal, overlay)

func show_music_credits() -> void:
	modal_base("配乐鸣谢", 720)
	var credits = RichTextLabel.new()
	credits.position = Vector2(410, 190)
	credits.size = Vector2(770, 480)
	credits.add_theme_font_override("normal_font", font)
	credits.add_theme_font_size_override("normal_font_size", 23)
	credits.add_theme_color_override("default_color", INK)
	credits.text = FileAccess.get_file_as_string("res://assets/music/MUSIC-NOTICE.txt")
	overlay.add_child(credits)
	button("CloseMusicCredits", "合上", Rect2(650, 710, 300, 60), close_modal, overlay)

func show_codex() -> void:
	if not core.state.finished:
		return
	modal_base("故人 · 灯下留席", 850)
	var descriptions = [
		"他以为，先把自己的名字写上榜，才能安心回到饭桌。于是每一次关心，都在他心里变成不能辜负的催促。那些被推迟的日子里，他并非没有爱过谁；他把爱写成了许诺，又把许诺交给一个总还没到的以后。",
		"文章之外，他添过灯油，留过饭，也给过叶生授业的机会。他的赞许是真心的，关照也是真心的。叶生听见了前者，却很久没有看见后者。那只留着的碗，没有写着名次。",
		"他把先生的批注留在旧稿里，也把自己的句子写进新文章。他的进步来自许多次被认真听见。报信记下了一次考试的结果，旧稿则记下了两个人怎样一起把一句话说清楚。",
		"她替他的好消息欢喜，也盼有人一起添衣、扫雪、照看孩子。她不是只会等待的人，她把日子一天天撑住，也希望被看见。归宁的约定里，她要的是一双同行的脚。"]
	descriptions[3] = core.narrative.wife_card
	var bio_panel = panel(Rect2(385, 535, 830, 230), overlay, Color("e2e8e3"))
	var body = label(descriptions[0], Rect2(410, 550, 780, 200), 23, INK, overlay)
	var colors = [Color("dce5e7"), Color("e8dfca"), Color("e2dbeb"), Color("efdbd5")]
	var places = [Vector2(400, 200), Vector2(615, 150), Vector2(825, 195), Vector2(1030, 145)]
	for i in range(4):
		if stage.portraits != null:
			var portrait = TextureRect.new()
			var atlas = AtlasTexture.new()
			atlas.atlas = stage.portraits
			var width = stage.portraits.get_width() / 4.0
			atlas.region = Rect2(i * width, 0, width, stage.portraits.get_height())
			portrait.texture = stage.wife if i == 3 and stage.wife != null else atlas
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.position = places[i]
			portrait.size = Vector2(165, 255)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			overlay.add_child(portrait)
		button("Person_" + str(i), ["叶生", "丁乘鹤", "丁再昌", "叶妻"][i], Rect2(places[i].x, 460, 165, 58), func():
			body.text = descriptions[i]
			var style = bio_panel.get_theme_stylebox("panel").duplicate()
			style.bg_color = colors[i]
			bio_panel.add_theme_stylebox_override("panel", style), overlay)
	button("CloseCodex", "合上人物簿", Rect2(650, 785, 300, 55), close_modal, overlay)

func open_pause() -> void:
	if paused:
		return
	modal_base("在此歇一歇", 650)
	label("记忆会等你。", Rect2(420, 235, 760, 50), 26, INK, overlay)
	button("Resume", "继续", Rect2(425, 320, 350, 66), close_modal, overlay)
	button("PauseSettings", "设定与辅助", Rect2(825, 320, 350, 66), open_settings, overlay)
	button("SaveNow", "记下此刻", Rect2(425, 410, 350, 66), save_manual_memory, overlay)
	button("BackShore", "回到岸边", Rect2(825, 410, 350, 66), func():
		close_modal()
		if active_tween != null and active_tween.is_valid(): active_tween.kill()
		stage.modulate = Color.WHITE
		go("hub"), overlay)
	button("MainMenu", "保存并返回主菜单", Rect2(425, 500, 750, 66), func():
		if commit(): close_modal(); show_menu()
		else: label(core.save_error, Rect2(420, 680, 760, 55), 22, RED, overlay), overlay)
	label("Esc 继续 · 对话 E / 空格 · 每个安全检查点自动记下进度", Rect2(425, 610, 750, 70), 20, INK, overlay)

func open_settings() -> void:
	modal_base("设定 · 按自己的步调", 760)
	label("音量", Rect2(425, 205, 170, 45), 25, INK, overlay)
	slider("Volume", core.settings.volume, Rect2(620, 215, 540, 35), func(value): core.settings.volume = value; update_volume(); core.save_settings(), overlay)
	label("文字大小", Rect2(425, 280, 190, 45), 25, INK, overlay)
	for i in range(3):
		var scale_value: float = [1.0, 1.15, 1.3][i]
		button("Scale" + str(i), str(roundi(scale_value * 100)) + "%", Rect2(630 + i * 180, 280, 150, 50), func(): core.settings.text_scale = scale_value; core.save_settings(); open_settings(), overlay)
	var options = [["assist", "宽松笔锋 · 反弹更容易，批阵不重试"], ["reduced_motion", "减少动态 · 简化转场与画面运动"], ["click_release", "松手改为单击 · 无需持续按住"]]
	for i in range(options.size()):
		var key: String = options[i][0]
		var check = CheckButton.new()
		check.name = key
		check.position = Vector2(425, 365 + i * 83)
		check.size = Vector2(750, 65)
		check.text = options[i][1]
		check.button_pressed = core.settings[key]
		check.add_theme_color_override("font_color", INK)
		check.add_theme_color_override("font_hover_color", RED)
		check.add_theme_color_override("font_pressed_color", INK)
		check.add_theme_font_size_override("font_size", 23)
		check.toggled.connect(func(on): core.settings[key] = on; core.save_settings())
		overlay.add_child(check)
	label("所有小游戏都可以使用键盘。拼玉等待片刻会出现吸附辅助。", Rect2(425, 625, 750, 65), 20, INK, overlay)
	button("CloseSettings", "收好设定", Rect2(600, 725, 400, 62), func():
		close_modal()
		if mode == "menu": show_menu()
		elif not busy and mode in ["dialogue", "hub", "release", "ding_lamp", "ding_graph", "board", "jade", "flip", "letter_open", "letter_fold"]: go(mode, false), overlay)

func keyboard_vector() -> Vector2:
	var x = int(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - int(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT))
	var y = int(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - int(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP))
	return (Vector2(x, y) + Vector2(touch_axis("right", "left"), touch_axis("down", "up"))).limit_length()

func _process(delta: float) -> void:
	update_volume()
	if paused:
		return
	idle_time += delta
	scene_age += delta
	update_transition(delta)
	if update_cinematic(delta): return
	if busy:
		return
	match mode:
		"dialogue":
			line_age += delta
			dialogue_entrance = minf(1.0, line_age / 0.55)
			var ch = current_text.substr(maxi(0, int(reveal) - 1), 1)
			reveal += delta * core.settings.text_speed * (0.28 if ch in ["，", "。", "；", "？", "！", "…"] else 1.0)
			if is_instance_valid(dialogue_label):
				dialogue_label.visible_characters = current_text.length() if core.state.dialogue.id == "WifeLetter" else mini(int(reveal), current_text.length())
				dialogue_label.modulate.a = smoothstep(0, 1, dialogue_entrance)
			var line: Dictionary = core.dialogue[core.state.dialogue.id].lines[int(core.state.dialogue.index)]
			if (auto_dialogue or not line.waitForInput) and line_age > maxf(3, current_text.length() / core.settings.text_speed + 2): advance_dialogue()
		"ding_lamp":
			update_lantern_maze(delta)
		"ding_graph":
			if idle_time > 40: graph_hint()
		"army", "dragon": update_battle(delta)
		"runner": update_runner(delta)
		"jade":
			jade_time += delta
			if selected_jade >= 0 and not dragging_jade:
				jade_positions[selected_jade] += keyboard_vector() * 320 * delta
				jade_positions[selected_jade] = jade_positions[selected_jade].clamp(Vector2(240, 200), Vector2(1360, 660))
			if jade_time > 30 and not ui.has_node("JadeAssist"):
				button("JadeAssist", "合上碎玉", Rect2(1180, 190, 180, 55), func():
					for id in range(3): core.place_jade(id)
					go("flip"))
		"accident":
			accident_time += delta
			accident_x = clampf(accident_x + keyboard_vector().x * accident_swim_speed() * delta, -260, 260)
			if accident_time >= Stage.EndingSequence.ACCIDENT_DURATION: go("body")
		"release":
			if not Input.is_physical_key_pressed(KEY_E): release_armed = true
			if (release_armed and Input.is_physical_key_pressed(KEY_E)) or mouse_hold:
				hold_progress += delta
				hold_delay = 0.5
			else:
				hold_delay -= delta
				if hold_delay <= 0: hold_progress = maxf(0, hold_progress - delta * 0.3)
			if hold_progress >= 1.5: do_release()

func _input(event: InputEvent) -> void:
	if mode == "ding_lamp" and not paused and not busy and core.state.lantern_maze.phase == "explore":
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			dragging_lamp = event.pressed and get_global_mouse_position().y > 160 and get_global_mouse_position().y < 700
	if dragging_lamp:
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			dragging_lamp = false
		elif paused or busy or mode != "ding_lamp":
			dragging_lamp = false
		elif event is InputEventMouseMotion:
			core.state.lantern_maze.yaw = wrapf(core.state.lantern_maze.yaw + event.relative.x * 0.003, -PI, PI)
			get_viewport().set_input_as_handled()
	# Realtime actions take precedence over the last clicked button's GUI focus.
	if not event is InputEventKey or not event.pressed or event.echo or paused or busy:
		return
	var handled = false
	if mode in ["army", "dragon"]:
		if event.keycode == KEY_J: brush(); handled = true
		elif event.keycode == KEY_SPACE: dodge(); handled = true
	elif mode == "runner":
		if event.keycode == KEY_SPACE: runner_jump(); handled = true
		elif event.keycode in [KEY_S, KEY_DOWN]: runner_slide(); handled = true
	elif mode == "jade":
		if event.keycode == KEY_TAB: select_next_jade(); handled = true
		elif event.keycode in [KEY_E, KEY_ENTER]: place_selected_jade(); handled = true
	elif mode == "dialogue" and event.keycode in [KEY_E, KEY_SPACE]:
		advance_dialogue()
		handled = true
	elif mode in ["letter_open", "letter_fold"] and event.keycode in [KEY_E, KEY_SPACE, KEY_ENTER]:
		if mode == "letter_open": open_family_letter()
		else: keep_family_letter()
		handled = true
	if handled:
		get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.keycode == KEY_M and mode == "ding_lamp":
		if overlay.has_node("MazeMapView"): close_modal()
		elif not paused: show_maze_map()
		get_viewport().set_input_as_handled()
		return
	if event.keycode == KEY_ESCAPE:
		if paused: close_modal()
		elif mode == "memory_atlas": show_menu()
		elif mode != "menu": open_pause()
		get_viewport().set_input_as_handled()
		return
	if paused or busy:
		return
	match mode:
		"dialogue":
			if event.keycode in [KEY_SPACE, KEY_E, KEY_ENTER]: advance_dialogue()
		"ding_lamp":
			if event.keycode == KEY_E: cross_lamp()
		"ding_graph":
			if event.keycode == KEY_Q: rotate_graph(-1)
			elif event.keycode == KEY_E: rotate_graph(1)
		"army", "dragon":
			if event.keycode == KEY_J: brush()
			elif event.keycode == KEY_SPACE: dodge()
		"runner":
			if event.keycode == KEY_SPACE: runner_jump()
			elif event.keycode in [KEY_S, KEY_DOWN]: runner_slide()
		"jade":
			if event.keycode == KEY_TAB: select_next_jade()
			elif event.keycode in [KEY_E, KEY_ENTER]: place_selected_jade()
		"flip":
			if event.keycode in [KEY_E, KEY_ENTER]: flip_jade()
		"release":
			if core.settings.click_release and event.keycode == KEY_E: do_release()
		"reply":
			if event.keycode == KEY_E: core.event("ReplyChosen"); go("seat")
		"seat":
			if event.keycode == KEY_E: go("finale")

func _unhandled_input(event: InputEvent) -> void:
	if paused or busy:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		var p = get_global_mouse_position()
		if event.pressed:
			if mode in ["army", "dragon"]: brush()
			elif mode == "runner" and p.y < 710: runner_jump()
			elif mode == "dialogue": advance_dialogue()
			elif mode == "jade":
				for id in range(2, -1, -1):
					if not id in core.state.jade and Geometry2D.is_point_in_polygon((p - jade_positions[id]) / 1.35, stage.jade_polygon(id)):
						selected_jade = id
						dragging_jade = true
						drag_offset = jade_positions[id] - p
						break
			elif mode in ["review", "literacy"] and stroke_rect().has_point(p):
				drawing_stroke = true
				stroke_points = PackedVector2Array([p])
		else:
			if dragging_jade:
				dragging_jade = false
				place_selected_jade()
			if drawing_stroke:
				drawing_stroke = false
				if stroke_points.size() > 2 and stroke_points[0].distance_to(stroke_points[-1]) > 55: complete_stroke()
	elif event is InputEventMouseMotion:
		if dragging_jade and selected_jade >= 0:
			jade_positions[selected_jade] = (get_global_mouse_position() + drag_offset).clamp(Vector2(220, 180), Vector2(1380, 690))
		elif drawing_stroke:
			var region = stroke_rect()
			var p = get_global_mouse_position().clamp(region.position, region.end)
			stroke_points.append(p)

func stroke_rect() -> Rect2:
	return Stage.StudentStory.PAPER_RECT if mode == "review" and core.state.memory == "Student" else Rect2(310, 235, 980, 350)

func music_for_scene() -> String:
	if mode in ["accident_prompt", "accident"]: return "storm"
	if mode in ["ding_lamp", "body"]: return "night"
	if mode in ["army", "dragon"]: return "battle"
	if mode in ["body", "release", "release_echo"]: return "farewell"
	if mode in ["dinner_call", "reply", "seat", "literacy", "finale", "credits"]: return "home"
	if mode == "dialogue" and core.state.dialogue.get("id", "") in ["DinnerCall", "FinalDinner", "FinalLiteracy"]: return "home"
	if mode in ["menu", "memory_atlas", "hub", "report", "jade", "flip"]: return "mist"
	if mode.begins_with("ding"): return "lantern"
	if mode in ["board", "army", "dragon", "review", "student_shard"]: return "ink"
	if mode.begins_with("wife") or mode in ["runner", "letter_open", "letter_fold"]: return "letter"
	if mode == "dialogue":
		var id: String = core.state.dialogue.get("id", "")
		if id.begins_with("Ding"): return "lantern"
		if id.begins_with("Student"): return "ink"
		if id.begins_with("Wife"): return "letter"
	if mode == "fragment": return {"Ding":"lantern", "Student":"ink", "Wife":"letter"}.get(core.state.memory, "mist")
	return "mist"

func set_ambience(index: int) -> void:
	ambient_index = index
	var next = music_for_scene()
	var next_track = MusicLibrary.track_for(next)
	music_key = next
	if next_track == music_target:
		if not paused and music_fade != null and music_fade.is_valid(): music_fade.play()
		return
	var stream = MusicLibrary.stream_for(next_track)
	if stream == null: return
	music_target = next_track
	if music_fade != null and music_fade.is_valid(): music_fade.kill()
	if DisplayServer.get_name() == "headless":
		music_track = next_track
		audio_player.stream = stream
		return
	music_fade = create_tween()
	music_fade.tween_property(self, "music_gain", 0.0, 0.35)
	music_fade.tween_callback(func():
		music_track = next_track
		audio_player.stream = stream
		audio_player.play()
		audio_player.stream_paused = paused)
	music_fade.tween_property(self, "music_gain", 1.0, 1.0)
	if paused: music_fade.pause()

func update_volume() -> void:
	audio_player.volume_db = linear_to_db(maxf(0.0001, core.settings.volume * 0.5 * music_gain * MusicLibrary.gain_for(music_track)))
	note_player.volume_db = linear_to_db(maxf(0.0001, core.settings.volume * 0.35))

func play_note(frequency = 520.0) -> void:
	if DisplayServer.get_name() == "headless":
		return
	# Short procedurally synthesized paper/jade cue, no external audio dependency.
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	var data = PackedByteArray()
	data.resize(4410 * 2)
	for i in range(4410):
		var t = i / 22050.0
		var sample = sin(t * frequency * TAU) * exp(-t * 28) * minf(t * 150, 1) * 3800
		data.encode_s16(i * 2, int(sample))
	stream.data = data
	note_player.stream = stream
	update_volume()
	note_player.play()

func begin_transition() -> void:
	if transition_view == null or DisplayServer.get_name() == "headless": return
	var frame = get_viewport().get_texture().get_image()
	if frame == null or frame.is_empty(): return
	transition_view.texture = ImageTexture.create_from_image(frame)
	transition_duration = 0.2 if core.settings.reduced_motion else 0.85
	transition_left = transition_duration
	transition_view.modulate.a = 1
	transition_view.visible = true

func update_transition(delta: float) -> void:
	if transition_left <= 0: return
	transition_left = maxf(0, transition_left - delta)
	transition_view.modulate.a = smoothstep(0, 1, transition_left / transition_duration)
	if transition_left == 0:
		transition_view.visible = false
		transition_view.texture = null

func build_full_letter() -> void:
	var view = make_letter_view(true, false)
	# Preserve the complete authored dialogue for progression, history and assistive text.
	dialogue_label = RichTextLabel.new()
	dialogue_label.name = "LetterTranscript"
	dialogue_label.text = current_text
	dialogue_label.visible_characters = current_text.length()
	dialogue_label.visible = false
	dialogue_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(dialogue_label)
	reveal = current_text.length()
	view.style_button(button("DialogueNext", "读罢 · 轻叠信纸", Rect2(630, 783, 340, 58), advance_dialogue))
	view.style_button(button("LetterTranscriptButton", "横排阅读", Rect2(1240, 789, 180, 46), show_letter), false)

func make_letter_view(reading: bool, folding: bool):
	var view = FamilyLetter.new()
	view.name = "FamilyLetter"
	ui.add_child(view)
	view.setup(reading, folding, core.dialogue.WifeLetter.lines[0].text, core.settings.text_scale)
	var pause_button = button("Pause", "Ⅱ", Rect2(1480, 34, 66, 54), open_pause)
	view.style_button(pause_button, false)
	status_label = label("", Rect2(280, 738, 1040, 40), 20, FamilyLetter.MUTED)
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return view

func build_letter_arrival() -> void:
	var view = make_letter_view(false, false)
	status_label.text = "衣上沾了些泥，信终于握在手里。" if core.state.stumbles > 2 else "风缓下来，纸也安稳了。"
	view.style_button(button("ReadLetter", "解开封缄 · 展信", Rect2(630, 783, 340, 58), open_family_letter))
	# A generous hit area makes the seal itself an action on touch screens.
	var seal = Button.new()
	seal.name = "LetterSeal"
	seal.position = Vector2(710, 371)
	seal.size = Vector2(180, 148)
	seal.tooltip_text = "展开家书 · E / 空格"
	seal.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	for state_name in ["normal", "hover", "pressed", "focus"]:
		var style = StyleBoxFlat.new()
		style.bg_color = Color(1, 0.88, 0.62, 0.07) if state_name in ["hover", "focus"] else Color.TRANSPARENT
		style.border_color = Color("b38d60", 0.85) if state_name == "focus" else Color.TRANSPARENT
		style.set_border_width_all(2)
		style.set_corner_radius_all(70)
		seal.add_theme_stylebox_override(state_name, style)
	seal.pressed.connect(open_family_letter)
	ui.add_child(seal)

func open_family_letter() -> void:
	if paused or busy or mode != "letter_open": return
	var view = ui.get_node("FamilyLetter")
	view.write_vertical(core.dialogue.WifeLetter.lines[0].text, core.settings.text_scale)
	if core.settings.reduced_motion:
		say("WifeLetter", "letter_fold")
		return
	busy = true
	ui.get_node("ReadLetter").visible = false
	ui.get_node("LetterSeal").visible = false
	status_label.text = ""
	active_tween = create_tween()
	active_tween.tween_property(view, "opened", 1.0, 1.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_callback(func(): say("WifeLetter", "letter_fold"))

func build_letter_fold() -> void:
	var view = make_letter_view(false, true)
	status_label.text = "春来种花，冬日同扫庭前雪。"
	view.style_button(button("FoldLetter", "贴身收好", Rect2(630, 783, 340, 58), keep_family_letter))
	if core.settings.reduced_motion:
		view.opened = 0
		return
	busy = true
	active_tween = create_tween()
	active_tween.tween_property(view, "opened", 0.0, 1.1).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_callback(func(): busy = false)

func keep_family_letter() -> void:
	if paused or busy or mode != "letter_fold": return
	core.event("LetterFolded")
	say("WifeReflection", "wife_shard")

func update_lamp_hint() -> void:
	var shadow: Dictionary = core.state.shadow
	if int(shadow.view) != 1:
		status_label.text = "第三步 · 移动莲花灯，让笔架投出墨影，再旋转视角接向暖灯房间。"
	elif shadow.lamp < 0.42:
		status_label.text = "影子还够不到暖灯门前；把灯向右移。"
	elif shadow.lamp > 0.62:
		status_label.text = "影端越过了门槛；把灯往回收。"
	else:
		status_label.text = "影路已接合 · 沿金色影路走向暖灯门前。"

func update_cinematic(_delta: float) -> bool:
	match mode:
		"wife_arrival":
			if scene_age >= Stage.WifeArrival.DURATION: say("WifeDeparture", "runner")
			return true
		"ding_table":
			if scene_age >= 6: go("ding_place")
			return true
		"flip":
			if not busy and scene_age >= 1.2: flip_jade()
		"accident_prompt":
			if scene_age >= 2: go("accident")
			return true
		"body":
			if scene_age >= Stage.EndingSequence.BODY_DURATION:
				core.event("DeathAcknowledged")
				go("release")
			return true
		"release_echo":
			if scene_age >= 9: go("dinner_call")
			return true
		"finale":
			if scene_age >= 4 and cinematic_step == 0:
				core.event("SatDown")
				cinematic_step = 1
				commit()
			if scene_age >= 30:
				core.event("FinalDinnerCompleted")
				go("credits")
			return true
	return false
