extends SceneTree
const Core = preload("res://scripts/game_core.gd")
const Saves = preload("res://scripts/memory_save_system.gd")
var checks = 0
var failures: Array = []
var directory = "res://.test-output/memory-suite-" + str(Time.get_ticks_usec())

func _initialize() -> void:
	call_deferred("run")

func expect(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures.append(message)
		printerr("FAIL: ", message)

func write_json(path: String, value) -> void:
	var file = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(value))
	file.close()

func run() -> void:
	DirAccess.make_dir_recursive_absolute(directory)
	var core = Core.new()
	core.save_path = directory + "/current.json"
	core.settings_path = directory + "/settings.json"
	var saves = Saves.new(core)
	expect(saves.list_memories().entries.is_empty(), "new atlas is empty")
	core.state.prologue = true
	expect(core.save_game(), "current save succeeds")
	var saved = saves.save_checkpoint()
	expect(saved.ok, "arrival checkpoint creates memory")
	var id: String = saved.get("id", "")
	var original = FileAccess.get_file_as_string(saves.record_path(id))
	expect(saves.save_checkpoint().get("skipped", false), "same checkpoint is idempotent")
	expect(saves.list_memories().entries.size() == 1, "only one automatic memory")
	var restarted = Core.new()
	restarted.save_path = core.save_path
	expect(restarted.load_game(), "fresh Core reads saved state")
	var fresh = Saves.new(restarted)
	expect(fresh.list_memories().entries.size() == 1 and fresh.prepare_load(id).ok, "fresh service discovers disk memory")
	expect(fresh.save_checkpoint().get("skipped", false), "restart does not regenerate checkpoint")
	core.state.memory = "Wife"
	core.state.route = "runner"
	core.state.season = 2
	core.state.stumbles = 7
	core.state.log.append("retained line")
	core.save_game()
	var manual = saves.save_memory(core.state, {"saved_at_utc": 1000})
	expect(manual.ok, "manual runner snapshot saves")
	var same_second = saves.save_memory(core.state, {"saved_at_utc": 1000})
	expect(same_second.ok and same_second.id != manual.id, "same timestamp gets independent files")
	var list_before: Array = saves.list_memories().entries
	expect(list_before[1].id == same_second.id, "same-second order uses sequence")
	expect(saves.load_memory(id).ok, "older memory can be loaded")
	expect(core.state.completed.is_empty() and core.state.route == "hub", "restore applies full historical state")
	expect(core.state.parent_memory_id == id and core.state.branch_id != fresh.prepare_load(id).state.branch_id, "restore forks continuation")
	expect(FileAccess.get_file_as_string(saves.record_path(id)) == original, "historical bytes remain immutable")
	var preserved_id = ""
	for item in saves.list_memories().entries:
		if item.source == "preserved": preserved_id = item.id
	expect(not preserved_id.is_empty(), "newer progress remains visible in atlas")
	expect(saves.load_memory(preserved_id).ok and core.state.season == 2 and core.state.stumbles == 7 and core.state.log.has("retained line"), "newer progress can be restored")
	var raw_archives = 0
	for filename in DirAccess.open(directory).get_files():
		if ".archive_" in filename: raw_archives += 1
	expect(raw_archives >= 2, "read preserves raw current and backup files")
	var before = core.state.duplicate(true)
	expect(not saves.prepare_load("../current").ok and not saves.delete_memory("../current").ok, "unsafe IDs cannot escape memory directory")
	expect(core.state == before, "failed preparation does not mutate current state")
	var corrupt = core.new_id()
	write_json(saves.record_path(corrupt), {"broken": true})
	var corrupt_bytes = FileAccess.get_file_as_string(saves.record_path(corrupt))
	expect(not saves.load_memory(corrupt).ok, "corrupt snapshot cannot load")
	expect(FileAccess.get_file_as_string(saves.record_path(corrupt)) == corrupt_bytes, "corrupt original retained")
	expect(saves.list_memories().entries.size() >= 5, "one corrupt file does not hide healthy entries")
	var future = core.read_json(saves.record_path(manual.id))
	future.id = core.new_id()
	future.memory_schema = 2
	write_json(saves.record_path(future.id), future)
	expect(not saves.load_memory(future.id).ok, "future outer schema rejected")
	future.memory_schema = 1
	future.state.script_revision = 3
	write_json(saves.record_path(future.id), future)
	expect(not saves.load_memory(future.id).ok, "future narrative schema rejected")
	var malformed = core.read_json(saves.record_path(manual.id))
	malformed.id = core.new_id()
	malformed.state.script_revision = "bad"
	write_json(saves.record_path(malformed.id), malformed)
	expect(not saves.load_memory(malformed.id).ok, "malformed narrative revision rejected without crashing")
	var missing_time = core.read_json(saves.record_path(manual.id))
	missing_time.id = core.new_id()
	missing_time.erase("saved_at_utc")
	write_json(saves.record_path(missing_time.id), missing_time)
	expect(not saves.prepare_load(missing_time.id).ok and saves.list_memories().ok, "missing timestamp field is isolated as corrupt entry")
	var temp_id = core.new_id()
	write_json(saves.record_path(temp_id) + ".tmp", {"memory_schema": 1})
	var found_temp = false
	for item in saves.list_memories().entries:
		if item.id == temp_id: found_temp = true
	expect(not found_temp, "partial temporary files stay out of atlas")
	expect(saves.delete_memory(corrupt).ok and not FileAccess.file_exists(saves.record_path(corrupt)), "corrupt entry may be explicitly deleted")
	expect(not saves.delete_memory(corrupt).ok, "delete missing file reports error")
	var blocker = directory + "/not-a-directory"
	write_json(blocker, {})
	var unavailable = Saves.new(core, blocker + "/memories")
	expect(not unavailable.list_memories().ok, "directory access error is not empty state")
	expect(not unavailable.save_memory(core.state).ok, "write failure reports failure")
	var old_path: String = core.save_path
	core.save_path = blocker + "/current.json"
	before = core.state.duplicate(true)
	expect(not core.restore_memory(fresh.prepare_load(id).state, id), "failed current commit aborts restore")
	expect(core.state == before, "failed commit restores old in-memory state")
	core.save_path = old_path
	# Existing newer/invalid current files are archived before explicit replacement.
	write_json(core.save_path, {"schema": 99})
	core.write_blocked = true
	expect(saves.load_memory(id).ok, "explicit restore can replace future current only after preserving it")
	var preserved_future = false
	for filename in DirAccess.open(directory).get_files():
		if ".archive_" in filename and core.read_json(directory.path_join(filename)).get("schema") == 99: preserved_future = true
	expect(preserved_future, "future current preserved verbatim in archive")
	expect(saves.delete_memory(id).ok, "remove automatic history")
	expect(saves.save_checkpoint().get("skipped", false), "deleted auto memory is not regenerated at same node")
	# Legacy import copies once without changing source bytes or settings.
	var legacy_core = Core.new()
	legacy_core.save_path = directory + "/legacy.json"
	var legacy = legacy_core.state.duplicate(true)
	for key in ["story_id", "branch_id", "parent_memory_id", "memory_markers"]: legacy.erase(key)
	write_json(legacy_core.save_path, legacy)
	var legacy_bytes = FileAccess.get_file_as_string(legacy_core.save_path)
	var legacy_saves = Saves.new(legacy_core)
	var imported = legacy_saves.import_legacy_once()
	expect(imported.ok and legacy_saves.list_memories().entries[0].saved_at_utc == null, "legacy unknown date remains unknown")
	expect(FileAccess.get_file_as_string(legacy_core.save_path) == legacy_bytes, "legacy source untouched")
	legacy_saves.delete_memory(imported.id)
	expect(legacy_saves.import_legacy_once().get("skipped", false) and legacy_saves.list_memories().entries.is_empty(), "deleted legacy import stays deleted")
	# Diverse checkpoint round trips, including all six orders of collecting memories.
	for order in [["Ding", "Student", "Wife"], ["Ding", "Wife", "Student"], ["Student", "Ding", "Wife"], ["Student", "Wife", "Ding"], ["Wife", "Ding", "Student"], ["Wife", "Student", "Ding"]]:
		core.reset_state()
		for memory in order:
			core.state.memory = memory
			for event in core.PREREQUISITES[memory]: core.event(event)
			core.complete_memory(memory)
			core.state.route = "fragment"
			var record = saves.save_checkpoint()
			expect(record.ok and saves.prepare_load(record.id).state.completed == core.state.completed, "checkpoint round trip preserves order " + str(order))
		for piece in range(3): core.place_jade(piece)
		core.state.route = "flip"
		var jade = saves.save_checkpoint()
		expect(jade.ok and not saves.prepare_load(jade.id).state.inscription, "jade card does not prematurely reveal inscription")
		core.flip_jade()
		for event in ["DeathAcknowledged", "ReplyChosen", "SatDown", "FinalDinnerCompleted"]: core.event(event)
		core.release_report()
		core.finish_game()
		core.state.route = "credits"
		var ending = saves.save_checkpoint()
		expect(ending.ok and saves.prepare_load(ending.id).state.finished, "ending completion round trip")
	var file = FileAccess.open("res://.test-output/memory-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	print("GUINING MEMORY: ", checks, " checks, ", failures.size(), " failures")
	quit(0 if failures.is_empty() else 1)
