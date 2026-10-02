class_name Backdrop
extends Node2D
## Fondo espacial por bioma con parallax (19.1: alto detalle, contraste reducido).
## Capa 1: imagen del bioma (assets/backgrounds/<bioma>.png) repetida en espejo para ocultar costuras.
## Capas 2-3: estrellas a distintas profundidades.

const BG_PARALLAX := 0.04
const BG_SCALE := 1.6

var sector: Sector
var stars: Array = []
var tex: Texture2D


func _ready() -> void:
	z_index = -20
	texture_repeat = CanvasItem.TEXTURE_REPEAT_MIRROR
	var path := "res://assets/backgrounds/%s.png" % sector.biome_id
	if ResourceLoader.exists(path):
		tex = load(path)
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 220:
		stars.append({"p": Vector2(r.randf(), r.randf()), "d": r.randf_range(0.08, 0.35), "s": r.randf_range(0.6, 1.8), "a": r.randf_range(0.2, 0.7)})


func _process(_delta: float) -> void:
	if sector.camera:
		position = sector.camera.get_screen_center_position()
	queue_redraw()


func _draw() -> void:
	var zoom: Vector2 = sector.camera.zoom if sector.camera else Vector2.ONE
	var vp := get_viewport_rect().size / zoom
	var span := vp * 1.2
	var rect := Rect2(-span * 0.5, span)
	draw_rect(rect, sector.biome["bg"])
	var cam := position
	if tex:
		# Región de la textura desplazada por la cámara: el fondo se mueve más lento que el mapa.
		var region_size := span / BG_SCALE
		var offset := cam * BG_PARALLAX / BG_SCALE
		draw_texture_rect_region(tex, rect, Rect2(offset - region_size * 0.5, region_size), Color(1, 1, 1, 0.9))
	for s in stars:
		var p: Vector2 = s["p"] * span - cam * s["d"]
		p = Vector2(fposmod(p.x, span.x), fposmod(p.y, span.y)) - span * 0.5
		draw_circle(p, s["s"], Color(0.85, 0.9, 1.0, s["a"]))
