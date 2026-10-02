class_name PlayerShip
extends Entity
## Nave del jugador. Movimiento con clic derecho; objetivo con clic izquierdo; ataque automático:
## una andanada con todos los láseres cada VOLLEY_INTERVAL mientras haya objetivo en alcance.
## Con objetivo fijado la nave siempre apunta a él (no gira "sin sentido" al moverse).

signal died

var ship_id := ""
var ship_class := ""
var stats: Dictionary = {}
var hull := 1.0
var hull_max := 1.0
var shield := 1.0
var shield_max := 1.0
var since_damage := 99.0
var heading := 0.0
var move_target := Vector2.ZERO
var has_move_target := false
var target: Entity = null
var firing := false

var lasers: Array = []          # [{id, def, level, count, stack, last_target}]
var volley_timer := 0.4
var energy := 100.0             # para impulso
var boost_time := 0.0
var boost_cd := 0.0
var ability_id := ""
var ability_cd := 0.0
var buffs: Dictionary = {}      # nombre -> segundos restantes
var invulnerable := false
var thrust_anim := 0.0
var external_pull := Vector2.ZERO  # tirón de pozos gravitatorios enemigos
var warn_timer := 0.0           # aviso de voz de casco crítico
var shield_was_up := true
var marked: Entity = null       # objetivo marcado por el dron (Pet-Marker)
var marked_time := 0.0


func setup(p_sector: Sector) -> void:
	sector = p_sector
	ship_id = GameState.data["current_ship"]
	var def: Dictionary = GameData.SHIPS[ship_id]
	ship_class = def["class"]
	stats = GameState.ship_stats(ship_id)
	hull_max = stats["hull"]
	hull = hull_max
	shield_max = stats["shield"]
	shield = shield_max
	radius = 34.0 + (10.0 if ship_class in ["tanque", "batalla"] else 0.0)
	height = 22.0
	ability_id = def.get("ability", GameData.SHIP_CLASSES[ship_class]["ability"])
	for l in GameState.equipped_lasers(ship_id):
		lasers.append({"id": l["id"], "def": l["def"], "level": l["level"], "count": 0, "stack": 0, "last_target": null})


func max_speed() -> float:
	var s: float = stats["speed"] * GameData.SPEED_UNIT
	if buffs.has("afterburner"):
		s *= 1.6
	if buffs.has("boost_item"):
		s *= 1.4
	if buffs.has("anchor"):
		s *= 0.65
	if buffs.has("slowed"):
		s *= 0.6
	return s


func _process(delta: float) -> void:
	if not alive:
		return
	_tick_buffs(delta)
	_move(delta)
	_shield(delta)
	_fire(delta)
	_warnings(delta)
	energy = minf(100.0, energy + 14.0 * delta)
	boost_cd = maxf(0.0, boost_cd - delta)
	ability_cd = maxf(0.0, ability_cd - delta)
	marked_time = maxf(0.0, marked_time - delta)
	since_damage += delta
	thrust_anim += delta
	sync_screen()
	queue_redraw()


func _tick_buffs(delta: float) -> void:
	for k in buffs.keys():
		buffs[k] -= delta
		if buffs[k] <= 0.0:
			buffs.erase(k)
	invulnerable = buffs.has("phase")


func _move(delta: float) -> void:
	var desired := Vector2.ZERO
	if has_move_target:
		var to := move_target - plane_pos
		var dist := to.length()
		if dist < 8.0:
			has_move_target = false
		else:
			desired = to / dist * clampf(dist / 120.0, 0.25, 1.0)
	var top := max_speed()
	if boost_time > 0.0:
		boost_time -= delta
		top *= 2.6
		if desired == Vector2.ZERO:
			desired = Vector2.from_angle(heading)
	var accel: float = 900.0 * stats["accel"] * (1.6 if ship_class == "caza" else 1.0)
	velocity = velocity.move_toward(desired * top, accel * delta)
	plane_pos += (velocity + external_pull) * delta
	external_pull = external_pull.move_toward(Vector2.ZERO, 500.0 * delta)
	plane_pos = sector.constrain(plane_pos, radius)
	# Con objetivo fijado la proa apunta siempre al objetivo; si no, hacia donde se mueve.
	var face_dir := velocity
	if target_valid():
		face_dir = target.plane_pos - plane_pos
	if face_dir.length() > 5.0:
		var turn: float = 9.0 * stats["turn"]
		heading = lerp_angle(heading, face_dir.angle(), clampf(turn * delta, 0.0, 1.0))


