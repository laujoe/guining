extends RefCounted
## Independent immutable snapshots. The Core remains the only gameplay authority.
var core
var root_path: String
var checkpoints: Dictionary = {}
var last_error = ""

func _init(game_core, directory = "") -> void:
	core = game_core
	root_path = directory
	if root_path.is_empty():
		root_path = "user://memories" if core.save_path == "user://slot01.json" else core.save_path.get_basename() + "-memories"
	checkpoints = core.read_json("res://data/memory_checkpoints.json")

func result_error(message: String) -> Dictionary:
	last_error = message
	return {"ok": false, "error": message}

func valid_id(id: String) -> bool:
	return id.length() == 32 and id.is_valid_hex_number(false)

func ensure_directory() -> bool:
	if DirAccess.make_dir_recursive_absolute(root_path) == OK: return true
	last_error = "记忆目录暂时无法读取或写入，请重试。"
	return false

func record_path(id: String) -> String:
	return root_path.path_join(id + ".json")

func validate_record(record: Dictionary) -> String:
	if record.get("memory_schema") != 1:
		return "这卷记忆由其他版本保存，请使用相应版本读取。" if record.has("memory_schema") else "这卷记忆暂时无法展开。"
	for key in ["id", "story_id", "branch_id", "parent_memory_id", "checkpoint_id", "source", "title", "chapter", "story_time", "game_version"]:
		if not record.get(key) is String: return "记忆信息不完整，原文件已保留。"
	if not valid_id(record.id) or not valid_id(record.story_id) or not valid_id(record.branch_id): return "记忆编号无效。"
	if not record.source in ["auto", "manual", "legacy", "test", "preserved"]: return "记忆来源无效。"
	if not core.is_whole(record.get("sequence"), 0, 9007199254740991): return "记忆顺序无效。"
	if not record.has("saved_at_utc"): return "记忆保存时间字段缺失。"
	if record.saved_at_utc != null and not core.is_whole(record.saved_at_utc, 0, 253402300799): return "记忆保存时间无效。"
	if not record.get("state") is Dictionary: return "记忆进度不完整。"
	var data: Dictionary = record.state
	if data.get("schema") != 1 or (data.get("script_revision", 1) is float or data.get("script_revision", 1) is int) and data.get("script_revision", 1) > 2:
		return "这卷记忆由其他版本保存，请使用相应版本读取。"
	if core.prepare_snapshot(data).is_empty(): return "这卷记忆的故事进度无效，原文件已保留。"
	if record.source == "auto":
		if not checkpoints.has(record.checkpoint_id): return "记忆节点不受当前版本支持。"
		if not data.route in checkpoints[record.checkpoint_id].routes: return "记忆节点与恢复位置不一致。"
		var previous: Dictionary = core.state
		core.state = data
		var actual: String = core.memory_checkpoint()
		core.state = previous
		if actual != record.checkpoint_id: return "记忆节点条件不完整。"
	return ""

func list_memories() -> Dictionary:
	last_error = ""
	if not ensure_directory(): return result_error(last_error)
	var directory = DirAccess.open(root_path)
	if directory == null: return result_error("记忆目录暂时无法读取。")
	var entries: Array = []
	for filename in directory.get_files():
		if not filename.ends_with(".json") or filename.begins_with("."): continue
		var id = filename.trim_suffix(".json")
		if not valid_id(id): continue
		var record: Dictionary = core.read_json(record_path(id))
		var error = validate_record(record)
		if error.is_empty() and record.id != id: error = "记忆编号与文件不一致。"
		if not error.is_empty():
			entries.append({"id": id, "title": "未能展开的记忆", "error": error, "saved_at_utc": null, "sequence": 0})
		else:
			var summary = record.duplicate()
			summary.erase("state")
			summary["completed"] = record.state.completed.size()
			summary["route"] = record.state.route
			summary["error"] = ""
			entries.append(summary)
	entries.sort_custom(func(a, b):
		var at = int(a.saved_at_utc) if a.saved_at_utc != null else 0
		var bt = int(b.saved_at_utc) if b.saved_at_utc != null else 0
		if at != bt: return at > bt
		if a.sequence != b.sequence: return a.sequence > b.sequence
		return a.id > b.id)
	return {"ok": true, "entries": entries}

func save_memory(snapshot: Dictionary, metadata: Dictionary = {}) -> Dictionary:
	last_error = ""
	var state: Dictionary = core.prepare_snapshot(snapshot)
	if state.is_empty(): return result_error("当前片刻尚不是可恢复的检查点。")
	if not ensure_directory(): return result_error(last_error)
	var id: String = metadata.get("id", core.new_id())
	if not valid_id(id): return result_error("记忆编号无效。")
	var path = record_path(id)
	if FileAccess.file_exists(path):
		var existing = core.read_json(path)
		if validate_record(existing).is_empty(): return {"ok": true, "id": id, "existing": true}
		return result_error("同编号记录无法读取，已保留原文件。")
	var listing = list_memories()
	if not listing.ok: return listing
	var sequence = 1
	for item in listing.entries: sequence = maxi(sequence, int(item.sequence) + 1)
	var record = {
		"memory_schema": 1, "id": id, "story_id": state.story_id, "branch_id": state.branch_id,
		"parent_memory_id": state.parent_memory_id, "checkpoint_id": metadata.get("checkpoint_id", state.route),
		"source": metadata.get("source", "manual"), "title": metadata.get("title", title_for(state)),
		"chapter": metadata.get("chapter", chapter_for(state)), "story_time": metadata.get("story_time", "未记"),
		"saved_at_utc": metadata.get("saved_at_utc", int(Time.get_unix_time_from_system())),
		"sequence": sequence, "game_version": str(ProjectSettings.get_setting("application/config/version", "0.1.1")), "state": state
	}
	var error = validate_record(record)
	if not error.is_empty(): return result_error(error)
	var file = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if file == null: return result_error("这一刻尚未收入图谱，请重试保存。")
	file.store_string(JSON.stringify(record, "\t"))
	file.close()
	if not validate_record(core.read_json(path + ".tmp")).is_empty(): return result_error("记忆写入校验失败，旧卷轴未改动。")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return result_error("记忆提交失败，请重试。")
	return {"ok": true, "id": id}

