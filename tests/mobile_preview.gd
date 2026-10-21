extends Node

func _ready() -> void:
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/mobile-preview.json"
	app.core.settings_path = "res://.test-output/mobile-preview-settings.json"
	app.touch_controls = true
	add_child(app)
	app.core.reset_state()
	app.core.settings.reduced_motion = true
	app.go("army", false)
	app.transition_view.visible = false
	app.transition_left = 0
	app.close_modal()
	app.set_process(false)
	if get_window().focus_exited.is_connected(app._on_focus_lost):
		get_window().focus_exited.disconnect(app._on_focus_lost)
