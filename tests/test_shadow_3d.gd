extends SceneTree
const Core = preload("res://scripts/game_core.gd")
var failures: Array = []
var checks = 0
func expect(ok: bool, text: String) -> void:
	checks += 1
	if not ok: failures.append(text); printerr("FAIL SHADOW: ",text)
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var c = Core.new()
	for edge in c.graph.edges:
		var points = c.shadow_edge_points(edge)
		expect(points.a.distance_to(points.b) > 1.0,"real depth gap "+edge.id)
		for node in [edge.fromNode,edge.toNode]:
			var other = edge.toNode if node == edge.fromNode else edge.fromNode
			for angle in range(4):
				var error = c.shadow_seam_error(edge,node,angle,0.52)
				var joined = other in c.shadow_edges(node,angle,0.52)
				expect(joined == (angle == int(edge.viewIndex)),"only designed view connects "+edge.id+node+str(angle))
				if joined: expect(error < 0.01,"actual endpoint projection matches "+edge.id+node)
	c.state.shadow = {"node":"B","view":2,"lamp":0.15}
	expect(c.traverse_shadow("D"),"optional side shelf reachable")
	expect(not c.rotate_shadow(1),"dead end has no rotation handle")
	expect(c.traverse_shadow("B"),"dead end always returns")
	expect(not c.traverse_shadow("F"),"cannot walk on a visually tempting solid shortcut")
	c.state.shadow = {"node":"E","view":1,"lamp":0.15}
	for sample in [0.0,0.419,0.42,0.52,0.62,0.621,1.0]:
		c.set_shadow_lamp(sample)
		expect(("F" in c.shadow_edges("E",1,sample)) == (sample >= 0.42 and sample <= 0.62),"lamp boundary "+str(sample))
	c.set_shadow_lamp(0.52)
	c.state.shadow.view = 0
	expect(not c.traverse_shadow("F"),"lamp alone cannot bridge a wrong perspective")
	c.state.shadow.view = 1
	expect(c.traverse_shadow("F"),"lamp plus correct projection reaches room")
	expect(not c.set_shadow_lamp(0),"lamp only movable at high platform")
	# Build the production renderer and verify all solid mesh transforms remain fixed.
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/shadow-rules-save.json"
	app.core.settings_path = "res://.test-output/shadow-rules-settings.json"
	root.add_child(app)
	app.core.reset_state()
	app.core.state.shadow = {"node":"A","view":0,"lamp":0.15}
	app.go("ding_graph",false)
	app.set_process(false)
	app.close_modal()
	app.stage.shadow_library.sync()
	var library = app.stage.shadow_library
	var physical: Dictionary = {}
	for mesh in library.architecture.find_children("*","MeshInstance3D",true,false): physical[mesh] = mesh.global_transform
	for angle in range(4):
		app.core.state.shadow.view = angle
		library.sync()
		for mesh in physical:
			# Movable wooden handle tops are deliberately excluded.
			if mesh.get_parent() in library.handle_roots.values(): continue
			expect(mesh.global_transform == physical[mesh],"solid architecture fixed while camera orbits")
	app.core.state.shadow = {"node":"E","view":1,"lamp":0.52}
	library.sync()
	var lamp_position = library.lamp_root.position
	app.core.set_shadow_lamp(0.1)
	library.sync()
	expect(library.lamp_root.position != lamp_position,"lamp moves physically on rail")
	expect(not library.seam_nodes.EF.visible,"misplaced lamp hides gold join")
	app.core.set_shadow_lamp(0.52)
	library.sync()
	expect(library.seam_nodes.EF.visible,"correct lamp reveals gold join")
	app.graph_rotating = true
	app.busy = true
	library.sync()
	expect(not library.seam_nodes.EF.visible,"no premature join during rotation")
	app.graph_rotating = false
	app.busy = false
	app.open_pause()
	var state = app.core.state.shadow.duplicate()
	app.rotate_graph(1)
	app.traverse_graph("F")
	expect(app.core.state.shadow == state,"pause rejects rotation and crossing")
	app.close_modal()
	app.core.save_game()
	var loaded = Core.new()
	loaded.save_path = app.core.save_path
	expect(loaded.load_game() and loaded.state.shadow == state,"old shadow snapshot schema resumes without reset")
	app.queue_free()
	await process_frame
	var report = FileAccess.open("res://.test-output/shadow-results.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures},"\t"))
	report.close()
	print("SHADOW 3D: ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
