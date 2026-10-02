class_name Enemy
extends Entity
## Alienígena genérico: los datos vienen del bestiario y la IA del arquetipo (15.6).

var id := ""
var def: Dictionary = {}
var variant := "base"
var level := 1
var hp := 1.0
var hp_max := 1.0
var dmg := 1.0
var speed := 100.0
var arch := ""
var heading := 0.0
var home := Vector2.ZERO
var aggro := false
var is_nest := false
var is_elite := false

var attack_timer := 1.0
var state := "idle"
var state_time := 0.0
var charge_dir := Vector2.ZERO
var strafe_sign := 1.0
var spawn_timer := 6.0
var spawned := 0
var next_spawn_hp := 0.8
var flash := 0.0
var anim := 0.0

# Estados aplicados por el jugador
var burn_dps := 0.0
var burn_time := 0.0
var slow := 0.0
var slow_time := 0.0
var weaken_time := 0.0
var pull_vel := Vector2.ZERO


func setup(p_sector: Sector, p_id: String, p_level: int, p_variant: String, pos: Vector2) -> void:
	sector = p_sector
	id = p_id
	level = p_level
	variant = p_variant
	plane_pos = pos
	home = pos
	if id == "nest":
		is_nest = true
		def = {"name": "Nido Ferron", "arch": "nest", "hp": 6000, "dmg": 0, "vel": 0, "size": 48, "shape": "nest", "color": Color("4a3428"), "accent": Color("ff7a2a"), "credits": 3500, "drops": {"ferrita": 40, "oro": 6, "titanio": 10}, "nexo": 0.004}
	else:
		def = GameData.ENEMIES[id]
	var v: Dictionary = GameData.VARIANTS[variant]
	arch = def["arch"]
	hp_max = GameData.level_hp(float(def["hp"]), level) * float(v["hp"])
	hp = hp_max
	dmg = GameData.level_dmg(float(def["dmg"]), level) * float(v["dmg"])
	speed = float(def["vel"]) * GameData.SPEED_UNIT * 0.75
	radius = float(def["size"]) * float(v["scale"]) * 1.35
	height = 0.0 if is_nest else 14.0 + radius * 0.2
	is_elite = variant != "base" or arch == "mother"
	attack_timer = randf_range(0.8, 2.5)
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	heading = randf() * TAU
	anim = randf() * 10.0
	sync_screen()


func display_name() -> String:
	var v: String = GameData.VARIANTS[variant]["name"]
	return ("%s %s" % [v, def["name"]]).strip_edges()


func _process(delta: float) -> void:
	if not alive:
		return
	anim += delta
	flash = maxf(0.0, flash - delta * 4.0)
	_statuses(delta)
	var p := sector.player
	var dist := plane_pos.distance_to(p.plane_pos) if p.alive else 99999.0
	if not aggro and not sector.showcase and (dist < 700.0 or sector.alert >= 3.0):
		aggro = true
	var move := Vector2.ZERO
	if aggro and p.alive:
		move = _behave(delta, p, dist)
	else:
		move = _wander(delta)
	var spd := speed * (1.0 - slow)
	if state == "dash":
		spd = speed * 4.0
	velocity = velocity.move_toward(move * spd, 600.0 * delta)
	plane_pos += (velocity + pull_vel) * delta
	pull_vel = pull_vel.move_toward(Vector2.ZERO, 400.0 * delta)
	plane_pos = sector.constrain(plane_pos, radius)
	var face := velocity if state != "aim" else (p.plane_pos - plane_pos)
	if aggro and arch in ["harasser", "artillery", "tank", "hunter", "support"]:
		face = p.plane_pos - plane_pos
	if face.length() > 1.0 and not is_nest:
		heading = lerp_angle(heading, face.angle(), clampf(6.0 * delta, 0.0, 1.0))
	sync_screen()
	queue_redraw()


func _statuses(delta: float) -> void:
	if burn_time > 0.0:
		burn_time -= delta
		_apply_damage(burn_dps * delta, false)
		if burn_time <= 0.0:
			burn_dps = 0.0
	if slow_time > 0.0:
		slow_time -= delta
		if slow_time <= 0.0:
			slow = 0.0
	weaken_time = maxf(0.0, weaken_time - delta)


func out_dmg() -> float:
	return dmg * (0.9 if weaken_time > 0.0 else 1.0)


func _wander(_delta: float) -> Vector2:
	if is_nest:
		return Vector2.ZERO
	var to := home + Vector2(cos(anim * 0.4), sin(anim * 0.3)) * 120.0 - plane_pos
	return to.normalized() * 0.35 if to.length() > 10.0 else Vector2.ZERO


