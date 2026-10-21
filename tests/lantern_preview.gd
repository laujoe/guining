extends Node
func _ready() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/lantern-preview.json"
	app.core.settings_path = "res://.test-output/lantern-preview-settings.json"
	add_child(app)
	app.core.reset_state()
	app.core.state.memory = "Ding"
	app.core.state.prologue = true
	app.go("ding_lamp", false)
	app.transition_view.visible = false
	app.transition_left = 0
	# Allows MCP to inspect a background game without focus-loss pausing.
	if get_window().focus_exited.is_connected(app._on_focus_lost):
		get_window().focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
