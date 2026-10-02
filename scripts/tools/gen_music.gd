extends SceneTree
## Compositor procedural de bandas sonoras en bucle (una por bioma + menú) → assets/audio/music/*.wav
## Uso: godot --headless --script res://scripts/tools/gen_music.gd [-- pista]
## Secuenciador por compases: pad (acordes), bajo, arpegio, batería, drone y melodía, con reverb.
## La cola final se suma al principio para que el bucle sea perfecto.

const SR := 22050
const OUT_DIR := "res://assets/audio/music/"

const SCALES := {
	"minor": [0, 2, 3, 5, 7, 8, 10], "phrygian": [0, 1, 3, 5, 7, 8, 10], "lydian": [0, 2, 4, 6, 7, 9, 11],
	"locrian": [0, 1, 3, 5, 6, 8, 10], "dorian": [0, 2, 3, 5, 7, 9, 10],
}

# Arreglo: lista de secciones [compases, capas activas].
const TRACKS := {
	"ferron": {
		"bpm": 104, "root": 45, "scale": "minor", "prog": [0, 5, 3, 4],
		"pad": {"wave": "saw", "cut": 900.0, "vol": 0.20}, "bass": {"wave": "saw", "cut": 700.0, "vol": 0.34, "pat": [1,0,0,1, 0,0,1,0, 1,0,0,1, 0,1,0,0]},
		"arp": {"wave": "square", "vol": 0.07, "step": 1, "oct": 2, "cut": 2400.0},
		"drums": {"kick": [0, 4, 8, 12], "snare": [4, 12], "hat": [2, 6, 10, 14], "metal": true},
		"form": [[4, ["pad", "bass"]], [8, ["pad", "bass", "drums", "arp"]], [4, ["pad", "arp"]], [8, ["pad", "bass", "drums", "arp", "lead"]]],
	},
	"vesper": {
		"bpm": 84, "root": 50, "scale": "phrygian", "prog": [0, 1, 0, 6],
		"pad": {"wave": "saw", "cut": 1100.0, "vol": 0.20, "vib": 4.5, "vd": 0.012}, "bass": {"wave": "sine", "cut": 0.0, "vol": 0.40, "pat": [1,0,0,0, 0,0,0,0, 1,0,1,0, 0,0,0,0]},
		"arp": {"wave": "sine", "vol": 0.12, "step": 2, "oct": 2, "random_oct": true},
		"drums": {"kick": [0, 2, 8, 10], "snare": [], "hat": [4, 12], "soft": true},
		"form": [[4, ["pad"]], [8, ["pad", "bass", "arp", "drums"]], [4, ["pad", "arp"]], [4, ["pad", "bass", "drums", "lead"]]],
	},
	"prismaticos": {
		"bpm": 112, "root": 52, "scale": "lydian", "prog": [0, 4, 5, 3],
		"pad": {"wave": "tri", "cut": 3000.0, "vol": 0.22}, "bass": {"wave": "square", "cut": 600.0, "vol": 0.26, "pat": [1,0,0,0, 1,0,0,0, 1,0,0,0, 1,0,1,0]},
		"arp": {"wave": "bell", "vol": 0.14, "step": 1, "oct": 2},
		"drums": {"kick": [0, 8], "snare": [4, 12], "hat": [0,2,4,6,8,10,12,14], "clap": true},
		"form": [[4, ["pad", "arp"]], [8, ["pad", "bass", "arp", "drums"]], [4, ["pad", "arp"]], [8, ["pad", "bass", "arp", "drums", "lead"]]],
	},
	"vacio": {
		"bpm": 66, "root": 36, "scale": "locrian", "prog": [0, 0, 1, 4],
		"pad": {"wave": "saw", "cut": 520.0, "vol": 0.22, "vib": 0.3, "vd": 0.006}, "bass": {"wave": "sine", "cut": 0.0, "vol": 0.0, "pat": []},
		"arp": {"wave": "bell", "vol": 0.08, "step": 4, "oct": 3, "sparse": true},
		"drums": {"kick": [0], "snare": [], "hat": [], "boom": true},
		"drone": {"vol": 0.30},
		"form": [[4, ["pad", "drone"]], [4, ["pad", "drone", "arp", "drums"]], [4, ["pad", "drone", "swell"]], [4, ["pad", "drone", "arp", "drums", "swell"]]],
	},
	"leviatan": {
		"bpm": 90, "root": 43, "scale": "minor", "prog": [0, 5, 2, 6],
		"pad": {"wave": "choir", "cut": 1300.0, "vol": 0.24, "vib": 5.0, "vd": 0.006}, "bass": {"wave": "saw", "cut": 400.0, "vol": 0.30, "pat": [1,0,0,0, 0,0,0,0, 0,0,0,0, 0,0,0,0]},
		"arp": {"wave": "sine", "vol": 0.10, "step": 2, "oct": 2},
		"drums": {"kick": [0, 6, 8], "snare": [], "hat": [], "toms": [10, 14]},
		"form": [[4, ["pad", "bass"]], [8, ["pad", "bass", "drums", "arp", "glide"]], [4, ["pad", "glide"]], [4, ["pad", "bass", "drums", "arp", "lead"]]],
	},
	"menu": {
		"bpm": 92, "root": 48, "scale": "dorian", "prog": [0, 3, 6, 4],
		"pad": {"wave": "saw", "cut": 1500.0, "vol": 0.20, "vib": 3.0, "vd": 0.004}, "bass": {"wave": "sine", "cut": 0.0, "vol": 0.32, "pat": [1,0,0,0, 0,0,1,0, 0,0,0,0, 1,0,0,0]},
		"arp": {"wave": "bell", "vol": 0.10, "step": 2, "oct": 2},
		"drums": {"kick": [0, 10], "snare": [], "hat": [4, 12], "soft": true},
		"form": [[4, ["pad"]], [8, ["pad", "bass", "arp"]], [8, ["pad", "bass", "arp", "drums", "lead"]]],
	},
}

