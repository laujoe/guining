extends SceneTree
## Original procedural ambience, generated offline; shipped as WAV, no runtime synthesis load.
func _initialize() -> void:
	seed(260118)
	var rate = 22050
	var duration = 16
	for scene in range(4):
		var samples = PackedByteArray()
		samples.resize(rate * duration * 2)
		var smooth_noise = 0.0
		for i in range(rate * duration):
			var t = i / float(rate)
			var fade = minf(minf(t / 2, (duration - t) / 2), 1)
			smooth_noise = lerpf(smooth_noise, randf_range(-1, 1), 0.03)
			var water = smooth_noise * (0.13 if scene == 0 else 0.035)
			var local_t = fposmod(t, 4.0)
			var note_index = int(t / 4) % 4
			var frequencies = [196.0, 220.0, 293.665, 261.626]
			var freq: float = frequencies[(note_index + scene) % 4]
			var envelope = minf(local_t * 15, 1) * exp(-local_t * 1.4)
			var note = (sin(TAU * freq * t) + sin(TAU * freq * 2.001 * t) * 0.22 + sin(TAU * freq * 3 * t) * 0.06) * envelope * 0.045
			var drone = sin(TAU * 98 * t) * 0.006 * (0.6 + 0.4 * sin(t * TAU / 16))
			samples.encode_s16(i * 2, int(clampf((water + note + drone) * fade, -1, 1) * 32767))
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = samples
		stream.save_to_wav("res://assets/ambience_%d.wav" % scene)
	print("Generated four original ambient loops.")
	quit()
