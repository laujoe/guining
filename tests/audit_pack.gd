extends SceneTree

# Run from an empty audit project so only the exported pack is enumerated.
func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2 or not ProjectSettings.load_resource_pack(args[0]):
		push_error("Could not load release resource pack")
		quit(1)
		return
	var files: Array[String] = []
	_collect("res://", files)
	files.sort()
	for path in files:
		var destination := args[1].path_join(path.trim_prefix("res://"))
		DirAccess.make_dir_recursive_absolute(destination.get_base_dir())
		var source := FileAccess.open(path, FileAccess.READ)
		var output := FileAccess.open(destination, FileAccess.WRITE)
		if source == null or output == null:
			push_error("Could not inspect packed resource: " + path)
			quit(1)
			return
		var bytes := source.get_buffer(source.get_length())
		output.store_buffer(bytes)
		output.close()
		if path.ends_with(".gdc"):
			var expanded_size := bytes.decode_u32(8)
			var expanded := bytes.slice(12)
			if expanded_size > 0:
				expanded = expanded.decompress(expanded_size, FileAccess.COMPRESSION_ZSTD)
			if expanded.is_empty():
				push_error("Could not inspect compiled script: " + path)
				quit(1)
				return
			var decoded := FileAccess.open(destination + ".decoded", FileAccess.WRITE)
			decoded.store_buffer(expanded)
			decoded.close()
	var report := FileAccess.open(args[1].path_join("pack-files.json"), FileAccess.WRITE)
	report.store_string(JSON.stringify(files, "  "))
	report.close()
	var licenses := FileAccess.open(args[1].path_join("ENGINE-LICENSES.txt"), FileAccess.WRITE)
	licenses.store_string("Godot Engine\nhttps://godotengine.org/license/\n\n" + Engine.get_license_text() + "\n\nThird-party notices\n")
	for component in Engine.get_copyright_info():
		licenses.store_string("\n" + str(component.get("name", "")) + "\n")
		for part in component.get("parts", []):
			licenses.store_string("License: " + str(part.get("license", "")) + "\n")
			for notice in part.get("copyright", []):
				licenses.store_string(str(notice) + "\n")
	for title in Engine.get_license_info():
		licenses.store_string("\n" + str(title) + "\n" + str(Engine.get_license_info()[title]) + "\n")
	licenses.close()
	print("PACK_AUDIT_EXTRACTED ", files.size())
	quit()

func _collect(path: String, files: Array[String]) -> void:
	var directory := DirAccess.open(path)
	if directory == null:
		return
	directory.include_hidden = true
	directory.list_dir_begin()
	var entry := directory.get_next()
	while not entry.is_empty():
		if directory.current_is_dir():
			_collect(path.path_join(entry), files)
		else:
			files.append(path.path_join(entry))
		entry = directory.get_next()
	directory.list_dir_end()
