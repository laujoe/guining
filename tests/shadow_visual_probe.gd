extends SceneTree
var app
var failures: Array = []
var results: Array = []
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/shadow-visual-save.json"
	app.core.settings_path = "res://.test-output/shadow-visual-settings.json"
	root.add_child(app)
	if root.focus_exited.is_connected(app._on_focus_lost): root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Ding"
	root.size = Vector2i(1600,900)
	for sample in [["A",0,0.15],["A",1,0.15],["B",2,0.15],["B",3,0.15],["D",2,0.15],["C",0,0.15],["E",0,0.15],["E",1,0.15],["E",1,0.52]]:
		app.core.state.shadow = {"node":sample[0],"view":sample[1],"lamp":sample[2]}
		app.go("ding_graph",false)
		app.transition_view.visible = false
		for i in range(5): await process_frame
		await RenderingServer.frame_post_draw
		var file = "res://.test-output/mirror-%s-%s-%s.png" % sample
		root.get_texture().get_image().save_png(file)
		var library = app.stage.shadow_library
		var seams = []
		for edge in app.core.graph.edges:
			if not library.seam_nodes[edge.id].visible: continue
			var p = app.core.shadow_edge_points(edge,sample[2])
			var error = library.camera.unproject_position(p.a).distance_to(library.camera.unproject_position(p.b))
			seams.append({"id":edge.id,"pixels":error})
			if error > 12.1: failures.append("visible seam mismatch "+edge.id)
		results.append({"file":file,"seams":seams})
	root.size = Vector2i(960,540)
	app.core.settings.text_scale = 1.3
	app.refresh_graph()
	for i in range(5): await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-output/mirror-small-text130.png")
	for control in app.ui.get_children():
		if control is Button or control is Label:
			if not Rect2(0,0,1600,900).encloses(control.get_rect()): failures.append("UI bounds "+str(control.name))
	results.append({"file":"res://.test-output/mirror-small-text130.png"})
	var report = FileAccess.open("res://.test-output/shadow-visual-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"results":results,"failures":failures},"\t"))
	report.close()
	print("SHADOW VISUAL: ",results.size()," captures; ",failures)
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
