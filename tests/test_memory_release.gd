extends SceneTree
var failures: Array = []
func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func run() -> void:
	var args = OS.get_cmdline_user_args()
	if args.size() != 2 or not ProjectSettings.load_resource_pack(args[0]):
		printerr("FAIL: cannot open release pack")
		quit(1)
		return
	DirAccess.make_dir_recursive_absolute(args[1])
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = args[1].path_join("current.json")
	app.core.settings_path = args[1].path_join("settings.json")
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.core.settings.reduced_motion = true
	expect(app.memory_saves.checkpoints.size() == 6, "release contains all checkpoint configuration")
	expect(not ResourceLoader.exists("res://tests/memory_fixture.gd"), "release excludes test generator fixture")
	expect(not DirAccess.dir_exists_absolute("res://addons"), "release excludes development plugin")
	app.core.state.prologue = true
	app.core.save_game()
	app.has_save = true
	var result = app.memory_saves.save_checkpoint()
	expect(result.ok, "release saves snapshot")
	app.show_memory_atlas()
	for frame in range(4): await process_frame
	var atlas = app.ui.get_node("MemoryAtlas")
	expect(atlas.entries.size() == 1, "release lists snapshot on screen")
	expect(atlas.find_child("GenerateTestMemory", true, false) == null, "release has no development button")
	atlas.request_read(result.id)
	atlas.modal.hide()
	atlas.confirm_action()
	await process_frame
	expect(app.mode == "hub" and app.core.state.prologue, "release restores snapshot into real scene")
	expect(app.memory_saves.delete_memory(result.id).ok, "release deletes selected history")
	expect(app.core.valid_save(app.core.read_json(app.core.save_path)), "release retains active progress after deleting history")
	var report = FileAccess.open(args[1].path_join("release-memory-results.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify({"failures": failures, "passed": failures.is_empty()}, "\t"))
	report.close()
	print("MEMORY_RELEASE ", "PASS" if failures.is_empty() else str(failures))
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
