extends SceneTree
var checks = 0
var failures: Array = []
var app

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL UI: ", message)

func frames() -> void:
	for i in range(4): await process_frame

func press(parent: Node, id: String) -> void:
	var button = parent.find_child(id, true, false)
	expect(button != null and not button.disabled, "enabled button " + id)
	if button != null: button.pressed.emit()

func atlas():
	return app.ui.get_node("MemoryAtlas")

func run() -> void:
	var directory = "res://.test-output/memory-ui-" + str(Time.get_ticks_usec())
	DirAccess.make_dir_recursive_absolute(directory)
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = directory + "/current.json"
	app.core.settings_path = directory + "/settings.json"
	root.add_child(app)
	await frames()
	app.set_process(false)
	expect(app.ui.find_child("MemoryAtlasButton", true, false) != null, "atlas available without current save")
	press(app.ui, "MemoryAtlasButton")
	await frames()
	expect(app.mode == "memory_atlas" and app.core.state.route != "memory_atlas", "UI mode never becomes gameplay route")
	expect(atlas().entries.is_empty() and "还没有" in atlas().message.text, "empty atlas explains purpose")
	expect(atlas().find_child("GenerateTestMemory", true, false) == null, "normal game has no test generator")
	app.memory_test_mode = true
	app.memory_test_fixture = load("res://tests/memory_fixture.gd").new()
	app.memory_test_generator = app.memory_test_fixture.generate
	app.show_memory_atlas()
	press(atlas(), "GenerateTestMemory")
	await frames()
	expect(atlas().entries.size() == 1, "test generator reloads real disk list")
	var id: String = atlas().entries[0].id
	var path: String = app.memory_saves.record_path(id)
	expect(FileAccess.file_exists(path) and path.begins_with(directory), "test record is isolated on disk")
	# Tear down and recreate the entire game to prove persistence and restoration.
	app.queue_free()
	await frames()
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = directory + "/current.json"
	app.core.settings_path = directory + "/settings.json"
	root.add_child(app)
	await frames()
	app.set_process(false)
	app.core.settings.reduced_motion = true
	app.show_memory_atlas()
	await frames()
	expect(atlas().entries.size() == 1, "fresh game sees generated memory")
	var card = atlas().list.get_node("Memory_" + id)
	press(card, "ReadMemory")
	expect(atlas().modal.visible, "read presents preservation confirmation")
	expect(atlas().modal.get_cancel_button().has_focus(), "confirmation defaults to cancel")
	atlas().modal.hide()
	atlas().confirm_action()
	await frames()
	expect(app.mode == "hub" and app.core.state.prologue and app.has_save, "reading snapshot restores actual scene")
	expect(app.core.state.completed.is_empty(), "read does not award fragments")
	expect(FileAccess.file_exists(path), "read preserves historical file")
	app.open_pause()
	press(app.overlay, "SaveNow")
	expect(not app.paused, "manual memory closes pause after success")
	app.show_memory_atlas()
	await frames()
	expect(atlas().list.has_node("Memory_current"), "current progress has independent card")
	expect(atlas().list.get_node("Memory_current").find_child("DeleteMemory", true, false) == null, "current progress has no delete action")
	card = atlas().list.get_node("Memory_" + id)
	press(card, "DeleteMemory")
	expect(atlas().modal.visible and FileAccess.file_exists(path), "delete waits for confirmation")
	atlas().modal.hide()
	atlas().confirm_action()
	await frames()
	expect(not FileAccess.file_exists(path), "confirmed delete removes record from disk")
	expect(app.core.state.prologue and app.core.valid_save(app.core.read_json(app.core.save_path)), "delete leaves active progress intact")
	atlas().refresh()
	expect(not atlas().list.has_node("Memory_" + id), "deleted record stays absent after refresh")
	# More than one page, including the 100-record design boundary.
	for i in range(101):
		var result = app.memory_saves.save_memory(app.core.state, {"title": "测试长标题 · 灯下留席与从前未能说完的话 " + str(i)})
		expect(result.ok, "write pagination fixture " + str(i))
	app.core.settings.text_scale = 1.3
	app.show_memory_atlas()
	await frames()
	expect(atlas().rendered == 20 and atlas().entries.size() > 100, "large list builds only twenty history cards")
	expect(atlas().list.get_child_count() == 22, "initial page contains current card twenty memories and load more")
	press(atlas(), "MoreMemories")
	await frames()
	expect(atlas().rendered == 40, "next page appends twenty")
	for child in atlas().list.get_children():
		if child is PanelContainer:
			expect(child.size.x <= atlas().scroll.size.x, "card stays within scroll width at large text")
			for text in child.find_children("*", "Label", true, false):
				expect(text.size.y + 1 >= text.get_minimum_size().y, "large text has enough vertical space")
	# A corrupt record remains independently visible and deletable.
	var corrupt_id: String = app.core.new_id()
	var file = FileAccess.open(app.memory_saves.record_path(corrupt_id), FileAccess.WRITE)
	file.store_string("broken JSON")
	file.close()
	atlas().refresh()
	while atlas().rendered < atlas().entries.size(): atlas().append_batch()
	await frames()
	card = atlas().list.get_node("Memory_" + corrupt_id)
	expect(card.read_button.disabled and not card.find_child("DeleteMemory", true, false).disabled, "broken record disables only read")
	var escape = InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	app._unhandled_key_input(escape)
	expect(app.mode == "menu", "Escape returns from atlas to menu")
	await frames()
	var menu: Control = app.ui.get_node("MenuButtons")
	expect(menu.position.y + menu.size.y < 810, "menu fits at 130 percent text size")
	var report = FileAccess.open("res://.test-output/memory-ui-results.json", FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	report.close()
	print("GUINING MEMORY UI: ", checks, " checks, ", failures.size(), " failures")
	app.queue_free()
	await frames()
	quit(0 if failures.is_empty() else 1)
