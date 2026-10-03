class_name SpriteLib
## Carga perezosa de sprites. Si existe res://assets/sprites/<grupo>/<id>.png se usa en lugar de la
## silueta procedural. Convención: vista cenital estricta, frente de la nave mirando a la DERECHA,
## fondo transparente (la proyección isométrica se aplica en el motor).

## Tamaño visual del sprite respecto al radio de colisión.
const VISUAL_SCALE := 1.35

static var _cache: Dictionary = {}


static func get_tex(group: String, id: String) -> Texture2D:
	var key := group + "/" + id
	if not _cache.has(key):
		var path := "res://assets/sprites/%s.png" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Dibuja una textura en el plano con rotación, elevación y radio dados.
static func draw(ci: CanvasItem, tex: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE) -> void:
	ci.draw_set_transform_matrix(Iso.sprite_matrix(angle, h, radius * VISUAL_SCALE))
	ci.draw_texture_rect(tex, Rect2(-1.25, -1.25, 2.5, 2.5), false, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


## Icono de interfaz: res://assets/ui/<grupo>/<id>.png (o null si aún no existe).
static func get_icon(group: String, id: String) -> Texture2D:
	var key := "ui/" + group + "/" + id
	if not _cache.has(key):
		var path := "res://assets/%s.png" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Versión recortada al contenido visible (para iconos del menú: algunas naves traían mucho margen).
static func get_cropped(group: String, id: String) -> Texture2D:
	var key := "crop/" + group + "/" + id
	if _cache.has(key):
		return _cache[key]
	var tex := get_tex(group, id)
	var out: Texture2D = tex
	if tex:
		var img := tex.get_image()
		if img and not img.is_compressed():
			var r := img.get_used_rect()
			if r.size.x > 0 and r.size.y > 0:
				# Región cuadrada centrada en el contenido, con un pequeño margen.
				var side := int(maxf(r.size.x, r.size.y) * 1.08)
				var c := r.get_center()
				var at := AtlasTexture.new()
				at.atlas = tex
				at.region = Rect2(c.x - side * 0.5, c.y - side * 0.5, side, side)
				at.filter_clip = true
				out = at
	_cache[key] = out
	return out


# --- Vistas direccionales (8 direcciones) ------------------------------------------------------
## Las naves, enemigos y el dron tienen 5 vistas prerrenderizadas en perspectiva (e, ne, n, se, s);
## las direcciones w, nw y sw son su espejo. Índice por ángulo en pantalla (y hacia abajo).
const VIEW_DIRS := ["e", "se", "s", "se", "e", "ne", "n", "ne"]
const VIEW_MIRROR := [false, false, false, true, true, true, false, false]
const VIEW_TURN_RATE := 7.5     # rad/s máximos del giro visual (rápido, como en DarkOrbit)
const VIEW_BLEND := 0.35        # fracción del hueco entre dos vistas en la que se funden
const VIEW_BANK_TILT := 0.14    # rad de inclinación con oscilación máxima
const VIEW_BANK_SQUASH := 0.07  # estrechamiento horizontal con oscilación máxima
const VIEW_BOB := 1.0           # px de balanceo vertical en vuelo
const VIEW_SIZE := 2.1          # tamaño de la vista respecto al radio visual (iguala al sprite cenital)
## Correcciones por modelo: una dirección usa otra vista girada (grados, horario en pantalla).
## Para vistas que la generación dejó con el rumbo equivocado.
const VIEW_FIX := {
	"ships/falcon_r": {"ne": ["e", -45.0], "n": ["e", -90.0]},
	"ships/kestrel_a1": {"ne": ["n", 45.0]},
	# Vista superior descartada en la revisión: el norte sale de la diagonal girada.
	"ships/bastion_h": {"n": ["ne", -45.0]},
	"ships/aegis_r": {"n": ["ne", -45.0]},
	"ships/atlas_c4": {"n": ["ne", -45.0]},
	"ships/centurion_p": {"n": ["ne", -45.0]},
	"ships/fortress_omega": {"n": ["ne", -45.0]},
	"ships/ark_meridian": {"n": ["ne", -45.0]},
	"ships/event_horizon": {"n": ["ne", -45.0]},
}


## Sólo se usan las vistas desde arriba (ne, n): la nave nunca se ve de lado ni por debajo.
## Este = "ne" girada 45°; abajo-derecha = "ne" girada 90°; abajo = "n" girada 180°.
const VIEW_DERIVED := {"e": ["ne", 45.0], "s": ["n", 180.0], "se": ["ne", 90.0]}


## Vista base y giro (grados, horario) para una dirección sin espejo, aplicando las correcciones.
static func _resolve_view(group: String, id: String, dir: String) -> Array:
	var rot := 0.0
	if VIEW_DERIVED.has(dir):
		rot = VIEW_DERIVED[dir][1]
		dir = VIEW_DERIVED[dir][0]
	var fix: Array = VIEW_FIX.get(group + "/" + id, {}).get(dir, [])
	if not fix.is_empty():
		dir = fix[0]
		rot += float(fix[1])
	return [dir, rot]


## Modelos cuyas vistas se revisaron una a una (las perspectivas con problemas se borraron).
## Un modelo nuevo se añade aquí tras revisarlo con --viewtest.
const VIEW_VERIFIED := [
	"ships/kestrel_a1", "ships/falcon_r", "ships/bastion_h", "ships/aegis_r",
	"ships/atlas_c4", "ships/centurion_p", "ships/fortress_omega", "ships/ark_meridian", "ships/event_horizon",
]


static func has_views(group: String, id: String) -> bool:
	var key := "views?/" + group + "/" + id
	if not _cache.has(key):
		var ok: bool = VIEW_VERIFIED.has(group + "/" + id)
		# Comprueba que existan las imágenes base a las que se resuelven las direcciones.
		for d in ["ne", "n", "e"]:
			var base: String = _resolve_view(group, id, d)[0]
			ok = ok and ResourceLoader.exists("res://assets/sprites/views/%s/%s/%s.png" % [group, id, base])
		_cache[key] = ok
	return _cache[key]


static func get_view(group: String, id: String, dir: String) -> Texture2D:
	var key := "views/" + group + "/" + id + "/" + dir
	if not _cache.has(key):
		var path := "res://assets/sprites/views/%s/%s/%s.png" % [group, id, dir]
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


# --- Fotogramas 3D (32 ángulos) ---------------------------------------------------------------
## Modelos 3D renderizados con cámara ortográfica fija a FRAME_ELEV grados (tools/build_3d_frames.ps1):
## el fotograma i tiene la proa a i*360/FRAME_COUNT grados (antihorario visto desde arriba, empezando
## por la derecha). Como en DarkOrbit, la nave nunca se gira como imagen: se muestra el fotograma de su
## rumbo, así la perspectiva y la luz siempre son coherentes. Tienen prioridad sobre las vistas.
const FRAME_COUNT := 32
const FRAME_ELEV := 55.0
const FRAME_SIZE := 2.3          # tamaño del fotograma respecto al radio visual
const FRAME_TURN_RATE := 9.0     # rad/s del giro visual (media vuelta en ~0,35 s)
## Modelos descartados tras revisarlos (se queda el sprite cenital o sus vistas).
const FRAME_EXCLUDED := []


const FRAME_COLS := 8             # hoja WebP de 8x4 fotogramas (tools/pack_frames.ps1)


static func has_frames(group: String, id: String) -> bool:
	var key := "frames?/" + group + "/" + id
	if not _cache.has(key):
		_cache[key] = not FRAME_EXCLUDED.has(group + "/" + id) and ResourceLoader.exists("res://assets/sprites/frames/%s/%s.webp" % [group, id])
	return _cache[key]


static func get_frame(group: String, id: String, i: int) -> Texture2D:
	var key := "frames/%s/%s/%d" % [group, id, i]
	if not _cache.has(key):
		var sheet_key := "frames/%s/%s" % [group, id]
		if not _cache.has(sheet_key):
			var path := "res://assets/sprites/frames/%s/%s.webp" % [group, id]
			_cache[sheet_key] = load(path) if ResourceLoader.exists(path) else null
		var sheet: Texture2D = _cache[sheet_key]
		if sheet == null:
			_cache[key] = null
		else:
			var fs := sheet.get_width() / FRAME_COLS
			var at := AtlasTexture.new()
			at.atlas = sheet
			at.region = Rect2((i % FRAME_COLS) * fs, (i / FRAME_COLS) * fs, fs, fs)
			at.filter_clip = true
			_cache[key] = at
	return _cache[key]


## Ángulo del modelo (antihorario visto desde arriba) cuya proa se ve con el ángulo `a` en pantalla.
static func _model_angle(a: float) -> float:
	return atan2(-sin(a) / sin(deg_to_rad(FRAME_ELEV)), cos(a))


## Ángulo en pantalla de la proa del fotograma i.
static func _frame_screen_angle(i: int) -> float:
	var phi := TAU * i / FRAME_COUNT
	return atan2(-sin(phi) * sin(deg_to_rad(FRAME_ELEV)), cos(phi))


static func _draw_frame(ci: CanvasItem, group: String, id: String, radius: float, a: float, h: float, modulate: Color) -> bool:
	var i := posmod(roundi(_model_angle(a) / (TAU / FRAME_COUNT)), FRAME_COUNT)
	var tex := get_frame(group, id, i)
	if tex == null:
		return false
	var s := radius * VISUAL_SCALE * FRAME_SIZE
	# Giro residual mínimo (≤ medio paso) para que el rumbo no avance a saltos.
	var residual := angle_difference(_frame_screen_angle(i), a)
	ci.draw_set_transform(Vector2(0.0, -h), residual, Vector2.ONE)
	ci.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
	return true


## Dibuja una entidad con su vista direccional si existe; si no, el sprite cenital girado.
## `angle` es el rumbo en el plano lógico. Giro suave:
##  - el rumbo visual sigue al real con velocidad de giro limitada (los virajes bruscos se ven como curva);
##  - la vista más cercana se gira el ángulo residual (±22,5°) para seguir el rumbo exacto;
##  - cerca de la frontera entre dos vistas, la siguiente se funde encima de la anterior;
##  - al virar, la nave se inclina hacia el giro (alabeo) y flota con un balanceo sutil.
static func draw_dir(ci: CanvasItem, group: String, id: String, fallback: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE, strafe: float = 0.0) -> void:
	if has_frames(group, id):
		# Fotogramas 3D: giro rápido y continuo hacia el rumbo, sin alabeo (como en DarkOrbit).
		var tgt := Iso.to_screen(Vector2.from_angle(angle)).angle()
		var t_now := Time.get_ticks_msec() / 1000.0
		var dtf := clampf(t_now - float(ci.get_meta("_vt", t_now)), 0.0, 0.1)
		var av: float = ci.get_meta("_va", tgt)
		av = rotate_toward(av, tgt, FRAME_TURN_RATE * dtf)
		ci.set_meta("_vt", t_now)
		ci.set_meta("_va", av)
		if _draw_frame(ci, group, id, radius, av, h, modulate):
			return
	if not has_views(group, id):
		if fallback:
			draw(ci, fallback, radius, angle, h, modulate)
		return
	var target := Iso.to_screen(Vector2.from_angle(angle)).angle()
	var now := Time.get_ticks_msec() / 1000.0
	var dt := clampf(now - float(ci.get_meta("_vt", now)), 0.0, 0.1)
	var a: float = ci.get_meta("_va", target)
	var prev := a
	a = rotate_toward(a, target, VIEW_TURN_RATE * dt)
	# Alabeo: proporcional a la velocidad angular, suavizado.
	var w := angle_difference(prev, a) / maxf(dt, 0.001)
	var bank: float = ci.get_meta("_vbank", 0.0)
	# Oscilación: por el giro y, sobre todo, por el desplazamiento lateral respecto a donde apunta.
	bank = lerpf(bank, clampf(w / VIEW_TURN_RATE * 0.5 + strafe, -1.0, 1.0), clampf(dt * 5.0, 0.0, 1.0))
	ci.set_meta("_vt", now)
	ci.set_meta("_va", a)
	ci.set_meta("_vbank", bank)
	var step := PI / 4.0
	var pos := a / step
	var i0 := floori(pos)
	var t := pos - i0
	# Fundido sólo en la franja central entre dos vistas: el resto del tiempo se ve una sola.
	var blend := smoothstep(0.5 - VIEW_BLEND * 0.5, 0.5 + VIEW_BLEND * 0.5, t)
	var main_i := i0 if blend < 0.5 else i0 + 1
	var other_i := i0 + 1 if main_i == i0 else i0
	var other_w := blend if main_i == i0 else 1.0 - blend
	var s := radius * VISUAL_SCALE * VIEW_SIZE
	var bob := sin(now * 2.2 + float(ci.get_instance_id() % 97)) * VIEW_BOB
	var origin := Vector2(0.0, -h - s * 0.08 + bob)
	_draw_view(ci, group, id, fallback, radius, angle, h, modulate, posmod(main_i, 8), a - main_i * step, bank, s, origin, 1.0)
	if other_w > 0.01:
		_draw_view(ci, group, id, fallback, radius, angle, h, modulate, posmod(other_i, 8), a - other_i * step, bank, s, origin, other_w)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)


