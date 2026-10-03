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