var rng := RandomNumberGenerator.new()


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var only := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		only = args[0]
	for name in TRACKS.keys():
		if only != "" and name != only:
			continue
		var t0 := Time.get_ticks_msec()
		var buf := render_track(name, TRACKS[name])
		save_wav(OUT_DIR + name + ".wav", buf)
		print("%s: %.1f s de audio en %d ms" % [name, buf.size() / float(SR), Time.get_ticks_msec() - t0])
	quit()


static func mtof(m: float) -> float:
	return 440.0 * pow(2.0, (m - 69.0) / 12.0)


func note(spec: Dictionary, deg: int, oct: int) -> float:
	var sc: Array = SCALES[spec["scale"]]
	var n := sc.size()
	var o := floori(float(deg) / n)
	var d := deg - o * n
	return spec["root"] + sc[d] + 12 * (o + oct)


func render_track(name: String, spec: Dictionary) -> PackedFloat32Array:
	rng.seed = hash(name)
	var beat: float = 60.0 / float(spec["bpm"])
	var bar: float = beat * 4.0
	var step: float = beat / 4.0
	var bars := 0
	for sec in spec["form"]:
		bars += sec[0]
	var length := int(bars * bar * SR)
	var tail := int(3.0 * SR)
	var buf := PackedFloat32Array()
	buf.resize(length + tail)
	var prog: Array = spec["prog"]
	var b := 0
	for sec in spec["form"]:
		var layers: Array = sec[1]
		for k in sec[0]:
			var t0: float = b * bar
			var deg: int = prog[b % prog.size()]
			var chord := [note(spec, deg, 0), note(spec, deg + 2, 0), note(spec, deg + 4, 0)]
			if "pad" in layers:
				_pad(buf, spec["pad"], chord, t0, bar)
			if "drone" in layers:
				_osc(buf, "sine", mtof(spec["root"] - 12), mtof(spec["root"] - 12), t0, bar, spec["drone"]["vol"], 0.01, 0.01, 0.0, 0.0, 0.0)
				_osc(buf, "sine", mtof(spec["root"] - 5), mtof(spec["root"] - 5), t0, bar, spec["drone"]["vol"] * 0.35, 0.01, 0.01, 0.2, 0.01, 0.0)
			if "bass" in layers and spec["bass"]["vol"] > 0.0:
				var pat: Array = spec["bass"]["pat"]
				for s in pat.size():
					if pat[s] == 1:
						var dur: float = step * 3.0
						var f := mtof(chord[0] - 12)
						_osc(buf, spec["bass"]["wave"], f, f, t0 + s * step, dur, spec["bass"]["vol"], 0.005, 0.3, 0.0, 0.0, spec["bass"]["cut"])
			if "arp" in layers:
				_arp(buf, spec, spec["arp"], chord, t0, step)
			if "drums" in layers:
				_drums(buf, spec["drums"], t0, step, k % 4 == 3)
			if "lead" in layers:
				_lead(buf, spec, deg, t0, step)
			if "swell" in layers and k % 2 == 0:
				_noise(buf, t0 + bar, bar * 2.0, 0.10, 1800.0, true)
			if "glide" in layers and k % 4 == 1:
				var f0 := mtof(note(spec, deg + 4, 2))
				_osc(buf, "sine", f0, f0 * 0.75, t0 + beat, bar * 1.5, 0.08, 0.4, 0.6, 3.0, 0.01, 0.0)
			b += 1
	_reverb(buf, 0.28)
	# Bucle perfecto: la cola (reverb, notas largas) vuelve al principio.
	for i in tail:
		buf[i] += buf[length + i]
	buf.resize(length)
	var peak := 0.0001
	for i in length:
		peak = maxf(peak, absf(buf[i]))
	var g := 0.85 / peak
	for i in length:
		buf[i] = tanh(buf[i] * g * 1.1) * 0.92
	return buf


