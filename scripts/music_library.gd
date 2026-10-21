extends RefCounted

# Original recordings from Kevin MacLeod / incompetech.com, CC BY 4.0.
# Full sources and attribution travel with the game in assets/music/MUSIC-NOTICE.txt.
const TRACKS = {
	"ripples": {"title": "Ripples", "file": "ripples.mp3", "gain": 0.72},
	"eastern": {"title": "Eastern Thought", "file": "eastern-thought.mp3", "gain": 0.58},
	"shenyang": {"title": "Shenyang", "file": "shenyang.mp3", "gain": 0.55},
	"drums": {"title": "Asian Drums", "file": "asian-drums.mp3", "gain": 0.48},
	"night": {"title": "Long Note Three", "file": "long-note-three.mp3", "gain": 0.48},
	"willow": {"title": "Willow and the Light", "file": "willow-and-the-light.mp3", "gain": 0.62},
}
const CUES = {
	"mist": "ripples", "lantern": "eastern", "ink": "eastern",
	"letter": "willow", "storm": "drums", "battle": "drums",
	"farewell": "ripples", "home": "shenyang", "night": "night",
}

static func track_for(cue: String) -> String:
	return CUES.get(cue, "ripples")

static func stream_for(track: String) -> AudioStreamMP3:
	var stream = load("res://assets/music/kevin-macleod/" + TRACKS[track].file) as AudioStreamMP3
	if stream == null:
		push_error("无法载入背景音乐：" + track)
		return null
	stream = stream.duplicate()
	stream.loop = true
	return stream

static func gain_for(track: String) -> float:
	return TRACKS.get(track, {}).get("gain", 0.6)
