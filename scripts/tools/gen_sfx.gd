extends SceneTree
## Sintetizador procedural de efectos de sonido (estilo sfxr). Genera assets/audio/sfx/*.wav.
## Uso: godot --headless --script res://scripts/tools/gen_sfx.gd
## Cada sonido = capas {w: onda, f0→f1: barrido Hz, t: inicio, d: duración, v: volumen, a: ataque,
## k: caída (exp), vib/vd: vibrato Hz/profundidad, lp: filtro paso bajo Hz, hp: paso alto}.
## Opciones globales: drive (distorsión), echo [retardo s, realimentación, repeticiones].

const SR := 44100
const OUT_DIR := "res://assets/audio/sfx/"
const AMMO_STYLE := "pew"   # pew | beam | plasma (láseres por munición que usa el juego)


func L(w: String, f0: float, f1: float, d: float, v: float = 1.0, extra: Dictionary = {}) -> Dictionary:
	var l := {"w": w, "f0": f0, "f1": f1, "d": d, "v": v, "t": 0.0, "a": 0.004, "k": 4.0}
	l.merge(extra, true)
	return l


func sounds() -> Dictionary:
	var base := {
		# --- Láseres del jugador: cada uno con firma propia (19.3) ---
		"laser_l01": {"layers": [L("square", 980, 260, 0.16, 0.6, {"k": 5.0, "lp": 5000}), L("sine", 1960, 520, 0.08, 0.3)]},
		"laser_l02": {"layers": [L("square", 1300, 600, 0.07, 0.5, {"k": 6.0, "lp": 6000}), L("square", 1250, 560, 0.07, 0.5, {"t": 0.045, "k": 6.0, "lp": 6000})]},
		"laser_l03": {"layers": [L("sine", 2600, 1900, 0.11, 0.7, {"k": 7.0}), L("noise", 6000, 6000, 0.03, 0.15, {"hp": 3000})]},
		"laser_l04": {"layers": [L("tri", 760, 330, 0.13, 0.8, {"k": 5.0}), L("noise", 3000, 3000, 0.015, 0.4, {"lp": 6000})]},
		"laser_l05": {"layers": [L("saw", 520, 190, 0.26, 0.55, {"vib": 38, "vd": 0.18, "lp": 3500, "k": 3.0}), L("square", 1040, 380, 0.2, 0.2, {"vib": 38, "vd": 0.2})]},
		"laser_l06": {"layers": [L("saw", 340, 140, 0.24, 0.5, {"lp": 1800, "k": 3.0}), L("noise", 2500, 600, 0.26, 0.45, {"lp": 2200, "k": 2.5})], "drive": 1.6},
		"laser_l07": {"layers": [L("sine", 1850, 1650, 0.2, 0.55, {"vib": 22, "vd": 0.04, "a": 0.02, "k": 3.0}), L("sine", 3700, 3300, 0.2, 0.2, {"vib": 31, "vd": 0.05, "a": 0.02})]},
		"laser_l08": {"layers": [L("noise", 5000, 800, 0.2, 0.7, {"lp": 4000, "k": 5.0}), L("square", 620, 180, 0.16, 0.4, {"k": 5.0})]},
		"laser_l09": {"layers": [L("noise", 4000, 4000, 0.3, 0.55, {"lp": 5000, "vib": 60, "vd": 0.9, "k": 3.0}), L("square", 900, 300, 0.3, 0.3, {"vib": 47, "vd": 0.5, "k": 3.0})], "drive": 1.4},
		"laser_l10": {"layers": [L("saw", 230, 55, 0.5, 0.7, {"lp": 1400, "k": 2.5}), L("noise", 1500, 200, 0.45, 0.5, {"lp": 1200, "k": 3.0}), L("sine", 110, 40, 0.5, 0.6, {"k": 2.0})], "drive": 1.8},
		"laser_l11": {"layers": [L("sine", 1400, 3200, 0.15, 0.6, {"k": 4.0}), L("square", 700, 1600, 0.15, 0.2, {"lp": 6000, "k": 4.0})]},
		"laser_l12": {"layers": [L("sine", 660, 660, 0.35, 0.5, {"k": 2.5}), L("sine", 990, 990, 0.35, 0.35, {"k": 2.8}), L("tri", 1320, 1250, 0.2, 0.2)]},
		"laser_l13": {"layers": [L("saw", 1300, 90, 0.6, 0.6, {"lp": 4000, "k": 2.0}), L("noise", 6000, 600, 0.6, 0.35, {"lp": 3500, "k": 2.0}), L("sine", 160, 60, 0.6, 0.5, {"k": 2.0})], "drive": 1.5},
		"laser_l14": {"layers": [L("square", 210, 190, 0.25, 0.4, {"lp": 1600, "k": 3.0}), L("square", 214, 194, 0.25, 0.4, {"lp": 1600, "k": 3.0})]},
		"laser_l15": {"layers": [L("sine", 90, 38, 0.55, 0.9, {"k": 2.0}), L("noise", 300, 2500, 0.55, 0.35, {"lp": 1800, "a": 0.2, "k": 1.5})]},
		"laser_l16": {"layers": [L("sine", 1100, 520, 0.12, 0.6, {"k": 5.0})], "echo": [0.08, 0.5, 3]},
		"laser_l17": {"layers": [L("tri", 620, 410, 0.2, 0.45), L("tri", 780, 520, 0.2, 0.4), L("tri", 930, 620, 0.2, 0.35)]},
		"laser_l18": {"layers": [L("saw", 420, 48, 0.55, 0.7, {"lp": 2200, "k": 2.2}), L("noise", 2000, 200, 0.5, 0.4, {"lp": 1500})], "drive": 3.0},
		"laser_drone": {"layers": [L("sine", 1500, 900, 0.07, 0.5, {"k": 6.0}), L("square", 3000, 1800, 0.04, 0.12)]},

		# --- Alienígenas: disparos y habilidades por arquetipo ---
		"e_shot_light": {"layers": [L("square", 520, 240, 0.13, 0.5, {"lp": 3000, "k": 5.0})]},
		"e_shot_swarm": {"layers": [L("square", 760, 1250, 0.07, 0.4, {"lp": 4000, "k": 6.0})]},
		"e_shot_bio": {"layers": [L("sine", 300, 600, 0.12, 0.6, {"vib": 30, "vd": 0.3}), L("noise", 800, 800, 0.1, 0.3, {"lp": 900})]},
		"e_shot_crystal": {"layers": [L("sine", 2200, 2800, 0.1, 0.45, {"k": 5.0}), L("sine", 3300, 4200, 0.08, 0.25)]},
		"e_shot_void": {"layers": [L("saw", 300, 120, 0.16, 0.5, {"lp": 1200, "vib": 12, "vd": 0.3})]},
		"e_heavy": {"layers": [L("saw", 190, 80, 0.32, 0.65, {"lp": 1300, "k": 3.0}), L("noise", 900, 200, 0.25, 0.4, {"lp": 900})], "drive": 1.5},
		"e_charge": {"layers": [L("saw", 90, 620, 0.9, 0.45, {"a": 0.6, "k": 0.5, "lp": 2500}), L("square", 45, 310, 0.9, 0.25, {"a": 0.6, "k": 0.5, "lp": 1200})]},
		"e_dash": {"layers": [L("noise", 3500, 400, 0.45, 0.6, {"lp": 3000, "a": 0.03, "k": 3.0})]},
		"e_heal": {"layers": [L("sine", 520, 520, 0.12, 0.4), L("sine", 660, 660, 0.12, 0.4, {"t": 0.08}), L("sine", 880, 880, 0.18, 0.4, {"t": 0.16})]},
		"e_arm": {"layers": [L("square", 1050, 1050, 0.06, 0.4), L("square", 1050, 1050, 0.06, 0.4, {"t": 0.3}), L("square", 1400, 1400, 0.08, 0.5, {"t": 0.6})]},
		"e_launch": {"layers": [L("sine", 140, 60, 0.18, 0.8, {"k": 4.0}), L("sine", 1800, 600, 0.6, 0.25, {"t": 0.08, "k": 1.2})]},
		"e_spawn": {"layers": [L("sine", 160, 320, 0.45, 0.6, {"vib": 9, "vd": 0.25, "a": 0.08, "k": 2.0}), L("noise", 600, 300, 0.4, 0.3, {"lp": 700})]},
		"e_drain": {"layers": [L("saw", 140, 110, 0.7, 0.4, {"vib": 18, "vd": 0.2, "lp": 900, "a": 0.1, "k": 1.5}), L("sine", 880, 440, 0.7, 0.2, {"a": 0.1})]},
		"e_phase": {"layers": [L("noise", 600, 6000, 0.4, 0.4, {"lp": 5000, "a": 0.3, "k": 0.8}), L("sine", 400, 1600, 0.4, 0.3, {"a": 0.3, "k": 0.8})]},
		"e_snipe_charge": {"layers": [L("sine", 600, 2400, 1.3, 0.35, {"a": 1.1, "k": 0.4}), L("square", 300, 1200, 1.3, 0.1, {"a": 1.1, "k": 0.4, "lp": 3000})]},
		"e_snipe_fire": {"layers": [L("noise", 7000, 2000, 0.25, 0.8, {"lp": 7000, "k": 6.0}), L("saw", 1800, 200, 0.3, 0.5, {"k": 4.0})], "drive": 1.6},
		"e_reflect": {"layers": [L("sine", 1700, 1700, 0.4, 0.5, {"k": 3.0}), L("sine", 2550, 2550, 0.4, 0.3, {"k": 3.5}), L("sine", 3400, 3400, 0.3, 0.2)]},
		"e_pulse": {"layers": [L("sine", 120, 60, 0.6, 0.8, {"vib": 6, "vd": 0.3, "k": 2.0}), L("noise", 400, 200, 0.5, 0.3, {"lp": 500})]},
		"e_nova": {"layers": [L("saw", 80, 900, 0.5, 0.5, {"a": 0.4, "k": 0.6, "lp": 3000}), L("noise", 4000, 300, 0.6, 0.6, {"t": 0.45, "lp": 3000, "k": 3.0})], "drive": 1.5},

		# --- Explosiones e impactos ---
		"explosion_s": {"layers": [L("noise", 3000, 300, 0.35, 0.8, {"lp": 2500, "k": 4.0}), L("sine", 160, 50, 0.3, 0.6)], "drive": 1.5},
		"explosion_m": {"layers": [L("noise", 2500, 200, 0.6, 0.9, {"lp": 2000, "k": 3.0}), L("sine", 120, 35, 0.5, 0.8)], "drive": 2.0},
		"explosion_l": {"layers": [L("noise", 2000, 120, 1.1, 1.0, {"lp": 1600, "k": 2.2}), L("sine", 90, 28, 0.9, 0.9, {"k": 2.0})], "drive": 2.2, "echo": [0.12, 0.3, 2]},
		"ship_explode": {"layers": [L("noise", 3000, 90, 1.5, 1.0, {"lp": 2200, "k": 2.0}), L("sine", 110, 26, 1.2, 1.0, {"k": 1.8}), L("noise", 6000, 1500, 0.2, 0.6, {"lp": 7000, "k": 6.0}), L("saw", 70, 30, 0.9, 0.4, {"lp": 300, "t": 0.05, "k": 2.0}), L("noise", 1200, 300, 0.8, 0.4, {"t": 0.25, "lp": 1000, "k": 3.0})], "drive": 2.4, "echo": [0.14, 0.28, 2]},
		"hit_shield": {"layers": [L("sine", 900, 1300, 0.12, 0.35, {"vib": 50, "vd": 0.2, "k": 5.0}), L("noise", 6000, 6000, 0.06, 0.15, {"hp": 3000})]},
		"hit_hull": {"layers": [L("noise", 1800, 300, 0.18, 0.7, {"lp": 1500, "k": 5.0}), L("square", 140, 70, 0.15, 0.4, {"lp": 800})], "drive": 1.8},
		"hit_enemy": {"layers": [L("noise", 4000, 2000, 0.05, 0.35, {"lp": 6000, "k": 8.0})]},

		# --- Jugador y sistema ---
		"pickup": {"layers": [L("sine", 1300, 1300, 0.05, 0.4), L("sine", 1750, 1750, 0.08, 0.4, {"t": 0.045})]},
		"pickup_rare": {"layers": [L("sine", 1046, 1046, 0.1, 0.4), L("sine", 1318, 1318, 0.1, 0.4, {"t": 0.07}), L("sine", 1568, 1568, 0.1, 0.4, {"t": 0.14}), L("sine", 2093, 2093, 0.25, 0.4, {"t": 0.21})]},
		"boost": {"layers": [L("noise", 800, 4000, 0.35, 0.6, {"lp": 3500, "a": 0.02, "k": 3.0}), L("sine", 200, 500, 0.3, 0.3)]},
		"ability": {"layers": [L("saw", 200, 800, 0.4, 0.4, {"lp": 3000, "k": 2.0}), L("sine", 400, 1600, 0.4, 0.4, {"k": 2.0})]},
		"drone_ability": {"layers": [L("square", 800, 1600, 0.15, 0.35, {"lp": 4000}), L("square", 1200, 2400, 0.15, 0.3, {"t": 0.1, "lp": 4000})]},
		"item_use": {"layers": [L("sine", 600, 900, 0.15, 0.5), L("sine", 900, 1350, 0.15, 0.4, {"t": 0.08})]},
		"deploy": {"layers": [L("square", 300, 150, 0.12, 0.5, {"lp": 1500}), L("square", 900, 900, 0.05, 0.3, {"t": 0.15})]},
		"alert": {"layers": [L("square", 700, 700, 0.25, 0.35, {"lp": 2500, "k": 0.5}), L("square", 520, 520, 0.25, 0.35, {"t": 0.27, "lp": 2500, "k": 0.5}), L("square", 700, 700, 0.25, 0.35, {"t": 0.54, "lp": 2500, "k": 0.5})]},
		"jackpot": {"layers": [L("sine", 784, 784, 0.08, 0.45), L("sine", 1046, 1046, 0.08, 0.45, {"t": 0.06}), L("sine", 1318, 1318, 0.08, 0.45, {"t": 0.12}), L("sine", 1568, 1568, 0.08, 0.45, {"t": 0.18}), L("sine", 2093, 2093, 0.5, 0.5, {"t": 0.24, "k": 2.0}), L("tri", 1046, 2093, 0.6, 0.25, {"t": 0.24})]},
		"objective": {"layers": [L("tri", 523, 523, 0.15, 0.5), L("tri", 659, 659, 0.15, 0.5, {"t": 0.13}), L("tri", 784, 784, 0.15, 0.5, {"t": 0.26}), L("tri", 1046, 1046, 0.45, 0.5, {"t": 0.39, "k": 2.0})]},
		"warp": {"layers": [L("sine", 200, 2000, 1.0, 0.5, {"a": 0.6, "k": 0.8}), L("noise", 500, 6000, 1.0, 0.3, {"lp": 5000, "a": 0.6, "k": 0.8})]},
		"ui_click": {"layers": [L("square", 1800, 1200, 0.03, 0.25, {"lp": 6000, "k": 8.0})]},
		"ui_select": {"layers": [L("tri", 900, 1400, 0.06, 0.4, {"k": 5.0})]},
		"ui_error": {"layers": [L("square", 220, 180, 0.15, 0.35, {"lp": 1500}), L("square", 180, 150, 0.15, 0.35, {"t": 0.12, "lp": 1500})]},
		"craft": {"layers": [L("noise", 3000, 3000, 0.04, 0.4, {"lp": 5000}), L("tri", 700, 1050, 0.2, 0.4, {"t": 0.05})]},
	}
	# Los láseres y disparos modernos sustituyen a la versión clásica (más "arcade").
	base.merge(modern(), true)
	# Motor v2 (estéreo, sin aliasing): el láser suena según la munición, como en los MMO de naves.
	base.merge(ammo_set(AMMO_STYLE), true)
	# Resto de efectos rehechos en el mismo estilo (A: pulso con cuerpo, golpe grave y estéreo).
	base.merge(fx_v2(), true)
	# Los láseres por modelo (laser_l01…l18) ya no se usan: el sonido lo marca la munición.
	for k in base.keys():
		if k.begins_with("laser_l"):
			base.erase(k)
	return base


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	if OS.get_cmdline_user_args().has("--preview"):
		# Los tres estilos de láser por munición, para escucharlos y elegir (build/sfx_preview/<estilo>/).
		for style in ["pew", "beam", "plasma"]:
			var dir := "res://build/sfx_preview/%s/" % style
			DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
			var set := ammo_set(style)
			for name in set.keys():
				var st := render_v2(set[name])
				save_wav_stereo(dir + name + ".wav", st[0], st[1])
		print("Vista previa generada")
		quit()
		return
	var all := sounds()
	var only := OS.get_cmdline_user_args()
	for name in all.keys():
		if not only.is_empty() and not only.has(name):
			continue
		if all[name].get("v2", false):
			var st := render_v2(all[name])
			save_wav_stereo(OUT_DIR + name + ".wav", st[0], st[1])
		else:
			var samples := render(all[name])
			save_wav(OUT_DIR + name + ".wav", samples)
	print("SFX generados: %d" % all.size())
	quit()


