class_name Asteroid
extends Entity
## Obstáculo del bioma (rocas, chatarra, restos, cristales, huevos…). Si `ore` no está vacío es un
## depósito de recursos que se mina disparándole. Sólo las naves colisionan con obstáculos.

var ore := ""
var sprite_id := ""
var hp := 1.0
var hp_max := 1.0
var poly := PackedVector2Array()
var spin := 0.0
var rot := 0.0
var flash := 0.0
var glow := 0.0


func setup(p_sector: Sector, pos: Vector2, r: float, p_ore: String, rng: RandomNumberGenerator) -> void:
	sector = p_sector
	plane_pos = pos
	radius = r
	ore = p_ore
	height = 0.0
	hp_max = 1500.0 + r * 40.0
	hp = hp_max
	spin = rng.randf_range(-0.06, 0.06)
	rot = rng.randf() * TAU
	glow = rng.randf() * TAU
	if ore != "":
		sprite_id = ["ore_1", "ore_2"][rng.randi() % 2]
	else:
		var pool: Array = GameData.OBSTACLES_COMMON + GameData.OBSTACLES_BIOME.get(sector.theme_id, [])
		sprite_id = pool[rng.randi() % pool.size()]
	var n := 9 + rng.randi() % 5
	for i in n:
		var a := TAU * i / n
		poly.append(Vector2.from_angle(a) * rng.randf_range(0.75, 1.05))
	sync_screen()


func _process(delta: float) -> void:
	# Mapa grande: sólo se animan y dibujan los obstáculos cercanos a la nave.
	visible = sector.player == null or plane_pos.distance_to(sector.player.plane_pos) < 2300.0
	if not visible:
		return
	rot += spin * delta
	glow += delta * 2.0
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
	var tex := SpriteLib.get_tex("obstacles", sprite_id)
	if tex:
		draw_shadow(radius * 0.9, 0.25)
		var mod := Color.WHITE.lerp(Color(2, 2, 2), flash * 0.3)
		if ore != "":
			# Depósito: halo del color del material bajo el sprite y tinte suave.
			var c := GameData.mat_color(ore)
			var pulse := 0.5 + 0.5 * sin(glow)
			draw_set_transform_matrix(Iso.MATRIX)
			draw_circle(Vector2.ZERO, radius * 1.3, Color(c, 0.10 + 0.08 * pulse))
			draw_set_transform_matrix(Transform2D.IDENTITY)
			mod = mod * Color(1, 1, 1).lerp(c, 0.35)
		draw_set_transform_matrix(Iso.sprite_matrix(rot, radius * 0.25, radius * 1.3))
		draw_texture_rect(tex, Rect2(-1.0, -1.0, 2.0, 2.0), false, mod)
		draw_set_transform_matrix(Transform2D.IDENTITY)
	else:
		_draw_procedural()
	if ore != "" and (hp < hp_max or sector.player.target == self):
		draw_bar(-radius * 0.9 - 10.0, radius * 1.2, hp / hp_max, GameData.mat_color(ore))
		if sector.player.target == self:
			draw_ring(radius * 1.25, Color(1, 0.9, 0.3, 0.8), 2.0)


func _draw_procedural() -> void:
	var b: Dictionary = sector.biome
	var fill: Color = b["rock"]
	var edge: Color = b["rock_edge"]
	if flash > 0.0:
		fill = fill.lerp(Color.WHITE, flash * 0.4)
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
	draw_set_transform_matrix(Transform2D.IDENTITY)
