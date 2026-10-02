class_name Backdrop
extends Node2D
## Fondo estelar con parallax (contraste reducido para no competir con el gameplay: 19.1).

var sector: Sector
var stars: Array = []


func _ready() -> void:
	z_index = -20
	var r := RandomNumberGenerator.new()
	r.seed = 99
	for i in 260:
		stars.append({"p": Vector2(r.randf(), r.randf()), "d": r.randf_range(0.05, 0.35), "s": r.randf_range(0.6, 2.0), "a": r.randf_range(0.25, 0.8)})


func _process(_delta: float) -> void:
	if sector.camera:
		position = sector.camera.get_screen_center_position()
	queue_redraw()


func _draw() -> void:
	var vp := get_viewport_rect().size / sector.camera.zoom if sector.camera else get_viewport_rect().size
	var span := vp * 1.2
	draw_rect(Rect2(-span * 0.5, span), sector.biome["bg"])
	var cam := position
	for s in stars:
		var p: Vector2 = s["p"] * span - cam * s["d"]
		p = Vector2(fposmod(p.x, span.x), fposmod(p.y, span.y)) - span * 0.5
		draw_circle(p, s["s"], Color(0.8, 0.85, 1.0, s["a"]))