func render(spec: Dictionary) -> PackedFloat32Array:
	var total := 0.0
	for l in spec["layers"]:
		total = maxf(total, l["t"] + l["d"])
	var echo: Array = spec.get("echo", [0.0, 0.0, 0])
	total += echo[0] * echo[2] + 0.02 + (0.3 if spec.get("rev", 0.0) > 0.0 else 0.0)
	var n := int(total * SR)
	var buf := PackedFloat32Array()
	buf.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(spec))
	for l in spec["layers"]:
		_render_layer(buf, l, rng)
	var drive: float = spec.get("drive", 1.0)
	if drive > 1.0:
		for i in n:
			buf[i] = tanh(buf[i] * drive) / tanh(drive)
	if echo[2] > 0:
		var dly := int(echo[0] * SR)
		for r in echo[2]:
			for i in range(n - 1, dly - 1, -1):
				buf[i] += buf[i - dly] * echo[1]
	var rev: float = spec.get("rev", 0.0)
	if rev > 0.0:
		_reverb(buf, rev)
	var peak := 0.0001
	for i in n:
		peak = maxf(peak, absf(buf[i]))
	var g := 0.89 / peak
	var fade := int(0.006 * SR)
	for i in n:
		var f := 1.0
		if i > n - fade:
			f = float(n - i) / fade
		buf[i] *= g * f
	return buf


