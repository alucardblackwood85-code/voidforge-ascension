class_name ObjPoint
extends Entity
## Puntos de objetivo y de interés del sector (M5, M19). Se activan por proximidad:
##  baliza   — quédate 6 s cerca para activarla (llegan enemigos al empezar).
##  socorro  — llega a la señal y resiste 30 s junto a ella mientras llegan oleadas.
##  convoy   — carguera aliada: avanza hacia su destino si estás cerca; los enemigos la dañan.
##  cofre    — alijo abandonado: suelta una caja de oro.
##  pecio    — restos con un registro de la historia y algo de botín.
##  veta     — veta mineral rica (asteroides con mena alrededor).

const COLORS := {"baliza": Color("4affc8"), "socorro": Color("ff5a5a"), "convoy": Color("5ad16a"), "cofre": Color("ffd84a"), "pecio": Color("9aa8c0"), "veta": Color("ffb84a")}
const NAMES := {"baliza": "Baliza", "socorro": "Señal de socorro", "convoy": "Convoy aliado", "cofre": "Alijo abandonado", "pecio": "Pecio", "veta": "Veta mineral"}

var kind := "baliza"
var progress := 0.0        # 0..1 (baliza, socorro) o fracción de ruta (convoy)
var done := false
var started := false
var anim := 0.0
var wave_t := 0.0
var hp := 1.0
var hp_max := 1.0
var route: Array = []      # convoy: puntos de paso
var route_i := 0
var speed := 70.0


func setup(p_sector: Sector, p_kind: String, pos: Vector2) -> void:
	sector = p_sector
	kind = p_kind
	plane_pos = pos
	radius = 46.0 if kind in ["convoy", "pecio"] else 34.0
	height = 18.0 if kind == "convoy" else 0.0
	anim = randf() * 10.0
	if kind == "convoy":
		hp_max = 40.0 * GameData.level_hp(100.0, sector.level)
		hp = hp_max
	sync_screen()


func label() -> String:
	return NAMES[kind]


func is_objective() -> bool:
	return kind in ["baliza", "socorro", "convoy"]


func _process(delta: float) -> void:
	anim += delta
	var p := sector.player
	var dist := plane_pos.distance_to(p.plane_pos)
	visible = dist < 2400.0
	if done or not p.alive:
		if visible:
			queue_redraw()
		return
	match kind:
		"baliza":
			if dist < 170.0:
				if not started:
					started = true
					sector.hud.toast("Activando baliza… mantente cerca", 2.0, COLORS[kind])
					sector.spawn_group_near(plane_pos + Vector2.from_angle(randf() * TAU) * 500.0, 2 + sector.level / 12, sector.level)
					Sfx.play("e_pulse", plane_pos, -4.0)
				progress = minf(1.0, progress + delta / 6.0)
				if progress >= 1.0:
					_complete()
			else:
				progress = maxf(0.0, progress - delta / 12.0)
		"socorro":
			if not started and dist < 260.0:
				started = true
				sector.hud.toast("Supervivientes localizados: resiste 30 s junto a la señal", 3.0, COLORS[kind])
				Sfx.voice("sector_alert")
			if started:
				if dist < 450.0:
					progress = minf(1.0, progress + delta / 30.0)
				wave_t -= delta
				if wave_t <= 0.0:
					wave_t = 8.0
					sector.spawn_group_near(plane_pos + Vector2.from_angle(randf() * TAU) * 650.0, 2 + sector.level / 10, sector.level)
				if progress >= 1.0:
					_complete()
		"convoy":
			_convoy(delta, dist)
		"cofre":
			if dist < 130.0:
				done = true
				sector.spawn_box({"nanoespuma": 10}, plane_pos, true, "gold")
				sector.on_poi(self, "Alijo abierto: caja de oro")
		"pecio":
			if dist < 150.0:
				done = true
				var txt := Prog.next_lore()
				var mats := {}
				for k in sector.biome["resources"].keys():
					mats[k] = int(GameData.level_reward(8.0, sector.level))
					break
				sector.spawn_box(mats, plane_pos, true)
				sector.on_poi(self, txt if txt != "" else "Pecio registrado (ya conocías su historia)")
		"veta":
			if dist < 320.0:
				done = true
				sector.on_poi(self, "Veta mineral descubierta")
	if visible:
		sync_screen()
		queue_redraw()


func _convoy(delta: float, dist: float) -> void:
	# Daño de los enemigos que lo rodean (los que ya te persiguen se fijan también en él).
	var dps := 0.0
	for e in sector.enemies:
		if e.alive and e.aggro and not e.is_nest and e.plane_pos.distance_squared_to(plane_pos) < 420.0 * 420.0:
			dps += e.out_dmg() * 0.3
	if dps > 0.0:
		hp -= dps * delta
		if hp <= 0.0:
			done = true
			sector.ship_explosion(plane_pos, radius * 1.6)
			sector.on_objective_failed("El convoy ha sido destruido")
			visible = false
			return
	if route_i >= route.size():
		return
	if dist < 650.0:
		var tgt: Vector2 = route[route_i]
		var to := tgt - plane_pos
		if to.length() < 30.0:
			route_i += 1
			if route_i >= route.size():
				_complete()
				return
		else:
			plane_pos += to.normalized() * speed * delta
			progress = float(route_i) / route.size()
	if not started and dist < 650.0:
		started = true
		sector.hud.toast("Escolta el convoy: mantente a menos de 650 u para que avance", 3.0, COLORS[kind])


