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


# --- Fotogramas 3D (32 ángulos) ---------------------------------------------------------------
## Modelos 3D renderizados con cámara ortográfica fija a FRAME_ELEV grados (tools/build_3d_frames.ps1):
## el fotograma i tiene la proa a i*360/FRAME_COUNT grados (antihorario visto desde arriba, empezando
## por la derecha). Como en DarkOrbit, la nave nunca se gira como imagen: se muestra el fotograma de su
## rumbo, así la perspectiva y la luz siempre son coherentes.
const FRAME_COUNT := 32
const FRAME_ELEV := 55.0
const FRAME_COLS := 8            # hoja WebP de 8x4 fotogramas (tools/pack_frames.ps1)
const FRAME_SIZE := 2.3          # tamaño del fotograma respecto al radio visual
const FRAME_TURN_RATE := 9.0     # rad/s del giro visual (media vuelta en ~0,35 s)
## Modelos descartados tras revisarlos (se queda el sprite cenital).
const FRAME_EXCLUDED := []


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


## Dibuja una entidad con sus fotogramas 3D si los tiene; si no, el sprite cenital girado.
## `angle` es el rumbo en el plano lógico; el giro visual lo sigue rápido y continuo, sin alabeo.
static func draw_dir(ci: CanvasItem, group: String, id: String, fallback: Texture2D, radius: float, angle: float, h: float, modulate: Color = Color.WHITE) -> void:
	if has_frames(group, id):
		var tgt := Iso.to_screen(Vector2.from_angle(angle)).angle()
		var now := Time.get_ticks_msec() / 1000.0
		var dt := clampf(now - float(ci.get_meta("_vt", now)), 0.0, 0.1)
		var av: float = ci.get_meta("_va", tgt)
		av = rotate_toward(av, tgt, FRAME_TURN_RATE * dt)
		ci.set_meta("_vt", now)
		ci.set_meta("_va", av)
		if _draw_frame(ci, group, id, radius, av, h, modulate):
			return
	if fallback:
		draw(ci, fallback, radius, angle, h, modulate)