func _render_layer(buf: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(l["t"] * SR)
	var len := int(l["d"] * SR)
	var phase := 0.0
	var lp_state := 0.0
	var hp_state := 0.0
	var hp_prev := 0.0
	var noise_val := 0.0
	var noise_phase := 0.0
	var f0: float = l["f0"]
	var f1: float = l["f1"]
	var vib: float = l.get("vib", 0.0)
	var vd: float = l.get("vd", 0.0)
	var a: float = l["a"]
	var k: float = l["k"]
	var lp: float = l.get("lp", 0.0)
	var hp: float = l.get("hp", 0.0)
	var ratio: float = l.get("ratio", 1.0)
	var index: float = l.get("index", 0.0)
	var ik: float = l.get("ik", 4.0)
	var mod_phase := 0.0
	for j in len:
		var i := start + j
		if i >= buf.size():
			break
		var u := float(j) / len
		var t := float(j) / SR
		var freq := f0 * pow(f1 / f0, u)
		if vib > 0.0:
			freq *= 1.0 + vd * sin(TAU * vib * t)
		phase = fposmod(phase + freq / SR, 1.0)
		var s := 0.0
		match l["w"]:
			"sine":
				s = sin(TAU * phase)
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"saw":
				s = 2.0 * phase - 1.0
			"tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
			"fm":
				# FM de 2 operadores: timbre metálico/energético moderno; el índice decae con el tiempo.
				mod_phase = fposmod(mod_phase + freq * ratio / SR, 1.0)
				s = sin(TAU * phase + index * exp(-ik * u) * sin(TAU * mod_phase))
			"noise":
				# Ruido "con tono": se re-muestrea a la frecuencia indicada.
				noise_phase += freq / SR
				if noise_phase >= 1.0:
					noise_phase -= floorf(noise_phase)
					noise_val = rng.randf_range(-1.0, 1.0)
				s = noise_val
		if lp > 0.0:
			var alpha := clampf(TAU * lp / SR, 0.0, 1.0)
			lp_state += alpha * (s - lp_state)
			s = lp_state
		if hp > 0.0:
			var rc := 1.0 / (TAU * hp)
			var ah := rc / (rc + 1.0 / SR)
			hp_state = ah * (hp_state + s - hp_prev)
			hp_prev = s
			s = hp_state
		var env := 1.0
		if t < a:
			env = t / a
		else:
			env = exp(-k * (u - a / l["d"]))
			env *= clampf((1.0 - u) * 20.0, 0.0, 1.0)
		buf[i] += s * env * l["v"]


func save_wav(path: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = false
	w.data = data
	w.save_to_wav(ProjectSettings.globalize_path(path))


# --- Diseño "moderno" (inspirado en shooters MMO actuales, no en 8 bits) ---------------------
## Disparo láser por capas: transitorio de ruido (pegada) + cuerpo FM con barrido + brillo armónico
## + golpe grave + soplo de aire filtrado. Se completa con saturación suave y reverb corta.
func zap(f0: float, f1: float, d: float, ratio: float, index: float, o: Dictionary = {}) -> Array:
	var t: float = o.get("t", 0.0)
	var v: float = o.get("v", 1.0)
	var layers := [
		L("noise", 9000, 3500, 0.03, 0.5 * v, {"t": t, "hp": 2500, "k": 16.0, "a": 0.001}),
		L("fm", f0, f1, d, 0.75 * v, {"t": t, "ratio": ratio, "index": index, "ik": o.get("ik", 5.0), "k": o.get("k", 4.5), "lp": o.get("lp", 9000.0), "a": 0.002, "vib": o.get("vib", 0.0), "vd": o.get("vd", 0.0)}),
		L("sine", f0 * 2.0, f1 * 1.5, d * 0.5, 0.16 * v, {"t": t, "k": 6.0}),
		L("noise", 5200, 900, d * 0.9, o.get("air", 0.22) * v, {"t": t, "lp": 4500, "k": 4.0, "a": 0.004}),
	]
	if o.get("sub", 0.45) > 0.0:
		layers.append(L("sine", o.get("sub_f", 150.0), 42, minf(0.2, d), o.get("sub", 0.45) * v, {"t": t, "k": 7.0}))
	return layers


func modern() -> Dictionary:
	var m := {
		"laser_l01": {"layers": zap(1500, 220, 0.20, 1.5, 3.0)},
		"laser_l02": {"layers": zap(1750, 320, 0.14, 2.0, 2.5, {"v": 0.85}) + zap(1650, 300, 0.14, 2.0, 2.5, {"t": 0.055, "v": 0.85, "sub": 0.0})},
		"laser_l03": {"layers": zap(3300, 1500, 0.14, 3.0, 1.5, {"sub": 0.15, "air": 0.3})},
		"laser_l04": {"layers": zap(1150, 260, 0.15, 1.0, 4.0, {"k": 6.0})},
		"laser_l05": {"layers": zap(950, 180, 0.30, 0.5, 6.0, {"vib": 42.0, "vd": 0.06, "lp": 6000.0})},
		"laser_l06": {"layers": zap(720, 130, 0.30, 1.41, 5.0, {"lp": 5000.0}) + [L("noise", 2200, 700, 0.35, 0.3, {"lp": 2000, "vib": 30, "vd": 0.8, "k": 2.5})]},
		"laser_l07": {"layers": zap(2600, 2000, 0.26, 2.76, 2.0, {"vib": 9.0, "vd": 0.02, "k": 3.0, "sub": 0.2})},
		"laser_l08": {"layers": zap(1300, 200, 0.22, 1.0, 3.0) + [L("noise", 6000, 900, 0.18, 0.55, {"lp": 5000, "k": 6.0})]},
		"laser_l09": {"layers": zap(1800, 600, 0.32, 7.0, 8.0, {"lp": 7000.0}) + [L("noise", 4500, 2000, 0.3, 0.3, {"lp": 6000, "vib": 55, "vd": 0.9, "k": 3.0})]},
		"laser_l10": {"layers": zap(620, 60, 0.55, 0.5, 6.0, {"sub": 0.9, "sub_f": 120.0, "k": 2.8, "lp": 4000.0}), "drive": 1.6},
		"laser_l11": {"layers": zap(1200, 3000, 0.18, 1.5, 3.0, {"sub": 0.2})},
		"laser_l12": {"layers": zap(880, 700, 0.36, 2.0, 2.0, {"k": 2.2, "ik": 2.0})},
		"laser_l13": {"layers": zap(2100, 90, 0.65, 1.0, 7.0, {"sub": 0.8, "k": 2.2, "air": 0.35}), "drive": 1.5},
		"laser_l14": {"layers": zap(420, 300, 0.28, 0.25, 3.0, {"lp": 3000.0})},
		"laser_l15": {"layers": zap(320, 40, 0.6, 0.5, 8.0, {"sub": 0.9, "k": 2.0}) + [L("noise", 300, 3000, 0.55, 0.3, {"lp": 2500, "a": 0.25, "k": 1.2})]},
		"laser_l16": {"layers": zap(1600, 500, 0.15, 3.5, 3.0), "echo": [0.085, 0.45, 3]},
		"laser_l17": {"layers": zap(1400, 260, 0.2, 1.5, 3.0, {"v": 0.7}) + zap(1750, 330, 0.2, 1.5, 3.0, {"t": 0.03, "v": 0.6, "sub": 0.0}) + zap(2100, 400, 0.2, 1.5, 3.0, {"t": 0.06, "v": 0.5, "sub": 0.0})},
		"laser_l18": {"layers": zap(900, 50, 0.6, 0.7, 9.0, {"sub": 0.9, "k": 2.4}), "drive": 2.2},
		"laser_drone": {"layers": zap(2400, 1200, 0.09, 2.0, 1.5, {"sub": 0.0, "air": 0.12, "v": 0.7})},
		# Disparos alienígenas: más oscuros y graves que los del jugador para distinguirlos.
		"e_shot_light": {"layers": zap(780, 190, 0.17, 1.41, 3.0, {"v": 0.8, "sub": 0.3})},
		"e_shot_swarm": {"layers": zap(1500, 900, 0.09, 2.0, 2.0, {"v": 0.7, "sub": 0.0})},
		"e_shot_bio": {"layers": zap(420, 260, 0.2, 0.5, 4.0, {"vib": 18.0, "vd": 0.12, "lp": 3000.0, "v": 0.85})},
		"e_shot_crystal": {"layers": zap(3000, 2500, 0.13, 2.76, 2.0, {"sub": 0.1, "v": 0.75})},
		"e_shot_void": {"layers": zap(500, 110, 0.22, 0.5, 5.0, {"lp": 2500.0, "vib": 7.0, "vd": 0.05})},
		"e_heavy": {"layers": zap(420, 60, 0.36, 0.7, 6.0, {"sub": 0.8, "lp": 3000.0}), "drive": 1.5},
		"e_snipe_fire": {"layers": zap(2600, 300, 0.32, 3.0, 6.0, {"sub": 0.7, "air": 0.4}), "drive": 1.4},
	}
	# Reverb corta para todo lo moderno (sensación de espacio, no de chip de 8 bits).
	for k in m.keys():
		m[k]["rev"] = 0.22
	return m


## Reverb tipo Schroeder (4 peines + 2 pasa-todo), cola corta. `off` desplaza los retardos (canal derecho).
func _reverb(buf: PackedFloat32Array, wet: float, off: int = 0) -> void:
	var n := buf.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [1116, 1188, 1277, 1356]:
		var delay: int = (d + off) * SR / 44100
		var line := PackedFloat32Array()
		line.resize(delay)
		var idx := 0
		for i in n:
			var y := line[idx]
			line[idx] = buf[i] + y * 0.72
			out[i] += y
			idx = (idx + 1) % delay
	for d in [556, 441]:
		var delay: int = (d + off / 3) * SR / 44100
		var line := PackedFloat32Array()
		line.resize(delay)
		var idx := 0
		for i in n:
			var x := out[i]
			var y := line[idx]
			line[idx] = x + y * 0.5
			out[i] = y - x * 0.5
			idx = (idx + 1) % delay
	for i in n:
		buf[i] = buf[i] * (1.0 - wet * 0.4) + out[i] * wet * 0.22



# --- Motor v2: sonido moderno ----------------------------------------------------------------------
# Osciladores sin aliasing (polyBLEP), unísono de varias voces desafinadas repartidas en estéreo,
# filtro resonante de estado variable con barrido, caída exponencial del tono ("pew") y reverb estéreo.
# Capa: {w: saw|square|sine|tri|noise, f0, f1, pr: velocidad de caída del tono (0 = barrido normal),
#   d, t, v, a: ataque, k: caída, voices, det: desafinado en cents, pan, spread: apertura estéreo,
#   cut0→cut1 con cr: velocidad del barrido del filtro, q: resonancia 0-0.95, mode: lp|bp|hp, vib, vd}

func _blep(t: float, dt: float) -> float:
	if t < dt:
		t /= dt
		return t + t - t * t - 1.0
	elif t > 1.0 - dt:
		t = (t - 1.0) / dt
		return t * t + t + t + 1.0
	return 0.0


func V(w: String, f0: float, f1: float, d: float, v: float, extra: Dictionary = {}) -> Dictionary:
	var l := {"w": w, "f0": f0, "f1": f1, "d": d, "v": v, "t": 0.0, "a": 0.002, "k": 5.0, "pr": 0.0,
		"voices": 1, "det": 0.0, "pan": 0.0, "spread": 0.0, "cut0": 0.0, "cut1": 0.0, "cr": 0.0, "q": 0.0, "mode": "lp"}
	l.merge(extra, true)
	return l


func render_v2(spec: Dictionary) -> Array:
	var total := 0.0
	for l in spec["layers"]:
		total = maxf(total, float(l["t"]) + float(l["d"]))
	total += float(spec.get("tail", 0.35))
	var n := int(total * SR)
	var bl := PackedFloat32Array()
	bl.resize(n)
	var br := PackedFloat32Array()
	br.resize(n)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(str(spec))
	for l in spec["layers"]:
		_layer_v2(bl, br, l, rng)
	var drive: float = spec.get("drive", 1.0)
	if drive > 1.0:
		for i in n:
			bl[i] = tanh(bl[i] * drive) / tanh(drive)
			br[i] = tanh(br[i] * drive) / tanh(drive)
	var rev: float = spec.get("rev", 0.0)
	if rev > 0.0:
		_reverb(bl, rev, 0)
		_reverb(br, rev, 37)
	# Volumen percibido igualado: RMS de los primeros 0,25 s a un objetivo común y limitador suave
	# (si sólo se normaliza al pico, un chasquido muy afilado deja el resto del sonido flojo).
	var m := mini(n, int(0.25 * SR))
	var acc := 0.0
	for i in m:
		acc += bl[i] * bl[i] + br[i] * br[i]
	var rms := sqrt(acc / maxf(1.0, 2.0 * m))
	var g := minf(float(spec.get("loud", 0.16)) / maxf(rms, 0.0001), 40.0)
	var fade := int(0.01 * SR)
	for i in n:
		var f := 1.0 if i <= n - fade else float(n - i) / fade
		bl[i] = tanh(bl[i] * g) * 0.92 * f
		br[i] = tanh(br[i] * g) * 0.92 * f
	return [bl, br]


func _layer_v2(bl: PackedFloat32Array, br: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	if l["w"] == "chirp":
		_chirp_v2(bl, br, l, rng)
		return
	var start := int(float(l["t"]) * SR)
	var d: float = l["d"]
	var len := int(d * SR)
	var nv: int = maxi(1, int(l["voices"]))
	var phases: Array = []
	var gains_l: Array = []
	var gains_r: Array = []
	var dets: Array = []
	for vi in nv:
		var x := 0.0 if nv == 1 else float(vi) / (nv - 1) * 2.0 - 1.0
		phases.append(rng.randf())
		dets.append(pow(2.0, float(l["det"]) * x / 1200.0))
		var pan := clampf(float(l["pan"]) + float(l["spread"]) * x, -1.0, 1.0)
		gains_l.append(cos((pan + 1.0) * PI / 4.0) / sqrt(nv))
		gains_r.append(sin((pan + 1.0) * PI / 4.0) / sqrt(nv))
	# Filtro de estado variable (Chamberlin) con sobremuestreo x2, uno por canal.
	var low := [0.0, 0.0]
	var band := [0.0, 0.0]
	var damp := 2.0 - 1.9 * clampf(float(l["q"]), 0.0, 0.95)
	var f0: float = l["f0"]
	var f1: float = l["f1"]
	var pr: float = l["pr"]
	var a: float = l["a"]
	var k: float = l["k"]
	var vib: float = l.get("vib", 0.0)
	var vd: float = l.get("vd", 0.0)
	var cut0: float = l["cut0"]
	var cut1: float = l["cut1"] if float(l["cut1"]) > 0.0 else cut0
	var cr: float = l["cr"]
	var mode: String = l["mode"]
	for j in len:
		var i := start + j
		if i >= bl.size():
			break
		var t := float(j) / SR
		var u := float(j) / len
		var freq := f1 + (f0 - f1) * exp(-pr * t) if pr > 0.0 else f0 * pow(f1 / f0, u)
		if vib > 0.0:
			freq *= 1.0 + vd * sin(TAU * vib * t)
		var sl := 0.0
		var sr := 0.0
		for vi in nv:
			var s := 0.0
			if l["w"] == "noise":
				s = rng.randf_range(-1.0, 1.0)
			else:
				var fv: float = freq * dets[vi]
				var dt := fv / SR
				var ph: float = fposmod(phases[vi] + dt, 1.0)
				phases[vi] = ph
				match l["w"]:
					"fm":
						# FM con crepitación: el modulador lleva ruido, el índice decae (timbre de plasma).
						var mph: float = fposmod(float(l.get("_m%d" % vi, 0.0)) + fv * float(l.get("ratio", 1.0)) / SR, 1.0)
						l["_m%d" % vi] = mph
						var idx: float = float(l.get("index", 3.0)) * exp(-float(l.get("ik", 6.0)) * u)
						s = sin(TAU * ph + idx * (sin(TAU * mph) + float(l.get("crk", 0.0)) * rng.randf_range(-1.0, 1.0)))
					"saw":
						s = 2.0 * ph - 1.0 - _blep(ph, dt)
					"square":
						s = (1.0 if ph < 0.5 else -1.0) + _blep(ph, dt) - _blep(fposmod(ph + 0.5, 1.0), dt)
					"tri":
						s = 4.0 * absf(ph - 0.5) - 1.0
					_:
						s = sin(TAU * ph)
			sl += s * gains_l[vi]
			sr += s * gains_r[vi]
		if cut0 > 0.0:
			var fc := cut1 + (cut0 - cut1) * exp(-cr * t) if cr > 0.0 else cut0
			var fcoef := 2.0 * sin(PI * minf(fc, SR * 0.2) / (SR * 2.0))
			var io := [sl, sr]
			for c in 2:
				var high := 0.0
				for _o in 2:
					low[c] += fcoef * band[c]
					high = io[c] - low[c] - damp * band[c]
					band[c] += fcoef * high
				io[c] = low[c] if mode == "lp" else (band[c] if mode == "bp" else high)
			sl = io[0]
			sr = io[1]
		var env := t / a if t < a else exp(-k * (t - a) / d)
		env *= clampf((1.0 - u) * 12.0, 0.0, 1.0)
		var vol: float = float(l["v"]) * env
		bl[i] += sl * vol
		br[i] += sr * vol


## Dispersión de fase: un chasquido atraviesa una cadena de pasa-todos y sale convertido en un barrido
## metálico descendente ("piu" de disparo de energía). stages = longitud del barrido, ap = coeficiente
## (más alto, más grave y largo); cada canal con un coeficiente algo distinto para abrir el estéreo.
func _chirp_v2(bl: PackedFloat32Array, br: PackedFloat32Array, l: Dictionary, rng: RandomNumberGenerator) -> void:
	var start := int(float(l["t"]) * SR)
	var n := int(float(l["d"]) * SR)
	var stages: int = int(l.get("stages", 120))
	var ap: float = l.get("ap", 0.7)
	var burst := int(float(l.get("burst", 0.0006)) * SR) + 1
	for c in 2:
		var x := PackedFloat32Array()
		x.resize(n)
		for i in burst:
			x[i] = rng.randf_range(-1.0, 1.0) if burst > 2 else 1.0
		var coef := ap + (0.012 if c == 1 else -0.012) * float(l.get("width", 1.0))
		for _st in stages:
			var x1 := 0.0
			var y1 := 0.0
			for i in n:
				var xi := x[i]
				var y := coef * xi + x1 - coef * y1
				x1 = xi
				y1 = y
				x[i] = y
		var buf := bl if c == 0 else br
		var k: float = l.get("k", 3.0)
		for i in n:
			var u := float(i) / n
			var j := start + i
			if j >= buf.size():
				break
			buf[j] += x[i] * float(l["v"]) * exp(-k * u) * clampf((1.0 - u) * 12.0, 0.0, 1.0)


func save_wav_stereo(path: String, bl: PackedFloat32Array, br: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(bl.size() * 4)
	for i in bl.size():
		data.encode_s16(i * 4, int(clampf(bl[i], -1.0, 1.0) * 32767.0))
		data.encode_s16(i * 4 + 2, int(clampf(br[i], -1.0, 1.0) * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = SR
	w.stereo = true
	w.data = data
	w.save_to_wav(ProjectSettings.globalize_path(path))


## Disparo de energía por capas: chasquido inicial, núcleo de sierras desafinadas con el tono cayendo
## y el filtro cerrándose, golpe grave y cola de aire. `n` = munición 1-6: cada una más grave y pesada.
func pew(f0: float, f1: float, d: float, o: Dictionary = {}) -> Array:
	var t: float = o.get("t", 0.0)
	var v: float = o.get("v", 1.0)
	var layers := [
		V("noise", 0, 0, 0.025, 0.35 * v, {"t": t, "cut0": 7000, "mode": "bp", "q": 0.3, "k": 9.0, "a": 0.0008}),
		V(o.get("w", "saw"), f0, f1, d, 0.8 * v, {"t": t, "pr": o.get("pr", 24.0), "voices": o.get("voices", 3), "det": o.get("det", 14.0), "spread": 0.6,
			"cut0": o.get("cut0", 9000.0), "cut1": o.get("cut1", 1500.0), "cr": o.get("cr", 16.0), "q": o.get("q", 0.45), "k": o.get("k", 4.5)}),
		V("noise", 0, 0, d * 1.3, o.get("air", 0.12) * v, {"t": t, "cut0": 5000, "cut1": 600, "cr": 10.0, "spread": 0.0, "k": 3.5, "a": 0.004}),
	]
	if o.get("sub", 0.3) > 0.0:
		layers.append(V("sine", o.get("sub_f", 150.0), 42, minf(0.22, d), o.get("sub", 0.3) * v, {"t": t, "pr": 30.0, "k": 6.0}))
	if o.get("shine", 0.0) > 0.0:
		layers.append(V("sine", o.get("shine_f", 5200.0), o.get("shine_f", 5200.0) * 0.72, d * 0.8, o.get("shine", 0.0) * v, {"t": t, "pr": 12.0, "vib": 34.0, "vd": 0.02, "voices": 2, "det": 8.0, "spread": 0.9, "k": 4.0}))
	return layers


## Disparo de energía v3: barrido por dispersión de fase (el "piu"), cuerpo FM con crepitación,
## chasquido estéreo inmediato y un grave discreto (no un bombo). Más etapas y FM más grave = más pesado.
func beam(o: Dictionary) -> Array:
	var t: float = o.get("t", 0.0)
	var v: float = o.get("v", 1.0)
	var d: float = o.get("d", 0.22)
	var layers := [
		V("noise", 0, 0, 0.012, 0.5 * v, {"t": t, "cut0": 6500, "mode": "hp", "k": 10.0, "a": 0.0003, "voices": 2, "spread": 0.9}),
		{"w": "chirp", "t": t, "d": d * 1.4, "v": 3.2 * v * o.get("chirp", 1.0), "stages": o.get("stages", 110), "ap": o.get("ap", 0.72), "k": o.get("ck", 2.6), "width": 1.0},
		V("fm", o.get("f0", 900.0), o.get("f1", 220.0), d, 0.42 * v * o.get("body", 1.0), {"t": t, "pr": o.get("pr", 20.0), "ratio": o.get("ratio", 1.5), "index": o.get("index", 3.0),
			"ik": 5.0, "crk": o.get("crk", 0.25), "voices": 3, "det": 9.0, "spread": 0.7, "cut0": 7000, "cut1": 1200, "cr": 14.0, "q": 0.15, "k": 4.5}),
	]
	if o.get("sub", 0.12) > 0.0:
		layers.append(V("sine", 110, 55, 0.08, o.get("sub", 0.12) * v, {"t": t, "pr": 25.0, "k": 6.0}))
	if o.get("shine", 0.0) > 0.0:
		layers.append(V("fm", 4200, 3000, d * 0.7, o.get("shine", 0.0) * v, {"t": t, "pr": 10.0, "ratio": 3.5, "index": 1.2, "ik": 3.0, "voices": 2, "det": 7.0, "spread": 1.0, "k": 4.0}))
	return layers


## Disparo de energía v4: núcleo denso de sierras saturadas en los medios (400-1500 Hz) con zumbido
## sostenido y un descenso suave, crepitación FM por encima, un toque de dispersión (no un muelle) y
## chasquido estéreo. Más voces, más grave y más saturación = munición más pesada.
func plasma(o: Dictionary) -> Array:
	var t: float = o.get("t", 0.0)
	var v: float = o.get("v", 1.0)
	var d: float = o.get("d", 0.2)
	var f0: float = o.get("f0", 1100.0)
	var f1: float = o.get("f1", 600.0)
	var layers := [
		V("noise", 0, 0, 0.01, 0.45 * v, {"t": t, "cut0": 7000, "mode": "hp", "k": 10.0, "a": 0.0003, "voices": 2, "spread": 0.9}),
		V("saw", f0, f1, d, 0.8 * v, {"t": t, "pr": o.get("pr", 9.0), "voices": o.get("voices", 5), "det": o.get("det", 16.0), "spread": 0.7,
			"cut0": o.get("cut0", 6000.0), "cut1": o.get("cut1", 1600.0), "cr": 9.0, "q": 0.2, "k": o.get("k", 3.6), "a": 0.003}),
		V("fm", f0 * 2.0, f1 * 2.2, d * 0.85, o.get("sizzle", 0.28) * v, {"t": t, "pr": 7.0, "ratio": o.get("ratio", 1.41), "index": o.get("index", 3.5),
			"ik": 3.0, "crk": o.get("crk", 0.4), "voices": 2, "det": 10.0, "spread": 1.0, "cut0": 9000, "q": 0.0, "k": 4.0}),
		{"w": "chirp", "t": t, "d": d, "v": o.get("chirp", 0.9) * v, "stages": o.get("stages", 60), "ap": o.get("ap", 0.6), "k": 5.0, "width": 1.0},
	]
	if o.get("sub", 0.1) > 0.0:
		layers.append(V("sine", f1 * 0.25, f1 * 0.15, 0.1, o.get("sub", 0.1) * v, {"t": t, "pr": 20.0, "k": 5.0}))
	return layers


func ammo_set(style: String) -> Dictionary:
	var m: Dictionary = {"pew": ammo_pew(), "beam": ammo_beam()}.get(style, ammo_plasma())
	for k in m.keys():
		m[k]["v2"] = true
	return m


## Estilo A (iteración 2): pulso de sierras con caída de tono, chasquido y golpe grave.
func ammo_pew() -> Dictionary:
	var crack := V("noise", 0, 0, 0.05, 0.4, {"cut0": 4500, "mode": "hp", "k": 7.0, "a": 0.0008})
	return {
		"laser_mk1": {"layers": pew(1600, 320, 0.18, {"voices": 2, "det": 10.0, "q": 0.3, "cut0": 6000.0, "cut1": 1400.0, "sub": 0.22}) + [crack], "drive": 1.3, "rev": 0.15, "tail": 0.25},
		"laser_mk2": {"layers": pew(1500, 260, 0.22, {"q": 0.22, "sub": 0.32, "air": 0.14}) + [V("saw", 750, 130, 0.2, 0.35, {"pr": 20.0, "voices": 3, "det": 12.0, "spread": 0.5, "cut0": 3000, "cut1": 700, "cr": 14.0, "q": 0.15})], "drive": 1.2, "rev": 0.18, "tail": 0.28},
		"laser_mk3": {"layers": pew(2400, 520, 0.2, {"w": "square", "q": 0.5, "cut0": 8000.0, "cut1": 500.0, "cr": 22.0, "sub": 0.3, "shine": 0.16}) + [crack], "rev": 0.2, "tail": 0.28},
		"laser_mk4": {"layers": pew(1300, 200, 0.26, {"voices": 4, "det": 18.0, "q": 0.4, "sub": 0.5, "sub_f": 140.0}) + pew(1200, 190, 0.18, {"t": 0.045, "v": 0.4, "sub": 0.0}), "drive": 1.3, "rev": 0.2, "tail": 0.22},
		"laser_mk5": {"layers": pew(1000, 120, 0.28, {"voices": 4, "det": 26.0, "q": 0.45, "sub": 0.6, "air": 0.26}) + [V("noise", 0, 0, 0.26, 0.22, {"cut0": 3200, "mode": "bp", "q": 0.45, "vib": 45.0, "vd": 0.9, "k": 4.0}), crack], "drive": 1.7, "rev": 0.2, "tail": 0.22},
		"laser_mk6": {"layers": pew(950, 95, 0.32, {"voices": 5, "det": 26.0, "q": 0.5, "sub": 0.85, "sub_f": 125.0, "shine": 0.2, "air": 0.22, "pr": 16.0, "k": 5.5}) + pew(900, 90, 0.22, {"t": 0.06, "v": 0.45, "sub": 0.35, "voices": 3, "k": 6.0}) + [crack], "drive": 1.6, "rev": 0.22, "tail": 0.25},
	}


## Estilo B (iteración 3): dispersión de fase ("piu" metálico), FM crepitante y grave discreto.
func ammo_beam() -> Dictionary:
	return {
		"laser_mk1": {"layers": beam({"d": 0.15, "stages": 70, "ap": 0.6, "f0": 1500.0, "f1": 420.0, "index": 2.0, "crk": 0.1, "sub": 0.05}), "rev": 0.14, "tail": 0.2},
		"laser_mk2": {"layers": beam({"d": 0.18, "stages": 95, "ap": 0.66, "f0": 1200.0, "f1": 320.0, "index": 2.6, "crk": 0.18, "sub": 0.1}), "rev": 0.16, "tail": 0.22},
		"laser_mk3": {"layers": beam({"d": 0.2, "stages": 110, "ap": 0.7, "f0": 1600.0, "f1": 600.0, "ratio": 2.76, "index": 4.0, "crk": 0.35, "shine": 0.12, "sub": 0.1}), "rev": 0.18, "tail": 0.24},
		"laser_mk4": {"layers": beam({"d": 0.24, "stages": 140, "ap": 0.75, "f0": 800.0, "f1": 190.0, "index": 4.5, "crk": 0.3, "sub": 0.18}) + beam({"t": 0.04, "v": 0.45, "d": 0.18, "stages": 120, "ap": 0.73, "f0": 760.0, "f1": 180.0, "sub": 0.0}), "drive": 1.25, "rev": 0.2, "tail": 0.24},
		"laser_mk5": {"layers": beam({"d": 0.26, "stages": 165, "ap": 0.78, "f0": 640.0, "f1": 140.0, "ratio": 0.5, "index": 6.0, "crk": 0.6, "sub": 0.22, "body": 1.15}), "drive": 1.5, "rev": 0.2, "tail": 0.24},
		"laser_mk6": {"layers": beam({"d": 0.3, "stages": 190, "ap": 0.8, "f0": 560.0, "f1": 110.0, "ratio": 0.5, "index": 7.0, "crk": 0.45, "shine": 0.14, "sub": 0.28, "body": 1.2}) + beam({"t": 0.055, "v": 0.5, "d": 0.22, "stages": 170, "ap": 0.79, "f0": 520.0, "f1": 105.0, "index": 6.0, "sub": 0.0}), "drive": 1.4, "rev": 0.22, "tail": 0.26},
	}


## Estilo C (iteración 4): núcleo denso de sierras saturadas con zumbido, crepitación FM y algo de dispersión.
func ammo_plasma() -> Dictionary:
	var m := {
		# Mk-I: pulso corto y nítido.
		"laser_mk1": {"layers": plasma({"d": 0.14, "f0": 1500.0, "f1": 900.0, "voices": 3, "det": 10.0, "sizzle": 0.18, "chirp": 0.6, "stages": 40, "sub": 0.0}), "drive": 1.3, "rev": 0.12, "tail": 0.18},
		# Mk-II: más denso.
		"laser_mk2": {"layers": plasma({"d": 0.17, "f0": 1250.0, "f1": 720.0, "voices": 4, "det": 13.0, "sizzle": 0.22, "chirp": 0.7, "stages": 50, "sub": 0.06}), "drive": 1.4, "rev": 0.14, "tail": 0.2},
		# Mk-III: eléctrico, con crepitación marcada.
		"laser_mk3": {"layers": plasma({"d": 0.19, "f0": 1400.0, "f1": 820.0, "voices": 4, "det": 14.0, "ratio": 2.76, "index": 5.0, "crk": 0.8, "sizzle": 0.4, "chirp": 0.8, "stages": 55, "sub": 0.06}), "drive": 1.4, "rev": 0.16, "tail": 0.22},
		# Mk-IV: pesado, con segundo pulso.
		"laser_mk4": {"layers": plasma({"d": 0.22, "f0": 950.0, "f1": 520.0, "voices": 5, "det": 18.0, "sizzle": 0.28, "sub": 0.12, "stages": 70, "ap": 0.65}) + plasma({"t": 0.045, "v": 0.45, "d": 0.16, "f0": 900.0, "f1": 500.0, "voices": 3, "sub": 0.0, "chirp": 0.0}), "drive": 1.6, "rev": 0.18, "tail": 0.22},
		# Mk-V: plasma grueso y saturado.
		"laser_mk5": {"layers": plasma({"d": 0.25, "f0": 780.0, "f1": 420.0, "voices": 6, "det": 22.0, "ratio": 0.5, "index": 6.0, "crk": 0.7, "sizzle": 0.35, "sub": 0.16, "stages": 80, "ap": 0.68, "cut0": 5000.0, "cut1": 1300.0}), "drive": 2.0, "rev": 0.18, "tail": 0.22},
		# Mk-VI: el más masivo: núcleo ancho, doble impacto y cola corta.
		"laser_mk6": {"layers": plasma({"d": 0.28, "f0": 660.0, "f1": 360.0, "voices": 7, "det": 26.0, "ratio": 0.5, "index": 7.0, "crk": 0.6, "sizzle": 0.38, "sub": 0.22, "stages": 90, "ap": 0.7, "cut0": 5200.0, "cut1": 1200.0}) + plasma({"t": 0.055, "v": 0.5, "d": 0.2, "f0": 620.0, "f1": 340.0, "voices": 5, "sub": 0.1, "chirp": 0.4}), "drive": 2.2, "rev": 0.2, "tail": 0.24},
	}
	return m



# --- Resto de efectos en estilo A ------------------------------------------------------------------
## Explosión por capas: estallido de ruido que se oscurece, retumbo grave, crepitar de restos y aire.
func boom(size: float, o: Dictionary = {}) -> Array:
	var t: float = o.get("t", 0.0)
	var d := 0.35 + 0.55 * size
	var layers := [
		V("noise", 0, 0, 0.03, 0.6, {"t": t, "cut0": 8000, "mode": "hp", "k": 9.0, "a": 0.0005, "voices": 2, "spread": 0.9}),
		V("noise", 0, 0, d, 0.9, {"t": t, "cut0": 6000 - 2500 * size, "cut1": 260, "cr": 6.0 - 3.0 * size, "q": 0.15, "k": 3.2 - size, "a": 0.002, "voices": 2, "spread": 0.8}),
		V("sine", 120 - 40 * size, 32, d * 0.8, 0.55 + 0.35 * size, {"t": t, "pr": 9.0, "k": 3.0}),
		# Expansión: soplo grave que se abre y se apaga.
		V("noise", 0, 0, d * 1.3, 0.3 + 0.15 * size, {"t": t + 0.03, "cut0": 300, "cut1": 1800, "cr": 5.0, "q": 0.1, "a": 0.08, "k": 2.2, "voices": 2, "spread": 1.0}),
	]
	# Restos: golpes cortos de metal repartidos en el tiempo y en el estéreo.
	for r in int(2 + 4 * size):
		var rt := t + 0.06 + 0.11 * r + 0.03 * sin(r * 7.3)
		layers.append(V("noise", 0, 0, 0.05, 0.22 + 0.08 * size, {"t": rt, "cut0": 2200 + 900 * sin(r * 3.1), "mode": "bp", "q": 0.6, "k": 7.0, "pan": 0.8 * sin(r * 2.3)}))
	if size >= 0.6:
		layers.append(V("saw", 70, 35, d, 0.25, {"t": t + 0.02, "pr": 4.0, "voices": 3, "det": 25.0, "spread": 0.6, "cut0": 400, "q": 0.2, "k": 2.4}))
	return layers


## Campanilla suave de interfaz (FM con poco índice, estéreo): reemplaza los pitidos de onda cuadrada.
func chime(f: float, t: float, d: float, v: float) -> Dictionary:
	return V("fm", f, f, d, v, {"t": t, "ratio": 2.0, "index": 1.2, "ik": 6.0, "voices": 2, "det": 6.0, "spread": 0.6, "k": 4.5, "a": 0.008})


func fx_v2() -> Dictionary:
	var m := {
		# Pet: pulso pequeño y agudo.
		"laser_drone": {"layers": pew(2400, 900, 0.1, {"voices": 2, "det": 8.0, "q": 0.25, "cut0": 7000.0, "cut1": 2500.0, "sub": 0.0, "air": 0.06, "v": 0.8}), "rev": 0.1, "tail": 0.15},
		# Disparos alienígenas: más graves y oscuros que los del jugador; cada facción con su textura.
		"e_shot_light": {"layers": pew(900, 200, 0.18, {"voices": 2, "det": 12.0, "q": 0.3, "cut0": 4500.0, "cut1": 900.0, "sub": 0.25}) + [V("saw", 450, 110, 0.16, 0.35, {"pr": 18.0, "voices": 3, "det": 16.0, "spread": 0.5, "cut0": 2200, "cut1": 600, "cr": 12.0, "k": 4.0})], "drive": 1.3, "rev": 0.14, "tail": 0.2},
		"e_shot_swarm": {"layers": pew(1500, 700, 0.09, {"voices": 2, "det": 10.0, "q": 0.2, "cut0": 6000.0, "sub": 0.0, "air": 0.05, "v": 0.8}), "rev": 0.08, "tail": 0.12},
		"e_shot_bio": {"layers": pew(520, 240, 0.2, {"w": "tri", "voices": 3, "det": 20.0, "q": 0.5, "cut0": 2500.0, "cut1": 700.0, "sub": 0.2}) + [V("noise", 0, 0, 0.18, 0.2, {"cut0": 900, "mode": "bp", "q": 0.6, "vib": 22.0, "vd": 0.7, "k": 3.0})], "rev": 0.18, "tail": 0.22},
		"e_shot_crystal": {"layers": pew(2600, 1700, 0.14, {"w": "square", "voices": 2, "det": 9.0, "q": 0.55, "cut0": 8000.0, "cut1": 3000.0, "sub": 0.0, "shine": 0.2, "shine_f": 5600.0}), "rev": 0.22, "tail": 0.25},
		"e_shot_void": {"layers": pew(600, 130, 0.24, {"voices": 3, "det": 28.0, "q": 0.6, "cut0": 2600.0, "cut1": 500.0, "sub": 0.3, "air": 0.2}), "drive": 1.4, "rev": 0.24, "tail": 0.28},
		"e_heavy": {"layers": pew(480, 70, 0.34, {"voices": 4, "det": 22.0, "q": 0.4, "cut0": 3000.0, "cut1": 500.0, "sub": 0.8, "sub_f": 120.0}) + [V("noise", 0, 0, 0.06, 0.45, {"cut0": 6000, "mode": "hp", "k": 7.0, "voices": 2, "spread": 0.9}), V("noise", 0, 0, 0.25, 0.2, {"cut0": 4500, "cut1": 1500, "cr": 8.0, "mode": "bp", "q": 0.3, "k": 4.0})], "drive": 1.6, "rev": 0.2, "tail": 0.26},
		"e_snipe_fire": {"layers": pew(3000, 260, 0.3, {"voices": 3, "det": 14.0, "q": 0.45, "sub": 0.6, "air": 0.35}) + [V("noise", 0, 0, 0.06, 0.6, {"cut0": 9000, "mode": "hp", "k": 8.0, "voices": 2, "spread": 1.0})], "drive": 1.5, "rev": 0.28, "tail": 0.35},
		# Avisos de ataque (telegraphs): subidas claras para que se oigan venir.
		"e_charge": {"layers": [V("saw", 90, 700, 0.9, 0.55, {"voices": 4, "det": 18.0, "spread": 0.7, "cut0": 500, "cut1": 4000, "cr": 3.0, "q": 0.5, "a": 0.6, "k": 0.5}), V("noise", 0, 0, 0.9, 0.15, {"cut0": 1500, "mode": "bp", "q": 0.5, "a": 0.7, "k": 0.4})], "rev": 0.15, "tail": 0.2},
		"e_snipe_charge": {"layers": [V("sine", 600, 2600, 1.3, 0.4, {"voices": 2, "det": 7.0, "spread": 0.8, "a": 1.1, "k": 0.4}), V("noise", 0, 0, 1.3, 0.12, {"cut0": 4000, "mode": "bp", "q": 0.6, "a": 1.1, "k": 0.4})], "rev": 0.2, "tail": 0.25},
		"e_arm": {"layers": [chime(1050, 0.0, 0.08, 0.5), chime(1050, 0.3, 0.08, 0.5), chime(1400, 0.6, 0.12, 0.6)], "rev": 0.12, "tail": 0.15},
		"e_launch": {"layers": [V("sine", 150, 55, 0.2, 0.8, {"pr": 14.0, "k": 4.0}), V("noise", 0, 0, 0.6, 0.35, {"t": 0.06, "cut0": 3000, "cut1": 600, "cr": 4.0, "k": 1.4, "voices": 2, "spread": 0.7})], "rev": 0.2, "tail": 0.25},
		"e_dash": {"layers": [V("noise", 0, 0, 0.45, 0.65, {"cut0": 5000, "cut1": 500, "cr": 6.0, "q": 0.3, "a": 0.03, "k": 3.0, "voices": 2, "spread": 0.9}), V("saw", 300, 120, 0.3, 0.2, {"pr": 8.0, "voices": 3, "det": 20.0, "cut0": 1500, "k": 3.0})], "rev": 0.12, "tail": 0.15},
		"e_heal": {"layers": [chime(520, 0.0, 0.2, 0.4), chime(660, 0.08, 0.2, 0.4), chime(880, 0.16, 0.3, 0.45)], "rev": 0.3, "tail": 0.35},
		"e_spawn": {"layers": [V("saw", 160, 360, 0.5, 0.45, {"voices": 3, "det": 25.0, "spread": 0.7, "vib": 8.0, "vd": 0.15, "cut0": 1200, "q": 0.4, "a": 0.08, "k": 2.0}), V("noise", 0, 0, 0.45, 0.25, {"cut0": 700, "mode": "bp", "q": 0.5, "k": 2.0})], "rev": 0.25, "tail": 0.3},
		"e_drain": {"layers": [V("saw", 140, 110, 0.7, 0.45, {"voices": 3, "det": 30.0, "spread": 0.6, "vib": 16.0, "vd": 0.18, "cut0": 900, "q": 0.5, "a": 0.1, "k": 1.5}), V("sine", 880, 440, 0.7, 0.15, {"a": 0.1, "k": 2.0})], "rev": 0.2, "tail": 0.25},
		"e_phase": {"layers": [V("noise", 0, 0, 0.45, 0.4, {"cut0": 600, "cut1": 6000, "cr": 3.0, "mode": "bp", "q": 0.6, "a": 0.3, "k": 0.8, "voices": 2, "spread": 1.0}), V("sine", 400, 1600, 0.45, 0.25, {"voices": 2, "det": 15.0, "spread": 0.9, "a": 0.3, "k": 0.8})], "rev": 0.3, "tail": 0.3},
		"e_reflect": {"layers": [chime(1700, 0.0, 0.4, 0.5), chime(2550, 0.0, 0.35, 0.3), V("noise", 0, 0, 0.05, 0.3, {"cut0": 7000, "mode": "hp", "k": 8.0})], "rev": 0.25, "tail": 0.3},
		"e_pulse": {"layers": [V("sine", 130, 55, 0.6, 0.8, {"pr": 6.0, "vib": 6.0, "vd": 0.2, "k": 2.0}), V("noise", 0, 0, 0.5, 0.35, {"cut0": 1200, "cut1": 300, "cr": 5.0, "k": 2.0, "voices": 2, "spread": 0.8})], "drive": 1.3, "rev": 0.25, "tail": 0.3},
		"e_nova": {"layers": [V("saw", 80, 900, 0.5, 0.5, {"voices": 4, "det": 20.0, "spread": 0.7, "cut0": 600, "q": 0.4, "a": 0.4, "k": 0.6})] + boom(0.6, {"t": 0.45}), "drive": 1.4, "rev": 0.25, "tail": 0.4},
		# Explosiones.
		"explosion_s": {"layers": boom(0.2), "drive": 1.3, "rev": 0.18, "tail": 0.3},
		"explosion_m": {"layers": boom(0.5), "drive": 1.5, "rev": 0.22, "tail": 0.4},
		"explosion_l": {"layers": boom(0.85), "drive": 1.7, "rev": 0.28, "tail": 0.6},
		"ship_explode": {"layers": boom(1.0) + boom(0.5, {"t": 0.22}), "drive": 1.8, "rev": 0.3, "tail": 0.7},
		# Impactos.
		"hit_shield": {"layers": [V("sine", 900, 1300, 0.14, 0.35, {"voices": 2, "det": 12.0, "spread": 0.8, "vib": 45.0, "vd": 0.15, "k": 5.0}), V("noise", 0, 0, 0.06, 0.25, {"cut0": 6000, "mode": "hp", "k": 8.0})], "rev": 0.15, "tail": 0.15},
		"hit_hull": {"layers": [V("noise", 0, 0, 0.2, 0.7, {"cut0": 2500, "cut1": 400, "cr": 14.0, "q": 0.3, "k": 5.0}), V("sine", 150, 60, 0.15, 0.6, {"pr": 20.0, "k": 5.0}), V("noise", 0, 0, 0.12, 0.3, {"cut0": 3200, "mode": "bp", "q": 0.7, "k": 6.0})], "drive": 1.5, "rev": 0.12, "tail": 0.15},
		"hit_enemy": {"layers": [V("noise", 0, 0, 0.05, 0.4, {"cut0": 5000, "mode": "bp", "q": 0.4, "k": 8.0}), V("sine", 300, 120, 0.05, 0.3, {"pr": 40.0, "k": 7.0})], "rev": 0.06, "tail": 0.08},
		# Nave y pet.
		"boost": {"layers": [V("noise", 0, 0, 0.45, 0.6, {"cut0": 800, "cut1": 5000, "cr": 3.0, "q": 0.3, "a": 0.03, "k": 2.5, "voices": 2, "spread": 0.9}), V("saw", 120, 300, 0.4, 0.3, {"voices": 3, "det": 18.0, "cut0": 2000, "a": 0.05, "k": 2.5})], "rev": 0.15, "tail": 0.2},
		"ability": {"layers": [V("saw", 200, 800, 0.45, 0.4, {"voices": 4, "det": 15.0, "spread": 0.7, "cut0": 3000, "q": 0.4, "k": 2.0}), chime(1200, 0.12, 0.35, 0.3)], "rev": 0.25, "tail": 0.3},
		"drone_ability": {"layers": [chime(900, 0.0, 0.15, 0.4), chime(1350, 0.1, 0.2, 0.4), V("noise", 0, 0, 0.2, 0.15, {"cut0": 5000, "mode": "hp", "k": 4.0})], "rev": 0.2, "tail": 0.25},
		"item_use": {"layers": [chime(600, 0.0, 0.2, 0.45), chime(900, 0.08, 0.25, 0.4)], "rev": 0.2, "tail": 0.25},
		"deploy": {"layers": [V("sine", 220, 110, 0.15, 0.6, {"pr": 15.0, "k": 5.0}), V("noise", 0, 0, 0.08, 0.35, {"cut0": 3000, "mode": "bp", "q": 0.5, "k": 7.0}), chime(900, 0.15, 0.1, 0.3)], "rev": 0.15, "tail": 0.2},
		"warp": {"tail": 0.9, "layers": [V("saw", 120, 1600, 1.0, 0.45, {"voices": 5, "det": 22.0, "spread": 0.9, "cut0": 800, "q": 0.5, "a": 0.6, "k": 0.8}), V("noise", 0, 0, 1.0, 0.3, {"cut0": 500, "cut1": 7000, "cr": 3.0, "mode": "bp", "q": 0.5, "a": 0.6, "k": 0.8, "voices": 2, "spread": 1.0}), V("noise", 0, 0, 1.2, 0.25, {"t": 0.95, "cut0": 6000, "cut1": 400, "cr": 3.0, "k": 2.0, "voices": 2, "spread": 1.0})], "rev": 0.42},
		# Botín, objetivos y alertas.
		"pickup": {"layers": [chime(1300, 0.0, 0.08, 0.4), chime(1750, 0.045, 0.12, 0.4)], "rev": 0.15, "tail": 0.15},
		"pickup_rare": {"layers": [chime(1046, 0.0, 0.4, 0.35), chime(1318, 0.06, 0.4, 0.35), chime(1568, 0.12, 0.4, 0.35), chime(2093, 0.18, 0.6, 0.4), V("noise", 0, 0, 0.5, 0.08, {"t": 0.1, "cut0": 8000, "mode": "hp", "a": 0.05, "k": 2.5})], "rev": 0.32, "tail": 0.4},
		"jackpot": {"layers": [chime(784, 0.0, 0.1, 0.45), chime(1046, 0.06, 0.1, 0.45), chime(1318, 0.12, 0.1, 0.45), chime(1568, 0.18, 0.1, 0.45), chime(2093, 0.24, 0.6, 0.5), V("noise", 0, 0, 0.6, 0.12, {"t": 0.24, "cut0": 7000, "mode": "hp", "k": 2.5})], "rev": 0.35, "tail": 0.45},
		"objective": {"layers": [chime(523, 0.0, 0.18, 0.5), chime(659, 0.13, 0.18, 0.5), chime(784, 0.26, 0.18, 0.5), chime(1046, 0.39, 0.6, 0.55), V("saw", 261, 261, 0.7, 0.18, {"t": 0.39, "voices": 3, "det": 10.0, "spread": 0.8, "cut0": 1500, "a": 0.05, "k": 2.5})], "rev": 0.3, "tail": 0.4},
		# Alerta: dos tonos suaves tipo sirena de cabina (triangulares y filtrados, sin timbre de altavoz de PC).
		"alert": {"layers": [V("tri", 700, 700, 0.28, 0.45, {"voices": 3, "det": 8.0, "spread": 0.7, "cut0": 1600, "a": 0.02, "k": 0.8}), V("tri", 525, 525, 0.28, 0.45, {"t": 0.3, "voices": 3, "det": 8.0, "spread": 0.7, "cut0": 1600, "a": 0.02, "k": 0.8}), V("tri", 700, 700, 0.28, 0.45, {"t": 0.6, "voices": 3, "det": 8.0, "spread": 0.7, "cut0": 1600, "a": 0.02, "k": 0.8}), V("sine", 175, 175, 0.9, 0.2, {"a": 0.05, "k": 1.2})], "rev": 0.22, "tail": 0.3},
		# Interfaz: suave y corta.
		"ui_click": {"layers": [V("noise", 0, 0, 0.025, 0.4, {"cut0": 4000, "mode": "bp", "q": 0.5, "k": 9.0}), chime(1800, 0.0, 0.04, 0.2)], "rev": 0.05, "tail": 0.05},
		"ui_select": {"layers": [chime(900, 0.0, 0.08, 0.4), chime(1350, 0.04, 0.1, 0.35)], "rev": 0.1, "tail": 0.12},
		"ui_error": {"layers": [V("saw", 220, 190, 0.14, 0.4, {"voices": 2, "det": 20.0, "cut0": 1300, "q": 0.3, "k": 2.0}), V("saw", 180, 150, 0.16, 0.4, {"t": 0.12, "voices": 2, "det": 20.0, "cut0": 1300, "q": 0.3, "k": 2.0})], "rev": 0.08, "tail": 0.1},
		"craft": {"layers": [V("noise", 0, 0, 0.05, 0.45, {"cut0": 3500, "mode": "bp", "q": 0.5, "k": 8.0}), V("sine", 180, 90, 0.08, 0.4, {"pr": 20.0, "k": 6.0}), chime(1050, 0.06, 0.25, 0.4)], "rev": 0.2, "tail": 0.25},
	}
	for k in m.keys():
		m[k]["v2"] = true
	return m