func _complete() -> void:
	done = true
	progress = 1.0
	sector.fx_ring(plane_pos, 200.0, COLORS[kind])
	sector.on_point_done(self)


func _draw() -> void:
	var col: Color = COLORS[kind]
	var pulse := 0.6 + 0.4 * sin(anim * 3.0)
	if done and kind != "convoy":
		col = col.darkened(0.6)
	match kind:
		"baliza":
			draw_ring(170.0, Color(col, 0.18 + 0.12 * pulse), 2.0)
			_pylon(col, pulse)
			if progress > 0.0 and not done:
				draw_arc(Vector2(0, -60), 26.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, col, 5.0)
		"socorro":
			if started and not done:
				draw_ring(450.0, Color(col, 0.15 + 0.1 * pulse), 2.0)
			_wreck(Color("8a95a8"))
			if not done:
				draw_circle(Vector2(0, -50), 6.0 + 3.0 * pulse, Color(col, 0.9))
			if progress > 0.0 and not done:
				draw_arc(Vector2(0, -50), 24.0, -PI * 0.5, -PI * 0.5 + TAU * progress, 32, col, 4.0)
		"convoy":
			var tex := SpriteLib.get_tex("ships", "mule_c1")
			var ang := 0.0
			if route_i < route.size():
				ang = ((route[route_i] as Vector2) - plane_pos).angle()
			if tex:
				SpriteLib.draw_dir(self, "ships", "mule_c1", tex, radius, ang, height, Color(0.8, 1.0, 0.85))
			else:
				draw_circle(Vector2(0, -height), radius * 0.6, col)
			draw_ring(radius * 1.3, Color(col, 0.5), 2.0)
			draw_bar(-height - radius - 14.0, 90.0, hp / hp_max, col)
		"cofre":
			var tex := SpriteLib.get_tex("loot", "cargo_box_rare")
			if not done:
				for k in 3:
					draw_rect(Rect2(-6.0 + k * 2.0, -200, 12.0 - k * 4.0, 200), Color(col, 0.08 * pulse * (k + 1)))
			if tex:
				draw_texture_rect(tex, Rect2(-30, -50, 60, 60), false, Color.WHITE.lerp(col, 0.4) if not done else Color(0.4, 0.4, 0.4))
		"pecio":
			_wreck(Color("9aa8c0") if not done else Color("4a5060"))
			if not done:
				draw_ring(150.0, Color(col, 0.12 + 0.08 * pulse), 1.5)
		"veta":
			if not done:
				draw_ring(320.0, Color(col, 0.08 + 0.06 * pulse), 1.5)


func _pylon(col: Color, pulse: float) -> void:
	draw_colored_polygon(PackedVector2Array([Vector2(-14, 0), Vector2(14, 0), Vector2(6, -44), Vector2(-6, -44)]), Color("2a3448"))
	draw_polyline(PackedVector2Array([Vector2(-14, 0), Vector2(-6, -44), Vector2(6, -44), Vector2(14, 0)]), col.darkened(0.2), 2.0)
	draw_circle(Vector2(0, -52), 9.0, Color(col, 0.5 + 0.5 * pulse))
	var r := 18.0 + 4.0 * sin(anim * 2.0)
	draw_arc(Vector2(0, -52), r, anim * 2.0, anim * 2.0 + PI * 1.2, 24, Color(col, 0.7), 2.0)


func _wreck(col: Color) -> void:
	# Satélite abandonado (sprite prerrenderizado); el dibujo vectorial queda de reserva.
	var tex := SpriteLib.get_tex("obstacles", "junk_2")
	if tex:
		var s := radius * 2.8
		draw_texture_rect(tex, Rect2(-s * 0.5, -s * 0.75, s, s), false, Color.WHITE.lerp(col, 0.25) if col.v > 0.4 else Color(0.45, 0.45, 0.5))
		return
	var rot := Iso.MATRIX
	var pts := PackedVector2Array()
	for p in [Vector2(-50, -10), Vector2(-20, -28), Vector2(30, -22), Vector2(55, 4), Vector2(18, 26), Vector2(-34, 20)]:
		pts.append(rot * p + Vector2(0, -8))
	draw_colored_polygon(pts, col.darkened(0.45))
	pts.append(pts[0])
	draw_polyline(pts, col, 2.0)
	draw_line(rot * Vector2(-30, -6) + Vector2(0, -8), rot * Vector2(26, 8) + Vector2(0, -8), col.darkened(0.2), 3.0)
	draw_line(rot * Vector2(-6, -20) + Vector2(0, -8), rot * Vector2(4, 18) + Vector2(0, -8), col.darkened(0.2), 2.0)
