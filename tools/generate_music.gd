extends SceneTree
## Original pentatonic score, synthesized offline with plucked strings and a soft reed.
## No downloaded recordings or external soundfonts. The last notes decay before looping.
const TRACKS = {
	"mist": {"bpm":60.0, "root":50, "melody":[0,-1,2,4,7,-1,4,2,0,-1,-3,0,2,4,2,-1], "reed":0.10},
	"lantern": {"bpm":66.0, "root":50, "melody":[0,2,-1,4,2,0,-3,-1,0,4,7,4,2,-1,0,-1], "reed":0.06},
	"ink": {"bpm":90.0, "root":55, "melody":[0,2,4,7,9,7,4,2,4,7,4,2,0,2,0,-1], "reed":0.07},
	"letter": {"bpm":72.0, "root":57, "melody":[0,4,7,-1,9,7,4,2,0,2,4,-1,2,0,-3,-1], "reed":0.16},
	"storm": {"bpm":84.0, "root":43, "melody":[0,2,0,-3,0,2,4,2,0,-3,0,2,0,-1,-3,-1], "reed":0.04},
	"farewell": {"bpm":56.0, "root":50, "melody":[7,-1,4,2,0,-1,2,0,-3,-1,0,2,0,-1,-1,-1], "reed":0.18},
	"home": {"bpm":70.0, "root":55, "melody":[0,4,7,9,7,4,2,4,7,9,12,9,7,4,2,0], "reed":0.16}
}
var rate = 22050

func note(buffer: PackedFloat32Array, start: float, midi: int, length: float, gain: float, reed: float) -> void:
	var freq = 440.0 * pow(2.0, (midi - 69) / 12.0)
	var offset = int(start * rate)
	for i in range(int(length * rate)):
		var index = offset + i
		if index >= buffer.size(): break
		var t = i / float(rate)
		var phase = TAU * freq * t
		var attack = minf(1, t * 90)
		var tail = minf(1, (length - t) * 4)
		var pluck = (sin(phase) + 0.32 * sin(phase * 2.002) + 0.12 * sin(phase * 3.0)) * exp(-t * 2.5)
		var breath = sin(phase + 0.012 * sin(TAU * 4.7 * t)) * minf(1, t * 5) * exp(-t * 0.65) * reed
		buffer[index] += (pluck + breath) * gain * attack * tail

func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/music")
	for key in TRACKS:
		var track: Dictionary = TRACKS[key]
		var beat: float = 60.0 / track.bpm
		var duration: float = beat * 36
		var mix = PackedFloat32Array()
		mix.resize(int(duration * rate))
		for step in range(32):
			var pitch: int = track.melody[step % 16]
			if pitch != -1:
				note(mix, beat * step, track.root + pitch + (12 if step >= 16 else 0), beat * 3, 0.22, track.reed)
			if step % 4 == 0:
				note(mix, beat * step, track.root - 12 + [0, -3, 4, 0][(step / 4) as int % 4], beat * 4, 0.13, 0.04)
			if step % 2 == 1:
				note(mix, beat * step, track.root + 7, beat * 2, 0.055, 0)
		var delay = int(rate * 0.27)
		for i in range(delay, mix.size()): mix[i] += mix[i - delay] * 0.23
		var pcm = PackedByteArray()
		pcm.resize(mix.size() * 2)
		for i in range(mix.size()):
			var fade = minf(1, i / float(rate) * 2) * minf(1, (mix.size() - i) / float(rate))
			pcm.encode_s16(i * 2, int(clampf(mix[i] * fade, -0.95, 0.95) * 32767))
		var stream = AudioStreamWAV.new()
		stream.format = AudioStreamWAV.FORMAT_16_BITS
		stream.mix_rate = rate
		stream.data = pcm
		stream.save_to_wav("res://assets/music/" + key + ".wav")
		print("MUSIC_GENERATED ", key, " ", duration)
	quit()