func _pad(buf: PackedFloat32Array, p: Dictionary, chord: Array, t0: float, dur: float) -> void:
	var detune := [0.997, 1.003] if p["wave"] != "choir" else [0.994, 1.0, 1.006]
	var wave: String = "saw" if p["wave"] == "choir" else p["wave"]
	for m in chord:
		for dt in detune:
			var f: float = mtof(m) * dt
			_osc(buf, wave, f, f, t0, dur * 1.15, p["vol"] / (chord.size() * detune.size()) * 2.2, dur * 0.35, dur * 0.5, p.get("vib", 0.0), p.get("vd", 0.0), p["cut"])


func _arp(buf: PackedFloat32Array, spec: Dictionary, a: Dictionary, chord: Array, t0: float, step: float) -> void:
	var every: int = a["step"]
	var s := 0
	var idx := 0
	while s < 16:
		if a.get("sparse", false) and rng.randf() < 0.55:
			s += every
			continue
		var m: float = chord[idx % 3] + 12 * a["oct"]
		if a.get("random_oct", false) and rng.randf() < 0.3:
			m += 12
		var f := mtof(m)
		var dur := step * every * 1.8
		if a["wave"] == "bell":
			_osc(buf, "sine", f, f, t0 + s * step, dur * 2.0, a["vol"], 0.002, dur * 0.6, 0.0, 0.0, 0.0)
			_osc(buf, "sine", f * 2.76, f * 2.76, t0 + s * step, dur, a["vol"] * 0.35, 0.002, dur * 0.25, 0.0, 0.0, 0.0)
		else:
			_osc(buf, a["wave"], f, f, t0 + s * step, dur, a["vol"], 0.004, dur * 0.4, 0.0, 0.0, a.get("cut", 0.0))
		idx += 1
		s += every


func _lead(buf: PackedFloat32Array, spec: Dictionary, deg: int, t0: float, step: float) -> void:
	# Motivo melódico corto por compás: paseo por la escala desde el acorde.
	var d := deg + 7
	var s := 0
	while s < 16:
		var len_steps: int = [2, 2, 4, 4, 6][rng.randi() % 5]
		if rng.randf() < 0.75:
			var f := mtof(note(spec, d, 1))
			_osc(buf, "tri", f, f, t0 + s * step, step * len_steps, 0.10, 0.02, step * len_steps * 0.6, 5.0, 0.004, 3000.0)
		d += [-2, -1, 1, 2, 0][rng.randi() % 5]
		s += len_steps


