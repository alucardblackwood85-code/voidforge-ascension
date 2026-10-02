extends SceneTree
## Aplica un filtro de "IA de nave" a las voces de assets/audio/voice_raw/ → assets/audio/voice/.
## Modulación en anillo suave + eco metálico corto + reducción de bits + paso alto.
## Uso: godot --headless --script res://scripts/tools/robotize_voice.gd

const IN_DIR := "res://assets/audio/voice_raw/"
const OUT_DIR := "res://assets/audio/voice/"


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var dir := DirAccess.open(ProjectSettings.globalize_path(IN_DIR))
	var count := 0
	for f in dir.get_files():
		if f.ends_with(".wav"):
			_process_file(f)
			count += 1
	print("Voces procesadas: %d" % count)
	quit()


func _process_file(name: String) -> void:
	var bytes := FileAccess.get_file_as_bytes(ProjectSettings.globalize_path(IN_DIR + name))
	# Busca los chunks "fmt " y "data" (la API puede dejar el tamaño de data sin rellenar).
	var rate := 24000
	var data_off := -1
	var i := 12
	while i < bytes.size() - 8:
		var id := bytes.slice(i, i + 4).get_string_from_ascii()
		var sz := bytes.decode_u32(i + 4)
		if id == "fmt ":
			rate = bytes.decode_u32(i + 12)
		elif id == "data":
			data_off = i + 8
			break
		i += 8 + sz
	if data_off < 0:
		push_error("WAV sin datos: " + name)
		return
	var n := (bytes.size() - data_off) / 2
	var x := PackedFloat32Array()
	x.resize(n)
	for k in n:
		x[k] = bytes.decode_s16(data_off + k * 2) / 32768.0
	var y := PackedFloat32Array()
	y.resize(n)
	var echo := int(0.009 * rate)
	var hp_state := 0.0
	var hp_prev := 0.0
	var rc := 1.0 / (TAU * 220.0)
	var ah := rc / (rc + 1.0 / rate)
	var hold := 0.0
	for k in n:
		var t := float(k) / rate
		var s := x[k]
		# Modulación en anillo parcial (timbre metálico sin perder inteligibilidad).
		s = s * (0.62 + 0.38 * sin(TAU * 55.0 * t))
		# Muestreo y retención a ~12 kHz + cuantización a 10 bits: aspereza digital.
		if k % 2 == 0:
			hold = round(s * 512.0) / 512.0
		s = hold
		# Paso alto (quita graves, suena a altavoz de cabina).
		hp_state = ah * (hp_state + s - hp_prev)
		hp_prev = s
		y[k] = hp_state
	# Eco metálico corto (efecto "lata").
	for k in range(echo, n):
		y[k] += y[k - echo] * 0.38
	var peak := 0.0001
	for k in n:
		peak = maxf(peak, absf(y[k]))
	var out := PackedByteArray()
	out.resize(n * 2)
	for k in n:
		out.encode_s16(k * 2, int(clampf(y[k] / peak * 0.9, -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	w.data = out
	w.save_to_wav(ProjectSettings.globalize_path(OUT_DIR + name))