func _shield(delta: float) -> void:
	var regen: float = stats["shield_regen"]
	if since_damage > float(stats["recharge_delay"]):
		shield = minf(shield_max_now(), shield + shield_max * GameData.SHIELD_RECHARGE_RATE * float(stats["recharge"]) * delta)
		if float(stats["hull_regen"]) > 0.0:
			hull = minf(hull_max, hull + hull_max * float(stats["hull_regen"]) * delta)
	elif regen > 0.0 and since_damage > 1.5:
		shield = minf(shield_max_now(), shield + shield_max * regen * delta)


func _warnings(delta: float) -> void:
	# Voz robótica: casco crítico (se repite mientras siga bajo) y escudos agotados.
	warn_timer = maxf(0.0, warn_timer - delta)
	if hull / hull_max < 0.3 and warn_timer <= 0.0:
		warn_timer = 7.0
		Sfx.voice("low_hull", true)
	if shield <= 1.0 and shield_was_up:
		shield_was_up = false
		if hull / hull_max >= 0.3:
			Sfx.voice("shield_down")
	elif shield > shield_max * 0.5:
		shield_was_up = true


func shield_max_now() -> float:
	return shield_max * (1.35 if buffs.has("anchor") else 1.0)


func target_valid() -> bool:
	return target != null and is_instance_valid(target) and target.alive


func volley_interval() -> float:
	var mult := 1.0
	if buffs.has("overcharge"):
		mult = 1.4
	if buffs.has("prismatic"):
		mult = 1.6
	return GameData.VOLLEY_INTERVAL / mult


func _fire(delta: float) -> void:
	if not target_valid():
		target = null
	volley_timer = maxf(0.0, volley_timer - delta)
	firing = target != null and plane_pos.distance_to(target.plane_pos) <= GameData.LASER_RANGE
	if not firing or volley_timer > 0.0 or lasers.is_empty():
		return
	# Sólo dispara cuando la proa ya apunta al objetivo (evita disparos "de lado").
	var aim := (target.plane_pos - plane_pos).angle()
	if absf(angle_difference(heading, aim)) > 0.6:
		return
	var cost := 0.0
	for l in lasers:
		cost += 1.2 if l["def"]["effect"] == "pull" else 1.0
	if not sector.consume_ammo(cost):
		volley_timer = 0.5
		return
	volley_timer = volley_interval()
	for i in lasers.size():
		_shoot_laser(i, lasers[i])
	if not lasers.is_empty():
		Sfx.play("laser_" + lasers[0]["id"], plane_pos, -2.0)


func _shoot_laser(i: int, l: Dictionary) -> void:
	var def: Dictionary = l["def"]
	var dmg: float = GameState.laser_volley_damage(def, l["level"])
	dmg *= sector.active_ammo_mult() * float(stats["dmg"])
	if buffs.has("barrage"):
		dmg *= 1.3
	if target is Enemy and (target as Enemy).is_elite:
		dmg *= 1.0 + float(stats["elite_dmg"])
	if marked == target and marked_time > 0.0:
		dmg *= 1.03
	l["count"] += 1
	if l["last_target"] != target:
		l["stack"] = 0
		l["last_target"] = target
	var info := {"effect": def["effect"], "color": def["color"]}
	if randf() < float(stats["crit"]):
		dmg *= 2.0
		info["crit"] = true
	match def["effect"]:
		"cadence":
			if l["count"] % 4 == 0:
				dmg *= 2.0
				info["crit"] = true
		"resonance":
			l["stack"] = mini(l["stack"] + 1, 6)
			dmg *= 1.0 + 0.03 * l["stack"]
		"oblivion":
			if l["count"] % 10 == 0:
				info["explode"] = dmg * 3.0
	# Punto de salida: monturas repartidas a lo largo del casco.
	var n := lasers.size()
	var side := (float(i) - (n - 1) * 0.5) * 10.0
	var origin := plane_pos + Vector2.from_angle(heading) * radius * 0.6 + Vector2.from_angle(heading + PI * 0.5) * side
	var shots: int = def["shots"]
	if def["effect"] == "scatter":
		var base_dir := (target.plane_pos - origin).normalized()
		for s in shots:
			var ang := (float(s) - 2.0) * 0.14
			sector.spawn_player_bolt(origin, null, dmg, info, base_dir.rotated(ang))
	else:
		var dist := origin.distance_to(target.plane_pos)
		for s in shots:
			var off := Vector2.from_angle(heading + PI * 0.5) * (float(s) - (shots - 1) * 0.5) * 9.0
			var shot_dmg := dmg
			# Twin Pulse: peor precisión a distancia (el segundo rayo falla más allá del 60% del alcance).
			if def["effect"] == "twin" and s == 1 and dist > GameData.LASER_RANGE * 0.6:
				shot_dmg = 0.0
			sector.spawn_player_bolt(origin + off, target, shot_dmg, info)
	if def["effect"] == "echo" and randf() < 0.15:
		sector.spawn_player_bolt(origin, target, dmg, info)


