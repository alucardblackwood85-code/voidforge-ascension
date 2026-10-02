class_name Loot
extends Entity
## Botín flotante: créditos, materiales o Cristales Nexo. Se recoge al acercarse (o con clic).

var item := "credits"
var amount := 0
var bob := 0.0
var magnet := false


func setup(p_sector: Sector, p_item: String, p_amount: int, pos: Vector2) -> void:
	sector = p_sector
	item = p_item
	amount = p_amount
	plane_pos = pos
	velocity = Vector2.from_angle(randf() * TAU) * randf_range(60.0, 180.0)
	radius = 10.0
	bob = randf() * TAU
	sync_screen()


func _process(delta: float) -> void:
	bob += delta * 3.0
	var p := sector.player
	if p.alive:
		var d := plane_pos.distance_to(p.plane_pos)
		if d < p.pickup_radius() or magnet:
			magnet = true
			var spd := maxf(300.0, p.velocity.length() + 260.0)
			velocity = (p.plane_pos - plane_pos).normalized() * spd
			if d < p.radius + 8.0:
				if sector.collect(self):
					queue_free()
					return
				magnet = false
				velocity = Vector2.ZERO
	if not magnet:
		velocity = velocity.move_toward(Vector2.ZERO, 200.0 * delta)
	plane_pos += velocity * delta
	sync_screen()
	queue_redraw()


func _draw() -> void:
	draw_shadow(9.0, 0.25)
	var h := 12.0 + sin(bob) * 3.0
	var c := GameData.mat_color(item)
	# Icono real del recurso (assets/ui/mats/<id>.png) con halo del color de su rareza.
	var tex := SpriteLib.get_icon("mats", item)
	if tex:
		var s := 34.0 if item in ["nexo", "credits"] else 30.0
		var pulse := 0.5 + 0.5 * sin(bob * 1.7)
		draw_circle(Vector2(0, -h), s * 0.55, Color(c, 0.18 + 0.12 * pulse))
		draw_set_transform(Vector2(0, -h), sin(bob * 0.5) * 0.15, Vector2.ONE)
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.5, s, s), false)
		draw_set_transform_matrix(Transform2D.IDENTITY)
		return
	if item == "credits":
		draw_circle(Vector2(0, -h), 6.0, c)
		draw_circle(Vector2(0, -h), 3.0, c.darkened(0.4))
	elif item == "nexo":
		var pts := PackedVector2Array([Vector2(0, -h - 10), Vector2(6, -h), Vector2(0, -h + 10), Vector2(-6, -h)])
		draw_colored_polygon(pts, c)
		draw_circle(Vector2(0, -h), 12.0, Color(c, 0.2))
	else:
		var pts := PackedVector2Array([Vector2(0, -h - 7), Vector2(7, -h), Vector2(0, -h + 7), Vector2(-7, -h)])
		draw_colored_polygon(pts, c)
		draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[3], pts[0]]), c.lightened(0.5), 1.0)