func save_checkpoint() -> Dictionary:
	var checkpoint: String = core.memory_checkpoint()
	if checkpoint.is_empty(): return {"ok": true, "skipped": true}
	if not checkpoints.has(checkpoint): return result_error("记忆节点配置缺失。")
	core.ensure_memory_identity()
	if checkpoint in core.state.memory_markers: return {"ok": true, "skipped": true}
	var snapshot: Dictionary = core.state.duplicate(true)
	snapshot.memory_markers.append(checkpoint)
	var config: Dictionary = checkpoints[checkpoint]
	var saved = save_memory(snapshot, {"id": (core.state.story_id + core.state.branch_id + checkpoint).sha256_text().substr(0, 32), "source": "auto", "checkpoint_id": checkpoint, "title": config.title, "chapter": config.chapter, "story_time": config.story_time})
	if saved.ok:
		core.state.memory_markers.append(checkpoint)
		if not core.save_game(): return result_error("卷轴已保存，当前进度标记保存失败，可重试。")
	return saved

func prepare_load(id: String) -> Dictionary:
	if not valid_id(id): return result_error("记忆编号无效。")
	var record = core.read_json(record_path(id))
	var error = validate_record(record)
	if not error.is_empty(): return result_error(error)
	if record.id != id: return result_error("记忆编号与文件不一致。")
	return {"ok": true, "state": core.prepare_snapshot(record.state), "id": id, "record": record}

func load_memory(id: String) -> Dictionary:
	var prepared = prepare_load(id)
	if not prepared.ok: return prepared
	# Keep the most recent playable state visible in the atlas, as well as raw archives.
	if FileAccess.file_exists(core.save_path) and not core.write_blocked:
		var preserved = save_memory(core.state, {"source": "preserved", "title": "读取前的故事", "id": ("preserve" + JSON.stringify(core.state)).sha256_text().substr(0, 32)})
		if not preserved.ok: return result_error("当前进度无法收入图谱，尚未读取记忆。" + preserved.error)
	if not core.restore_memory(prepared.state, id): return result_error(core.save_error)
	return {"ok": true, "id": id}

func delete_memory(id: String) -> Dictionary:
	if not valid_id(id): return result_error("记忆编号无效。")
	if not FileAccess.file_exists(record_path(id)): return result_error("这卷记忆已不存在，请刷新列表。")
	if DirAccess.remove_absolute(record_path(id)) != OK: return result_error("删除未完成，记忆仍保留，请重试。")
	return {"ok": true}

func import_legacy_once() -> Dictionary:
	if not FileAccess.file_exists(core.save_path): return {"ok": true, "skipped": true}
	if not ensure_directory(): return result_error(last_error)
	var marker_path = root_path.path_join(".legacy-import.json")
	if FileAccess.file_exists(marker_path):
		var marker = core.read_json(marker_path)
		if marker.get("complete") == true: return {"ok": true, "skipped": true}
		return result_error("旧档导入标记无法读取，原文件已保留。")
	var original: Dictionary = core.read_json(core.save_path)
	if original.has("story_id"): return {"ok": true, "skipped": true}
	if not core.valid_save(original): return result_error("旧存档无法导入，原文件已保留。")
	var timestamp = null
	if original.get("updated_utc") is String:
		var value = Time.get_unix_time_from_datetime_string(original.updated_utc)
		if value > 0: timestamp = value
	var saved = save_memory(original, {"id": ("legacy" + core.save_path).sha256_text().substr(0, 32), "source": "legacy", "title": "旧日记忆", "saved_at_utc": timestamp})
	if not saved.ok: return saved
	var marker = FileAccess.open(marker_path + ".tmp", FileAccess.WRITE)
	if marker == null: return result_error("旧档已收入图谱，导入标记写入失败，请重试。")
	marker.store_string(JSON.stringify({"complete": true, "id": saved.id}))
	marker.close()
	if core.read_json(marker_path + ".tmp").get("complete") != true or DirAccess.rename_absolute(marker_path + ".tmp", marker_path) != OK:
		return result_error("旧档已收入图谱，导入标记提交失败，请重试。")
	return saved

func chapter_for(state: Dictionary) -> String:
	if state.finished: return "终章"
	if state.route in ["report", "hub"]: return "渡口"
	if state.route in ["jade", "flip"]: return "合玉"
	if state.inscription: return "归途"
	return {"Ding": "丁公篇", "Student": "学生篇", "Wife": "家书篇"}.get(state.memory, "序章")

func title_for(state: Dictionary) -> String:
	return chapter_for(state) + " · 记下此刻"

func resume_hint(route: String) -> String:
	if route in ["army", "dragon"]: return "从本段战斗开头继续"
	if route == "runner": return "从当前季节开头继续"
	if route == "board": return "继续已保存的理稿牌局"
	if route == "dialogue": return "从已保存的对白继续"
	return "从本段安全检查点继续"

func local_time(timestamp) -> String:
	if timestamp == null: return "原保存时间不详"
	var local_stamp = int(timestamp) + int(Time.get_time_zone_from_system().bias) * 60
	return Time.get_datetime_string_from_unix_time(local_stamp).replace("T", " ").substr(0, 16)