func _keep_distance(p: PlayerShip, dist: float, want: float, strafe: float) -> Vector2:
	var to := (p.plane_pos - plane_pos) / maxf(dist, 1.0)
	var radial := clampf((dist - want) / 150.0, -1.0, 1.0)
	return (to * radial + to.orthogonal() * strafe * strafe_sign).limit_length(1.0)


func _shoot_at(p: PlayerShip, bullet_speed: float, size: float, mult: float = 1.0, spread: float = 0.0) -> void:
	var lead := p.plane_pos + p.velocity * (plane_pos.distance_to(p.plane_pos) / bullet_speed) * 0.5
	var dir := (lead - plane_pos).normalized().rotated(randf_range(-spread, spread))
	sector.spawn_enemy_bullet(plane_pos + dir * radius, dir, bullet_speed, out_dmg() * mult, size, def["accent"])


func _behave(delta: float, p: PlayerShip, dist: float) -> Vector2:
	attack_timer -= delta
	state_time += delta
	match arch:
		"harasser":
			if attack_timer <= 0.0 and dist < 600.0:
				attack_timer = 1.6
				_shoot_at(p, 420.0, 6.0)
			return _keep_distance(p, dist, 340.0, 0.6)
		"swarm":
			if attack_timer <= 0.0 and dist < 380.0:
				attack_timer = 1.3
				_shoot_at(p, 380.0, 5.0, 1.0, 0.15)
			return _keep_distance(p, dist, 130.0, 0.9)
		"tank":
			if state == "aim":
				if state_time > 0.7:
					state = "move"
					for k in 3:
						_shoot_at(p, 300.0, 10.0, 0.6, 0.25)
				return Vector2.ZERO
			if attack_timer <= 0.0 and dist < 520.0:
				attack_timer = 2.6
				state = "aim"
				state_time = 0.0
			return _keep_distance(p, dist, 200.0, 0.1)
		"hunter":
			if attack_timer <= 0.0 and dist < 450.0:
				attack_timer = 1.0
				_shoot_at(p, 520.0, 5.0)
			var flank := p.plane_pos + Vector2.from_angle(p.heading + PI * 0.5 * strafe_sign) * 230.0
			return (flank - plane_pos).normalized() if plane_pos.distance_to(flank) > 30.0 else Vector2.ZERO
		"charger":
			return _charger(p, dist)
		"support":
			if attack_timer <= 0.0:
				attack_timer = 3.0
				sector.heal_allies(self, 260.0, 0.08)
			var ally := sector.nearest_ally(self)
			if ally:
				var to := ally.plane_pos - plane_pos
				return to.normalized() * 0.8 if to.length() > 120.0 else _keep_distance(p, dist, 400.0, 0.3) * 0.5
			return _keep_distance(p, dist, 420.0, 0.4)
		"miner":
			if state == "arming":
				if state_time >= 1.0:
					sector.explode(plane_pos, 140.0, out_dmg(), def["accent"], self)
					die(false)
				return Vector2.ZERO
			if dist < 95.0:
				state = "arming"
				state_time = 0.0
			return (p.plane_pos - plane_pos).normalized()
		"artillery":
			if attack_timer <= 0.0 and dist < 750.0:
				attack_timer = 3.2
				var aim := p.plane_pos + p.velocity * 1.0
				sector.telegraph_circle(aim, 115.0, 1.3, out_dmg(), def["accent"])
			return _keep_distance(p, dist, 520.0, 0.3)
		"mother":
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = 7.0
				_spawn_children(2)
			if attack_timer <= 0.0 and dist < 600.0:
				attack_timer = 2.0
				for k in 2:
					_shoot_at(p, 340.0, 8.0, 0.8, 0.3)
			return _keep_distance(p, dist, 300.0, 0.2)
		"nest":
			spawn_timer -= delta
			if spawn_timer <= 0.0 and spawned < 10:
				spawn_timer = 9.0 - minf(sector.alert, 4.0)
				sector.spawn_group_near(plane_pos, 2, level)
				spawned += 2
			return Vector2.ZERO
	return Vector2.ZERO


func _charger(p: PlayerShip, dist: float) -> Vector2:
	match state:
		"aim":
			charge_dir = (p.plane_pos - plane_pos).normalized()
			if state_time > 0.9:
				state = "dash"
				state_time = 0.0
			return Vector2.ZERO
		"dash":
			if plane_pos.distance_to(p.plane_pos) < radius + p.radius:
				p.take_damage(out_dmg() * 1.5)
				sector.fx_ring(p.plane_pos, 60.0, def["accent"])
				state = "recover"
				state_time = 0.0
			elif state_time > 0.6:
				state = "recover"
				state_time = 0.0
			return charge_dir
		"recover":
			if state_time > 1.2:
				state = "move"
			return Vector2.ZERO
	if attack_timer <= 0.0 and dist < 480.0:
		attack_timer = 3.5
		state = "aim"
		state_time = 0.0
	return _keep_distance(p, dist, 380.0, 0.4)


