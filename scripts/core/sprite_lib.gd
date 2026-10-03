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
const VIEW_HYSTERESIS := 0.12   # rad extra antes de cambiar de vista (evita parpadeo en la frontera)


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
## `angle` es el rumbo en el plano lógico. La vista se elige por el rumbo proyectado en pantalla.
static func draw_dir(ci: CanvasItem, group: String, id: String, fallback: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE) -> void:
	if not has_views(group, id):
		if fallback:
			draw(ci, fallback, radius, angle, h, modulate)
		return
	var a := Iso.to_screen(Vector2.from_angle(angle)).angle()
	var step := PI / 4.0
	var idx := posmod(roundi(a / step), 8)
	var last: int = ci.get_meta("_vdir", -1)
	if last >= 0 and last != idx:
		# Histéresis: sólo cambia si se aleja claramente del centro de la vista anterior.
		var d := absf(angle_difference(a, last * step))
		if d < step * 0.5 + VIEW_HYSTERESIS:
			idx = last
	ci.set_meta("_vdir", idx)
	var tex := get_view(group, id, VIEW_DIRS[idx])
	if tex == null:
		if fallback:
			draw(ci, fallback, radius, angle, h, modulate)
		return
	var s := radius * VISUAL_SCALE * 2.6
	var flip := -1.0 if VIEW_MIRROR[idx] else 1.0
	ci.draw_set_transform(Vector2(0.0, -h - s * 0.08), 0.0, Vector2(flip, 1.0))
	ci.draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