static func _draw_view(ci: CanvasItem, group: String, id: String, fallback: Texture2D, radius: float, angle: float, h: float, modulate: Color, idx: int, residual: float, bank: float, s: float, origin: Vector2, alpha: float) -> void:
	var flip := -1.0 if VIEW_MIRROR[idx] else 1.0
	var res := _resolve_view(group, id, VIEW_DIRS[idx])
	var dir: String = res[0]
	# El giro se expresa sobre la vista sin espejo: en las espejadas se invierte.
	var rot := residual + deg_to_rad(float(res[1])) * flip
	var tex := get_view(group, id, dir)
	if tex == null:
		if fallback and alpha >= 1.0:
			draw(ci, fallback, radius, angle, h, modulate)
		return
	# Alabeo: inclinación hacia el giro y leve estrechamiento (la nave "rueda" sobre su eje).
	rot += bank * VIEW_BANK_TILT
	var sx := (1.0 - absf(bank) * VIEW_BANK_SQUASH) * flip
	ci.draw_set_transform(origin, rot, Vector2(sx, 1.0))
	var m := modulate
	m.a *= alpha
	ci.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false, m)


## Desplazamiento lateral (−1..1) respecto al rumbo, medido en pantalla: positivo si la nave se
## mueve hacia su derecha. Con la proa fija en el objetivo, moverse de lado la inclina hacia ese lado.
static func strafe_of(angle: float, velocity: Vector2, max_speed: float) -> float:
	var fwd := Iso.to_screen(Vector2.from_angle(angle)).normalized()
	var v := Iso.to_screen(velocity)
	return clampf(fwd.cross(v) / maxf(1.0, max_speed * Iso.K), -1.0, 1.0)
