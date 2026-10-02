class_name SpriteLib
## Carga perezosa de sprites. Si existe res://assets/sprites/<grupo>/<id>.png se usa en lugar de la
## silueta procedural. Convención: vista cenital estricta, frente de la nave mirando a la DERECHA,
## fondo transparente (la proyección isométrica se aplica en el motor).

static var _cache: Dictionary = {}


static func get_tex(group: String, id: String) -> Texture2D:
	var key := group + "/" + id
	if not _cache.has(key):
		var path := "res://assets/sprites/%s.png" % key
		_cache[key] = load(path) if ResourceLoader.exists(path) else null
	return _cache[key]


## Dibuja una textura en el plano con rotación, elevación y radio dados.
static func draw(ci: CanvasItem, tex: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE) -> void:
	ci.draw_set_transform_matrix(Iso.shape_matrix(angle, h, radius))
	ci.draw_texture_rect(tex, Rect2(-1.25, -1.25, 2.5, 2.5), false, modulate)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)
