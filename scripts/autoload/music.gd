extends Node
## Banda sonora: una pista en bucle por bioma + menú, con fundido cruzado entre pistas.
## Prefiere assets/audio/music/<pista>.mp3 (Lyria, API de Gemini) y si no existe usa el .wav sintetizado.
## Los MP3 se encadenan consigo mismos con un fundido de LOOP_FADE s para que el bucle no se note.

const DIR := "res://assets/audio/music/"
const FADE := 1.5
const LOOP_FADE := 2.5

var _a: AudioStreamPlayer
var _b: AudioStreamPlayer
var _active: AudioStreamPlayer
var _self_loop := false
var _looping := false
var current := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_a = AudioStreamPlayer.new()
	_b = AudioStreamPlayer.new()
	for p in [_a, _b]:
		p.bus = "Music"
		add_child(p)


func _load(track: String) -> AudioStream:
	for ext in ["ogg", "mp3", "wav"]:
		var path: String = DIR + track + "." + ext
		if ResourceLoader.exists(path):
			return load(path)
	return null


func play(track: String) -> void:
	if track == current:
		return
	var stream := _load(track)
	if stream == null:
		return
	current = track
	_self_loop = false
	if stream is AudioStreamWAV:
		var w: AudioStreamWAV = stream
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD
		w.loop_begin = 0
		# Contamos muestras por duración (la importación puede comprimir los datos).
		w.loop_end = int(w.get_length() * w.mix_rate)
	elif stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = false
		_self_loop = true
	_crossfade_to(stream, FADE)


func _crossfade_to(stream: AudioStream, fade: float) -> void:
	var old: AudioStreamPlayer = _active if _active and _active.playing else null
	var nxt := _b if old == _a else _a
	nxt.stream = stream
	nxt.volume_db = -40.0
	nxt.play()
	_active = nxt
	_looping = false
	var tw := create_tween().set_parallel(true)
	tw.tween_property(nxt, "volume_db", 0.0, fade)
	if old:
		tw.tween_property(old, "volume_db", -40.0, fade)
		tw.chain().tween_callback(old.stop)


func _process(_delta: float) -> void:
	# Bucle de MP3: poco antes del final arranca otra copia y se funden.
	if not _self_loop or _active == null or not _active.playing or _looping:
		return
	var length := _active.stream.get_length()
	if length > LOOP_FADE * 2.0 and _active.get_playback_position() >= length - LOOP_FADE:
		_looping = true
		_crossfade_to(_active.stream, LOOP_FADE)
