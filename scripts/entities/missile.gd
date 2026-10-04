class_name Missile
extends Node2D
## Misil teledirigido del jugador. Sale en diagonal hacia un lado, sube en arco y cae sobre el objetivo
## girando cada vez más rápido (no va en línea recta). La puntería se decide al lanzarlo: si falla,
## pasa de largo junto al objetivo y estalla en el vacío. Deja estela de humo con brasa.

const TRAIL := 18

var sector: Sector
var def: Dictionary = {}
var plane_pos := Vector2.ZERO
var vel := Vector2.ZERO
var target: Enemy = null
var damage := 0.0
var will_hit := true
var crit := false
var splash := 0.0
var color := Color("ffb84a")
var t := 0.0
var h := 20.0
var start_dist := 1.0
var miss_off := Vector2.ZERO
var passing := 0.0
var trail: Array = []       # puntos de pantalla (globales del mundo)
var dead := false
var fade := 0.0


func setup(p_sector: Sector, p_def: Dictionary, from: Vector2, p_target: Enemy, p_damage: float, hit: bool, p_crit: bool) -> void:
	sector = p_sector
	def = p_def
	plane_pos = from
	target = p_target
	damage = p_damage
	will_hit = hit
	crit = p_crit
	splash = float(def.get("splash", 0.0))
	color = def.get("color", color)
	var to := target.plane_pos - from
	start_dist = maxf(1.0, to.length())
	# Sale abierto hacia un lado (±60-80°) y algo lento: luego corrige y acelera hacia el blanco.
	var side := 1.0 if randf() < 0.5 else -1.0
	vel = to.normalized().rotated(side * randf_range(1.05, 1.4)) * float(def.get("speed", 520.0)) * 0.55
	if not will_hit:
		# Falla: apunta a un punto junto al objetivo y pasa de largo.
		miss_off = Vector2.from_angle(randf() * TAU) * (target.radius * 2.2 + 40.0)
	position = Iso.to_screen(plane_pos)


func _process(delta: float) -> void:
	if dead:
		fade -= delta
		if trail.size() > 0:
			trail.pop_front()
		if fade <= 0.0 and trail.is_empty():
			queue_free()
		queue_redraw()
		return
	t += delta
	var aim: Vector2 = target.plane_pos + miss_off if target and is_instance_valid(target) and target.alive else plane_pos + vel
	var to := aim - plane_pos
	var dist := to.length()
	var spd := float(def.get("speed", 520.0)) * clampf(0.55 + t * 1.4, 0.55, 1.35)
	# Giro cada vez más cerrado: trayectoria curva que acaba clavándose en el objetivo.
	var turn := 2.2 + t * 9.0
	var ang := rotate_toward(vel.angle(), to.angle(), turn * delta)
	if not will_hit and passing > 0.0:
		ang = vel.angle()        # ya ha fallado: sigue recto
	vel = Vector2.from_angle(ang) * spd
	plane_pos += vel * delta
	# Arco: sube en la primera mitad del recorrido y cae en la segunda.
	var p := clampf(1.0 - dist / start_dist, 0.0, 1.0)
	h = 22.0 + 90.0 * 4.0 * p * (1.0 - p) * clampf(start_dist / 500.0, 0.5, 1.2)
	position = Iso.to_screen(plane_pos)
	trail.append(position + Vector2(0, -h))
	if trail.size() > TRAIL:
		trail.pop_front()
	if target and is_instance_valid(target) and target.alive:
		var td := plane_pos.distance_to(target.plane_pos)
		if will_hit and td < target.radius * 0.6 + 14.0:
			_explode(true)
			return
		if not will_hit and td < target.radius * 3.0:
			passing += delta
	elif not will_hit:
		passing += delta
	if passing > 0.45 or t > 4.0:
		_explode(false)
		return
	queue_redraw()


func _explode(hit: bool) -> void:
	dead = true
	fade = 0.3
	if hit:
		target.take_hit(damage, {"missile": true, "color": color, "crit": crit})
		sector.fx_explosion(plane_pos, 26.0 + splash * 0.35, color)
		Sfx.play("missile_hit", plane_pos, -3.0)
		if splash > 0.0:
			for e in sector.enemies.duplicate():
				if e != target and e.alive and e.plane_pos.distance_to(plane_pos) < splash + e.radius:
					e.take_hit(damage * 0.5, {"missile": true, "color": color})
		if crit:
			sector.fx_text(plane_pos, "¡CRÍTICO!", Color("ffe04a"))
	else:
		sector.fx_explosion(plane_pos, 18.0, Color(0.7, 0.7, 0.75))
		Sfx.play("missile_hit", plane_pos, -10.0)
		sector.fx_text(plane_pos, "FALLO", Color(0.75, 0.8, 0.9))


func _draw() -> void:
	# Estela: humo gris que se desvanece y brasa cerca de la tobera.
	var n := trail.size()
	for i in range(1, n):
		var a := float(i) / n
		var p0: Vector2 = trail[i - 1] - position
		var p1: Vector2 = trail[i] - position
		draw_line(p0, p1, Color(0.75, 0.75, 0.8, 0.35 * a), 2.0 + 4.0 * (1.0 - a), true)
		if i > n - 5:
			draw_line(p0, p1, Color(color, 0.7 * a), 2.0, true)
	if dead:
		return
	var head := Vector2(0, -h)
	var dir := Iso.to_screen(vel).normalized()
	if dir == Vector2.ZERO:
		dir = Vector2.RIGHT
	var nrm := dir.orthogonal()
	# Cuerpo del misil (punta clara, aletas) y llama de la tobera.
	var tip := head + dir * 9.0
	var tail := head - dir * 7.0
	draw_colored_polygon(PackedVector2Array([tip, head + nrm * 2.4, tail + nrm * 2.4, tail - nrm * 2.4, head - nrm * 2.4]), Color(0.86, 0.88, 0.92))
	draw_colored_polygon(PackedVector2Array([tail, tail - dir * 3.0 + nrm * 4.0, tail + dir * 2.0]), Color(0.5, 0.55, 0.62))
	draw_colored_polygon(PackedVector2Array([tail, tail - dir * 3.0 - nrm * 4.0, tail + dir * 2.0]), Color(0.5, 0.55, 0.62))
	draw_line(tip - dir * 2.0, tip, color, 2.0)
	var flick := 4.0 + 3.0 * sin(t * 60.0)
	draw_colored_polygon(PackedVector2Array([tail + nrm * 1.8, tail - dir * flick * 1.6, tail - nrm * 1.8]), Color(1.0, 0.8, 0.4, 0.9))
	draw_circle(tail - dir * 1.5, 3.0, Color(color, 0.5))
