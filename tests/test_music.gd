extends SceneTree

var app
var checks = 0
var failures: Array = []

func expect(ok: bool, message: String) -> void:
	checks += 1
	if not ok:
		failures.append(message)
		printerr("FAIL MUSIC: ", message)

func _initialize() -> void:
	call_deferred("run")

func settle() -> void:
	await create_timer(1.6).timeout
	app.update_volume()

func run() -> void:
	DirAccess.make_dir_recursive_absolute("res://.test-output")
	app = load("res://scenes/main.tscn").instantiate()
	var run_id = str(Time.get_ticks_usec())
	app.core.save_path = "res://.test-output/music-" + run_id + ".json"
	app.core.settings_path = "res://.test-output/music-settings-" + run_id + ".json"
	root.add_child(app)
	await process_frame
	app.set_process(false)
	app.get_window().focus_exited.disconnect(app._on_focus_lost)
	app.close_modal()
	await settle()
	expect(app.audio_player.playing, "real audio playback starts")
	for track in app.MusicLibrary.TRACKS:
		var stream = app.MusicLibrary.stream_for(track)
		expect(stream != null and stream.loop and stream.get_length() > 120, "full track decodes and loops: " + track)
		var playback = stream.instantiate_playback()
		playback.start(stream.get_length() - 0.02)
		var samples = playback.mix_audio(1.0, 4410)
		expect(samples.size() == 4410 and playback.is_playing(), "decoder crosses repeat boundary: " + track)
		playback.stop()
	# A -> B -> A during fade-out must cancel B, not switch to it later.
	app.mode = "army"
	app.set_ambience(2)
	await create_timer(0.1).timeout
	app.mode = "hub"
	app.set_ambience(0)
	await settle()
	expect(app.music_track == "ripples" and app.audio_player.stream.data == app.MusicLibrary.stream_for("ripples").data, "rapid route change keeps final requested recording")
	var position_before = app.audio_player.get_playback_position()
	app.mode = "jade"
	app.set_ambience(0)
	await create_timer(0.2).timeout
	expect(app.audio_player.get_playback_position() > position_before, "same track continues across backgrounds without restarting")
	app.mode = "finale"
	app.set_ambience(2)
	app.show_music_credits()
	await create_timer(0.6).timeout
	expect(app.audio_player.stream_paused and not app.music_fade.is_running(), "modal pauses both player and transition")
	expect(app.overlay.find_child("CloseMusicCredits", true, false) != null, "attribution is reachable in game")
	app.close_modal()
	await settle()
	expect(app.music_track == "shenyang" and app.audio_player.playing and not app.audio_player.stream_paused, "transition resumes to requested track")
	app.core.settings.volume = 0.0
	app.update_volume()
	expect(app.audio_player.volume_db <= -79, "volume slider mutes music")
	app.core.settings.volume = 0.5
	app.update_volume()
	expect(app.audio_player.volume_db > -79, "volume slider restores music")
	var file = FileAccess.open("res://.test-output/music-results.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks": checks, "failures": failures}, "\t"))
	file.close()
	print("MUSIC: ", checks, " checks; ", failures.size(), " failures")
	app.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
