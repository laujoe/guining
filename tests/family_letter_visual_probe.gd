extends SceneTree
var app
var failures: Array = []
var checks = 0

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL LETTER: ", message)

func shot(id: String) -> void:
	app.update_transition(10)
	if DisplayServer.get_name() == "headless": return
	await process_frame
	await RenderingServer.frame_post_draw
	expect(root.get_texture().get_image().save_png("res://.test-output/family-letter-" + id + ".png") == OK, "capture " + id)

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/family-letter-probe-save.json"
	app.core.settings_path = "res://.test-output/family-letter-probe-settings.json"
	root.add_child(app)
	await process_frame
	root.focus_exited.disconnect(app._on_focus_lost)
	root.size = Vector2i(1600, 900)
	app.close_modal()
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.settings.text_scale = 1.0
	app.core.settings.reduced_motion = false
	app.go("letter_open", false)
	await shot("sealed")
	app.ui.get_node("LetterSeal").pressed.emit()
	app.open_family_letter()
	expect(app.busy and app.mode == "letter_open", "double click cannot skip unfolding")
	await create_timer(0.5).timeout
	await shot("opening")
	app.ui.get_node("Pause").pressed.emit()
	expect(app.paused, "pause button works during unfolding")
	var paused_amount: float = app.ui.get_node("FamilyLetter").opened
	await create_timer(0.15).timeout
	expect(is_equal_approx(app.ui.get_node("FamilyLetter").opened, paused_amount), "pause freezes unfolding")
	app.close_modal()
	await create_timer(1.5).timeout
	expect(app.mode == "dialogue" and not app.busy, "unfold reaches readable dialogue")
	await shot("reading")
	app.core.settings.text_scale = 1.3
	app.go("dialogue", false)
	await shot("reading130")
	app.ui.get_node("LetterTranscriptButton").pressed.emit()
	expect(app.paused and app.overlay.has_node("CloseLetter"), "horizontal reading opens accessible full-text view")
	app.overlay.get_node("CloseLetter").pressed.emit()
	expect(not app.paused and app.mode == "dialogue", "horizontal view returns without advancing story")
	root.size = Vector2i(960, 540)
	await shot("reading130-small")
	root.size = Vector2i(1600, 900)
	var glyphs = app.ui.get_node("FamilyLetter/Writing").get_children()
	var recovered = ""
	for glyph in glyphs:
		if not str(glyph.name).begins_with("Glyph_"): continue
		recovered += glyph.text
		expect(glyph.position.y + glyph.size.y < 720 and glyph.position.x > 350, "large type stays within paper: " + str(glyph.name))
	expect(recovered == app.current_text.replace("\n", ""), "vertical letter preserves authored text and punctuation exactly")
	app.line_age = 10
	app.advance_dialogue()
	expect(app.mode == "letter_fold" and app.busy, "reading starts fold animation")
	app.keep_family_letter()
	expect(app.mode == "letter_fold", "cannot collect during fold")
	await create_timer(1.3).timeout
	await shot("folded")
	app.keep_family_letter()
	expect(app.mode == "dialogue" and app.core.state.dialogue.id == "WifeReflection", "fold advances to existing reflection")
	expect(app.core.state.completed.is_empty(), "presentation grants no memory reward")
	app.core.settings.reduced_motion = true
	app.go("letter_open", false)
	var key = InputEventKey.new()
	key.keycode = KEY_E
	key.pressed = true
	app._input(key)
	expect(not app.busy and app.mode == "dialogue", "reduced motion opens immediately")
	app.line_age = 10
	app.advance_dialogue()
	expect(not app.busy and app.ui.get_node("FamilyLetter").opened == 0, "reduced motion folds immediately")
	var report = FileAccess.open("res://.test-output/family-letter-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks, "failures":failures}, "\t"))
	report.close()
	print("FAMILY LETTER: ", checks, " checks, ", failures.size(), " failures")
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
