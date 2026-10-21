extends "res://scripts/main.gd"
## Developer-only entrance; all checkpoints and settings are isolated.
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	core.save_path = "res://.test-output/ending-preview-save.json"
	core.settings_path = "res://.test-output/ending-preview-settings.json"
	super._ready()
	core.reset_state()
	core.state.completed = ["Ding", "Student", "Wife"]
	core.state.jade = [0, 1, 2]
	core.state.inscription = true
	core.settings.reduced_motion = false
	go("accident_prompt", false)

func build_credits() -> void:
	super.build_credits()
	button("ReplayEnding", "重看雨夜结局", Rect2(600, 675, 400, 54), func():
		core.state.events.clear()
		core.state.released = false
		core.state.finished = false
		go("accident_prompt", false))
