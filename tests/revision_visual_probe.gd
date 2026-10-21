extends SceneTree
var app
func _initialize() -> void:
	call_deferred("run")
func shot(id: String) -> void:
	app.transition_view.visible = false
	for i in range(8): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-output/review-" + id + ".png")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/review-visual-save.json"
	app.core.settings_path = "res://.test-output/review-visual-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.settings.text_scale = 1.3
	root.size = Vector2i(1280,720)
	app.core.state.memory = "Ding"
	for index in [0,1]:
		app.core.state.dialogue = {"id":"DingDinner","index":index,"next":"ding_seat"}
		app.go("dialogue",false)
		app.scene_age=4
		app.dialogue_entrance=1
		app.dialogue_label.modulate.a=1
		app.dialogue_label.visible_characters=-1
		await shot("ding-"+str(index))
	app.core.new_board()
	app.go("board",false)
	await shot("board")
	app.go("ding_lamp",false)
	app.show_maze_map()
	app.overlay.get_node("MazeRoute").pressed.emit()
	await shot("map")
	app.close_modal()
	app.core.state.memory="Wife"
	for memory in app.core.MEMORY_IDS:
		for event in app.core.PREREQUISITES[memory]: app.core.event(event)
		app.core.complete_memory(memory)
	app.go("wife_shard",false)
	await shot("jade-three")
	app.go("accident",false)
	app.accident_time=15
	await shot("overboard")
	app.go("finale",false)
	app.scene_age=24
	await shot("reunion")
	print("REVISION_VISUAL: 7 captures")
	app.queue_free()
	await process_frame
	quit()
