class_name Asteroid
extends Entity
## Obstáculo del bioma. Si `ore` no está vacío es un nodo de recursos que se puede minar disparándole.

var ore := ""
var hp := 1.0
var hp_max := 1.0
var poly := PackedVector2Array()
var spin := 0.0
var rot := 0.0
var colors: Dictionary = {}
var flash := 0.0


func setup(p_sector: Sector, pos: Vector2, r: float, p_ore: String, rng: RandomNumberGenerator) -> void:
	sector = p_sector
	plane_pos = pos
	radius = r
	ore = p_ore
	height = 0.0
	hp_max = 1500.0 + r * 40.0
	hp = hp_max
	spin = rng.randf_range(-0.15, 0.15)
	rot = rng.randf() * TAU
	var n := 9 + rng.randi() % 5
	for i in n:
		var a := TAU * i / n
		poly.append(Vector2.from_angle(a) * rng.randf_range(0.75, 1.05))
	sync_screen()


func _process(delta: float) -> void:
	rot += spin * delta
	flash = maxf(0.0, flash - delta * 4.0)
	queue_redraw()


func take_hit(amount: float, _info: Dictionary) -> void:
	if ore == "" or not alive:
		return
	hp -= amount
	flash = 1.0
	if hp <= 0.0:
		alive = false
		sector.on_ore_mined(self)
		queue_free()


func _draw() -> void:
	var b: Dictionary = sector.biome
	var fill: Color = b["rock"]
	var edge: Color = b["rock_edge"]
	if flash > 0.0:
		fill = fill.lerp(Color.WHITE, flash * 0.4)
	# Volumen falso: base oscura desplazada y cara superior.
	draw_set_transform_matrix(Iso.MATRIX * Transform2D(rot, Vector2.ONE * radius, 0.0, Vector2.ZERO))
	draw_colored_polygon(poly, fill.darkened(0.5))
	draw_set_transform_matrix(Transform2D(0.0, Vector2(0, -radius * 0.35)) * Iso.MATRIX * Transform2D(rot, Vector2.ONE * radius, 0.0, Vector2.ZERO))
	draw_colored_polygon(poly, fill)
	var closed := poly.duplicate()
	closed.append(poly[0])
	draw_polyline(closed, edge, 1.5 / radius, true)
	if ore != "":
		var c := GameData.mat_color(ore)
		for i in 3:
			var p := poly[i * 3 % poly.size()] * 0.45
			draw_circle(p, 0.12, c)
			draw_circle(p, 0.22, Color(c, 0.25))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	if ore != "" and (hp < hp_max or sector.player.target == self):
		draw_bar(-radius * 0.9 - 10.0, radius * 1.2, hp / hp_max, GameData.mat_color(ore))
		if sector.player.target == self:
			draw_ring(radius * 1.25, Color(1, 0.9, 0.3, 0.8), 2.0)
