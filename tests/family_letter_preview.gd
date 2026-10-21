extends Node
## Isolated preview: never reads or writes the player's story or settings.
var app

func _ready() -> void:
	app = preload("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/family-letter-preview-save.json"
	app.core.settings_path = "res://.test-output/family-letter-preview-settings.json"
	add_child(app)
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.settings.reduced_motion = false
	app.core.settings.text_scale = 1.0
	app.go("letter_open", false)
	app.update_transition(10)