func _drums(buf: PackedFloat32Array, d: Dictionary, t0: float, step: float, fill: bool) -> void:
	var soft: float = 0.6 if d.get("soft", false) else 1.0
	for s in d.get("kick", []):
		_osc(buf, "sine", 150.0, 42.0, t0 + s * step, 0.32, 0.55 * soft, 0.002, 0.12, 0.0, 0.0, 0.0)
	if d.get("boom", false):
		_osc(buf, "sine", 90.0, 28.0, t0, 1.6, 0.7, 0.003, 0.7, 0.0, 0.0, 0.0)
		_noise(buf, t0, 1.2, 0.18, 400.0, false)
	for s in d.get("snare", []):
		if d.get("clap", false):
			for r in 3:
				_noise(buf, t0 + s * step + r * 0.012, 0.12, 0.16, 3500.0, false)
		else:
			_noise(buf, t0 + s * step, 0.18, 0.22, 3000.0, false)
			if d.get("metal", false):
				_osc(buf, "square", 820.0, 760.0, t0 + s * step, 0.15, 0.05, 0.001, 0.05, 0.0, 0.0, 4000.0)
	for s in d.get("hat", []):
		_noise(buf, t0 + s * step, 0.05, 0.07 * soft, 9000.0, false)
	for s in d.get("toms", []):
		_osc(buf, "sine", 110.0, 70.0, t0 + s * step, 0.4, 0.4, 0.002, 0.18, 0.0, 0.0, 0.0)
	if fill:
		for s in [13, 14, 15]:
			_noise(buf, t0 + s * step, 0.08, 0.12 * soft, 2500.0, false)


## Oscilador con barrido, envolvente (ataque / caída exponencial), vibrato y paso bajo.
func _osc(buf: PackedFloat32Array, wave: String, f0: float, f1: float, t: float, dur: float, vol: float, att: float, decay: float, vib: float, vd: float, cut: float) -> void:
	var start := int(t * SR)
	var n := int(dur * SR)
	var phase := rng.randf()
	var lp := 0.0
	var alpha := clampf(TAU * cut / SR, 0.0, 1.0) if cut > 0.0 else 1.0
	var ratio := f1 / f0
	var inv_n := 1.0 / maxf(1.0, n)
	var att_s := att * SR
	var dec_k := 1.0 / maxf(0.001, decay * SR)
	for j in n:
		var i := start + j
		if i >= buf.size():
			break
		var u := j * inv_n
		var f := f0 * pow(ratio, u) if ratio != 1.0 else f0
		if vib > 0.0:
			f *= 1.0 + vd * sin(TAU * vib * j / SR)
		phase += f / SR
		phase -= floorf(phase)
		var s := 0.0
		match wave:
			"sine":
				s = sin(TAU * phase)
			"saw":
				s = 2.0 * phase - 1.0
			"square":
				s = 1.0 if phase < 0.5 else -1.0
			"tri":
				s = 4.0 * absf(phase - 0.5) - 1.0
		lp += alpha * (s - lp)
		var env := (j / att_s) if j < att_s else exp(-(j - att_s) * dec_k)
		env *= minf(1.0, (n - j) * 0.002)
		buf[i] += lp * env * vol


func _noise(buf: PackedFloat32Array, t: float, dur: float, vol: float, cut: float, rising: bool) -> void:
	var start := int(t * SR)
	var n := int(dur * SR)
	var lp := 0.0
	var prev := 0.0
	var alpha := clampf(TAU * cut / SR, 0.0, 1.0)
	for j in n:
		var i := start + j
		if i >= buf.size():
			break
		var s := rng.randf_range(-1.0, 1.0)
		lp += alpha * (s - lp)
		var v := lp if cut < 5000.0 else lp - prev  # agudos: paso alto aproximado
		prev = lp
		var u := float(j) / n
		var env := u * u if rising else exp(-u * 8.0)
		if rising:
			env *= minf(1.0, (n - j) * 0.001)
		buf[i] += v * env * vol


## Reverb tipo Schroeder: 4 filtros peine en paralelo + 2 pasa-todo.
func _reverb(buf: PackedFloat32Array, wet: float) -> void:
	var n := buf.size()
	var out := PackedFloat32Array()
	out.resize(n)
	for d in [1116, 1188, 1277, 1356]:
		var delay: int = d * SR / 44100
		var line := PackedFloat32Array()
		line.resize(delay)
		var idx := 0
		for i in n:
			var y := line[idx]
			line[idx] = buf[i] + y * 0.82
			out[i] += y
			idx = (idx + 1) % delay
	for d in [556, 441]:
		var delay: int = d * SR / 44100
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
		buf[i] = buf[i] * (1.0 - wet * 0.5) + out[i] * wet * 0.25


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