func try_boost() -> void:
	if boost_cd > 0.0 or energy < 35.0:
		return
	energy -= 35.0
	boost_time = 0.35
	boost_cd = 2.5 * float(stats["boost_cd"])
	Sfx.play("boost")
	sector.fx_ring(plane_pos, 50.0, Color(0.5, 0.9, 1.0, 0.8))


func try_ability() -> void:
	if ability_cd > 0.0:
		return
	var ab: Dictionary = GameData.ABILITIES[ability_id]
	ability_cd = ab["cd"]
	match ability_id:
		"bulwark":
			shield = minf(shield_max_now(), shield + shield_max * 0.3)
		"magnet", "compressor":
			buffs["magnet"] = ab["dur"]
		"gravity_well":
			sector.gravity_well(plane_pos, 420.0, ab["dur"])
		_:
			buffs[ability_id] = ab["dur"]
	Sfx.play("ability")
	sector.fx_ring(plane_pos, 90.0, UiTheme.ACCENT)
	sector.hud.toast(ab["name"])


func pickup_radius() -> float:
	var drone_bonus := sector.drone.pickup_bonus() if sector.drone else 1.0
	return 110.0 * drone_bonus * (4.0 if buffs.has("magnet") else 1.0)


func take_damage(amount: float) -> void:
	if not alive or invulnerable:
		return
	since_damage = 0.0
	var s := minf(shield, amount)
	shield -= s
	var rest := amount - s
	if rest > 0.0:
		hull -= rest
		sector.hud.flash_damage()
		Sfx.play("hit_hull", null, -3.0)
	else:
		Sfx.play("hit_shield", null, -6.0)
	if hull <= 0.0:
		hull = 0.0
		alive = false
		visible = false   # la nave desaparece: sólo queda la explosión
		sector.ship_explosion(plane_pos, radius * 1.6)
		died.emit()


func repair(frac: float) -> void:
	hull = minf(hull_max, hull + hull_max * frac)


func _draw() -> void:
	draw_shadow(radius * 0.9)
	var col := Color("b8c8e0")
	if invulnerable:
		col.a = 0.4
	var pts: Array = Shapes.PLAYER.get(ship_class, Shapes.PLAYER["caza"])
	# Llama del motor
	var moving := velocity.length() > 20.0
	if moving:
		var flick := 0.8 + 0.2 * sin(thrust_anim * 40.0)
		var boost := boost_time > 0.0 or buffs.has("afterburner")
		var move_ang := velocity.angle()
		draw_set_transform_matrix(Iso.shape_matrix(move_ang, height, radius))
		var fl := (1.6 if boost else 1.1) * flick
		draw_colored_polygon(PackedVector2Array([Vector2(-0.7, 0.18), Vector2(-0.7 - fl * 0.6, 0), Vector2(-0.7, -0.18)]), Color(0.4, 0.9, 1.0, 0.8))
		draw_set_transform_matrix(Transform2D.IDENTITY)
	var tex := SpriteLib.get_tex("ships", ship_id)
	if tex == null:
		tex = SpriteLib.get_tex("ships", ship_class)
	if tex:
		SpriteLib.draw(self, tex, radius, heading, height, Color(1, 1, 1, col.a))
	else:
		Shapes.draw_hull(self, pts, radius, heading, height, col.darkened(0.25), col, Color("4affff"))
	# Burbuja de escudo
	if shield > 1.0:
		var a := 0.08 + 0.25 * clampf(1.0 - since_damage * 2.0, 0.0, 1.0)
		draw_ring(radius * 1.25, Color(0.3, 0.8, 1.0, a + 0.1), 2.0, height)
	if buffs.has("anchor"):
		draw_ring(radius * 1.5, Color(0.4, 0.8, 1.0, 0.7), 3.0, height)