func _spawn_children(n: int) -> void:
	var child: String = def.get("spawns", "chatarrax")
	for i in n:
		var e := sector.spawn_enemy(child, plane_pos + Vector2.from_angle(randf() * TAU) * radius * 1.2, level, "base")
		e.aggro = true


## Recibe un impacto del jugador con los efectos del láser.
func take_hit(amount: float, info: Dictionary) -> void:
	if not alive:
		return
	aggro = true
	match info.get("effect", ""):
		"burn":
			burn_dps = minf(burn_dps + amount * 0.15, amount * 0.75)
			burn_time = 3.0
		"slow":
			slow = minf(0.18, slow + 0.06)
			slow_time = 2.0
		"weaken":
			weaken_time = 3.0
		"siege":
			if radius >= 35.0:
				amount *= 1.2
		"pull":
			pull_vel += (sector.player.plane_pos - plane_pos).normalized() * (-120.0)
		"pierce_armor":
			if arch in ["tank"]:
				amount *= 1.12
	_apply_damage(amount, info.get("crit", false))
	if info.has("explode"):
		sector.player_explosion(plane_pos, 150.0, info["explode"])
	if arch == "mother" and hp / hp_max < next_spawn_hp and alive:
		next_spawn_hp -= 0.2
		_spawn_children(3)


func _apply_damage(amount: float, crit: bool) -> void:
	if amount <= 0.0 or not alive:
		return
	hp -= amount
	flash = 1.0
	if amount >= 1.0 and randf() < 0.6:
		sector.fx_number(plane_pos, amount, crit)
	if hp <= 0.0:
		die(true)


func die(by_player: bool) -> void:
	if not alive:
		return
	alive = false
	sector.on_enemy_killed(self, by_player)
	queue_free()


func _draw() -> void:
	var v: Dictionary = GameData.VARIANTS[variant]
	draw_shadow(radius * 0.9, 0.3)
	if variant != "base":
		var pulse := 0.6 + 0.4 * sin(anim * 4.0)
		draw_ring(radius * 1.35, Color(v["color"], 0.5 * pulse), 3.0, height)
	var fill: Color = def["color"]
	var edge: Color = fill.lightened(0.35)
	if flash > 0.0:
		fill = fill.lerp(Color.WHITE, flash * 0.6)
	if state == "arming" and int(anim * 10.0) % 2 == 0:
		fill = Color("ff3a3a")
	var pts: Array = Shapes.ENEMY.get(def["shape"], Shapes.ENEMY["oval"])
	var rot := heading
	if is_nest:
		rot = anim * 0.3
	var tex := SpriteLib.get_tex("enemies", id)
	if tex:
		SpriteLib.draw(self, tex, radius, rot, height, Color.WHITE.lerp(Color(3, 3, 3), flash * 0.3))
	else:
		Shapes.draw_hull(self, pts, radius, rot, height, fill, edge, def["accent"])
	# Telegraph de embestida: línea de advertencia.
	if state == "aim" and arch == "charger":
		var a := Iso.to_screen(charge_dir * 520.0)
		draw_line(Vector2(0, -height), a + Vector2(0, -height), Color(1, 0.2, 0.2, 0.25 + 0.5 * state_time), 6.0)
	if state == "aim" and arch == "tank":
		draw_circle(Vector2(0, -height), radius * 0.4 * state_time / 0.7, Color(def["accent"], 0.7))
	if state == "arming":
		draw_ring(140.0 * clampf(state_time, 0.0, 1.0), Color(1, 0.2, 0.2, 0.7), 2.0)
		draw_ring(140.0, Color(1, 0.2, 0.2, 0.3), 1.0)
	if burn_time > 0.0:
		draw_circle(Vector2(randf_range(-6, 6), -height - randf_range(0, 10)), 3.0, Color(1, 0.5, 0.1, 0.8))
	# Selección y barra de vida
	var selected: bool = sector.player.target == self
	if selected:
		draw_ring(radius * 1.5, Color(1, 0.3, 0.3, 0.9), 2.0)
	if selected or hp < hp_max or is_elite:
		var top := -height - radius * 0.8 - 12.0
		draw_bar(top, maxf(40.0, radius * 1.6), hp / hp_max, Color("ff4a4a") if not is_elite else v["color"] if variant != "base" else Color("ffb84a"))
