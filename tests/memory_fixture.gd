extends RefCounted
## Only this excluded test fixture can enable the interactive generator.
func configure(app) -> void:
	var directory = "res://.test-output/memory-atlas"
	DirAccess.make_dir_recursive_absolute(directory)
	app.core.save_path = directory + "/current.json"
	app.core.settings_path = directory + "/settings.json"
	app.memory_test_mode = true
	app.memory_test_fixture = self
	app.memory_test_generator = generate

func generate(app) -> Dictionary:
	var isolated = load("res://scripts/game_core.gd").new()
	isolated.state.route = "hub"
	isolated.state.prologue = true
	return app.memory_saves.save_memory(isolated.state, {"source": "test", "title": "测试记忆 · 雾中渡口"})
