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
const VIEW_TURN_RATE := 5.5     # rad/s máximos del giro visual (los cambios bruscos se ven como curva)
const VIEW_BLEND := 0.35        # fracción del hueco entre dos vistas en la que se funden
const VIEW_BANK_TILT := 0.16    # rad de inclinación con alabeo máximo
const VIEW_BANK_SQUASH := 0.10  # estrechamiento horizontal con alabeo máximo
const VIEW_BOB := 1.2           # px de balanceo vertical en vuelo
const VIEW_SIZE := 2.1          # tamaño de la vista respecto al radio visual (iguala al sprite cenital)
## Correcciones por modelo: una dirección usa otra vista girada (grados, horario en pantalla).
## Para vistas que la generación dejó con el rumbo equivocado.
const VIEW_FIX := {
	"ships/falcon_r": {"ne": ["e", -45.0], "n": ["e", -90.0], "se": ["e", 45.0], "s": ["e", 90.0]},
	"ships/bulwark_t1": {"ne": ["n", 45.0]},
	"ships/kestrel_a1": {"s": ["s", -20.0]},
}


static func has_views(group: String, id: String) -> bool:
	var key := "views?/" + group + "/" + id
	if not _cache.has(key):
		# Sólo si están las 5 vistas: un modelo a medio generar seguiría usando el sprite cenital.
		var ok := true
		for d in ["e", "ne", "n", "se", "s"]:
			ok = ok and ResourceLoader.exists("res://assets/sprites/views/%s/%s/%s.png" % [group, id, d])
		_cache[key] = ok
	return _cache[key]


static func get_view(group: String, id: String, dir: String) -> Texture2D:
	var key := "views/" + group + "/" + id + "/" + dir
	if not _cache.has(key):
		var path := "res://assets/sprites/views/%s/%s/%s.png" % [group, id, dir]
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Dibuja una entidad con su vista direccional si existe; si no, el sprite cenital girado.
## `angle` es el rumbo en el plano lógico. Giro suave:
##  - el rumbo visual sigue al real con velocidad de giro limitada (los virajes bruscos se ven como curva);
##  - la vista más cercana se gira el ángulo residual (±22,5°) para seguir el rumbo exacto;
##  - cerca de la frontera entre dos vistas, la siguiente se funde encima de la anterior;
##  - al virar, la nave se inclina hacia el giro (alabeo) y flota con un balanceo sutil.
static func draw_dir(ci: CanvasItem, group: String, id: String, fallback: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE) -> void:
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
	bank = lerpf(bank, clampf(w / VIEW_TURN_RATE, -1.0, 1.0), clampf(dt * 6.0, 0.0, 1.0))
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
	var dir: String = VIEW_DIRS[idx]
	var rot := residual
	var fix: Array = VIEW_FIX.get(group + "/" + id, {}).get(dir, [])
	var flip := -1.0 if VIEW_MIRROR[idx] else 1.0
	if not fix.is_empty():
		dir = fix[0]
		# La corrección se expresa sobre la vista sin espejo: en las espejadas se invierte.
		rot += deg_to_rad(float(fix[1])) * flip
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
