extends SceneTree

class CharacterBoard extends Control:
	const Ye = preload("res://scripts/ye_sheng.gd")
	var font: Font
	func _ready() -> void:
		font = SystemFont.new()
		font.font_names = PackedStringArray(["Microsoft YaHei", "SimHei"])
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1600, 900), Color("eee7d8"))
		draw_string(font, Vector2(65, 65), "叶生 · 固定造型动作", HORIZONTAL_ALIGNMENT_LEFT, -1, 32, Color("25393b"))
		var poses = ["stand", "run", "run", "run", "run", "jump", "slide", "brace", "brush_prepare", "brush", "brush_recover", "hit"]
		var labels = ["站立", "跑步 ①", "跑步 ②", "跑步 ③", "跑步 ④", "跳跃", "低身 / 闪避", "顶风", "挥笔 · 蓄势", "挥笔 · 出笔", "挥笔 · 收势", "失衡 / 受击"]
		for i in range(12):
			var p := Vector2(200 + (i % 4) * 395, 295 + (i / 4) * 265)
			draw_style_box(_panel(), Rect2(p.x - 165, p.y - 195, 330, 240))
			Ye.paint(self, p, 1.4, poses[i], (i - 1) / 9.0 if i in [1, 2, 3, 4] else 0.0, false, 1, false)
			draw_string(font, p + Vector2(-90, 34), labels[i], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("384a4d"))
	func _panel() -> StyleBoxFlat:
		var box := StyleBoxFlat.new()
		box.bg_color = Color("f8f4eb")
		box.set_corner_radius_all(12)
		return box

func _initialize() -> void:
	call_deferred("run")

func capture(name_value: String) -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://.test-output/ye-" + name_value + ".png")

func run() -> void:
	root.size = Vector2i(1280, 720)
	var app = load("res://scenes/main.tscn").instantiate()
	app.core.save_path = "res://.test-output/ye-save.json"
	app.core.settings_path = "res://.test-output/ye-settings.json"
	root.add_child(app)
	await process_frame
	if root.focus_exited.is_connected(app._on_focus_lost):
		root.focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	app.set_process(false)
	app.stage.set_process(false)
	app.core.reset_state()
	app.core.state.memory = "Wife"
	app.core.state.season = 0
	app.go("runner")
	app.stage.clock = 0.23
	app.transition_left = 0
	app.transition_view.visible = false
	app.stage.queue_redraw()
	await capture("run")
	app.jump_height = 90
	app.stage.queue_redraw()
	await capture("jump")
	app.jump_height = 0
	app.slide_time = 0.4
	app.stage.queue_redraw()
	await capture("slide")
	app.slide_time = 0
	app.bracing = true
	app.core.state.season = 3
	app.season_time = 20
	app.stage.queue_redraw()
	await capture("brace")
	app.bracing = false
	app.stumble_protect = 1.0
	app.stage.queue_redraw()
	await capture("hit")
	app.audio_player.stop()
	app.note_player.stop()
	app.audio_player.stream = null
	app.note_player.stream = null
	app.queue_free()
	await process_frame
	var board := CharacterBoard.new()
	root.add_child(board)
	await capture("all-actions")
	board.queue_free()
	await process_frame
	print("YE SHENG: 6 rendered captures complete")
	quit()
