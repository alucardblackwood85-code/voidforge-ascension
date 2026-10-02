extends Node
## Banda sonora: una pista en bucle por bioma + menú (assets/audio/music/<pista>.wav), con fundido cruzado.

const DIR := "res://assets/audio/music/"
const FADE := 1.5

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Music"
		add_child(p)


func play(track: String) -> void:
	if track == current:
		return
	var path := DIR + track + ".wav"
	if not ResourceLoader.exists(path):
		return
	current = track
	var stream: AudioStream = load(path)
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# Contamos muestras por duración (la importación puede comprimir los datos).
		w.loop_end = int(w.get_length() * w.mix_rate)
	var old: AudioStreamPlayer = _a if _a.playing else (_b if _b.playing else null)
	var nxt := _b if old == _a else _a
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, FADE)
	if old:
		tw.tween_property(old, "volume_db", -40.0, FADE)
		tw.chain().tween_callback(old.stop)
