extends SceneTree
## Actual GPU frames verify motion, pause, reduced motion and large captions.
func _initialize() -> void:
	call_deferred("run")

func frame(app, age: float) -> Image:
	app.scene_age = age
	app.accident_time = age
	app.stage.ending_sequence.sync(app)
	await process_frame
	await RenderingServer.frame_post_draw
	return root.get_texture().get_image()

func run() -> void:
	var app = load("res://tests/ending_preview.tscn").instantiate()
	root.add_child(app)
	await process_frame
	var probe = load("res://tests/ending_visual_probe.gd").new()
	probe.prepare(app)
	app.go("body", false)
	app.transition_left = 0
	app.transition_view.visible = false
	var failures: Array = []
	var captures: Array = []
	for shot in [["body", 14.0], ["finale", 5.0], ["finale", 12.0], ["finale", 19.0], ["finale", 24.0]]:
		app.go(shot[0], false)
		app.transition_left = 0
		app.transition_view.visible = false
		var age: float = shot[1]
		app.core.settings.reduced_motion = false
		var first = await frame(app, age)
		var path = "res://.test-output/revision-ending-%s-%d.png" % [shot[0], int(age)]
		captures.append({"path": path, "error": first.save_png(path)})
		var moving = await frame(app, age + 0.5)
		if first.get_data() == moving.get_data(): failures.append("motion does not change pixels at %s" % age)
		var frozen = await frame(app, age + 0.5)
		if moving.get_data() != frozen.get_data(): failures.append("fixed clock does not freeze shader at %s" % age)
		app.core.settings.reduced_motion = true
		var still_a = await frame(app, age)
		var still_b = await frame(app, age + 0.5)
		if still_a.get_data() != still_b.get_data(): failures.append("reduced motion changes at %s" % age)
	app.core.settings.text_scale = 1.3
	app.go("body", false)
	app.transition_left = 0
	app.transition_view.visible = false
	var large = await frame(app, 10.7)
	large.save_png("res://.test-output/ending-caption130.png")
	app.go("accident", false)
	app.transition_view.visible = false
	app.core.settings.reduced_motion = false
	app.accident_x = -150
	var left = await frame(app, 20)
	app.accident_x = 150
	var right = await frame(app, 20)
	if left.get_data() == right.get_data(): failures.append("swimming does not move the first-person camera")
	var report = {"checks": 16, "failures": failures, "render_size": str(large.get_size()), "captures": captures}
	var file = FileAccess.open("res://.test-output/ending-render-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("ENDING RENDER: ", report)
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	await create_timer(0.15).timeout
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
