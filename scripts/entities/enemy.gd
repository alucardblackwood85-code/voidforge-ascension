class_name Enemy
extends Entity
## Alienígena genérico: los datos vienen del bestiario y la IA del arquetipo (15.6).
## Arquetipos: harasser, swarm, tank, hunter, charger, support, miner, artillery, mother, nest,
## drainer, ambusher, defender, sniper, elite, control, trap.

const FACTION_SHOT := {
	"ferron": "e_shot_light", "vesper": "e_shot_bio", "prismaticos": "e_shot_crystal",
	"vacio": "e_shot_void", "leviatan": "e_shot_bio",
}

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
var shot_sfx := "e_shot_light"
var attack_range := 450.0

var attack_timer := 1.0
var ability_timer := 5.0
var state := "idle"
var state_time := 0.0
var charge_dir := Vector2.ZERO
var strafe_sign := 1.0
var spawn_timer := 6.0
var spawned := 0
var next_spawn_hp := 0.8
var flash := 0.0
var anim := 0.0
var phased := false        # emboscador: casi invisible y con daño reducido
var reflecting := 0.0      # defensor: ventana de reflejo visible
var draining := false      # drenador: haz conectado al jugador
var drain_tick := 0.0
var aim_point := Vector2.ZERO
# M8: escudo enemigo (regenera; su blindaje plano por impacto hace que la munición x3-x6 importe)
var shield := 0.0
var shield_max := 0.0
var shield_armor := 0.0
var since_hit := 99.0
# M9: afijos de élite
var affixes: Array = []
var atk_mult := 1.0
var dmg_taken_mult := 1.0
var affix_timer := 4.0
var swarmed := false
var phase_t := 0.0          # afijo Fásico: segundos de fase restantes
var leash_t := 0.0          # segundos con el jugador lejos (abandona la persecución a los 5 s)
# M6: jefe con fases
var is_boss := false
var boss_phase := 1
var boss_spiral := 3.0
var boss_zone := 5.0
var boss_summon := 8.0

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
		def = {"name": "Nido " + sector.biome.get("faction", "alienígena"), "arch": "nest", "hp": 6000, "dmg": 0, "vel": 0, "size": 48, "shape": "nest", "color": Color("4a3428"), "accent": Color("ff7a2a"), "credits": 3500, "drops": sector.biome["resources"].duplicate(), "nexo": 0.004}
		for k in def["drops"].keys():
			def["drops"][k] = maxi(1, int(def["drops"][k]) / 2)
	else:
		def = GameData.ENEMIES[id]
	var v: Dictionary = GameData.VARIANTS[variant]
	arch = def["arch"]
	hp_max = GameData.level_hp(float(def["hp"]), sector.eff_level) * float(v["hp"]) * GameData.ENEMY_HP_MULT
	hp = hp_max
	dmg = GameData.level_dmg(float(def["dmg"]), sector.eff_level) * float(v["dmg"]) * GameData.ENEMY_DMG_MULT
	# M9: Ascensión (vida x2^A, daño x1,55^A).
	if sector.asc > 0:
		hp_max *= pow(2.0, sector.asc)
		hp = hp_max
		dmg *= pow(1.55, sector.asc)
	dmg *= float(sector.mod.get("enemy_dmg", 1.0))
	# Alcance de disparo propio de cada especie (arquetipo ± pequeña variación estable por especie).
	attack_range = float(def.get("range", GameData.ARCH_RANGE.get(def["arch"], 450.0))) * (0.92 + 0.16 * float(abs(hash(id)) % 100) / 100.0)
	speed = float(def["vel"]) * GameData.SPEED_UNIT * 0.75
	radius = float(def["size"]) * float(v["scale"]) * 1.35
	height = 0.0 if is_nest or arch == "trap" else 14.0 + radius * 0.2
	is_elite = variant != "base" or arch in ["mother", "elite"]
	attack_timer = randf_range(0.8, 2.5)
	ability_timer = randf_range(3.0, 6.0)
	strafe_sign = 1.0 if randf() < 0.5 else -1.0
	heading = randf() * TAU
	anim = randf() * 10.0
	shot_sfx = "e_shot_swarm" if arch == "swarm" else FACTION_SHOT.get(sector.biome_id, "e_shot_light")
	_setup_shield()
	# Los afijos llegan a partir del nivel 5 (antes castigaban demasiado al jugador nuevo).
	if level >= 5:
		_roll_affixes({"boss": 1, "mega": 2, "ultra": randi_range(2, 3), "uber": 3}.get(variant, 0))
	sync_screen()


## Al detectar al jugador avisa a su grupo cercano (los enemigos atacan en manada).
func set_aggro() -> void:
	if aggro:
		return
	aggro = true
	# Avisa sólo a los vecinos directos (sin cadena: antes se activaba medio mapa en cascada).
	for e in sector.enemies:
		if e != self and not e.aggro and not e.is_nest and e.plane_pos.distance_to(plane_pos) < 350.0:
			e.aggro = true


func display_name() -> String:
	var v: String = GameData.VARIANTS[variant]["name"]
	return ("%s %s" % [v, def["name"]]).strip_edges()


func sfx(name: String, vol: float = 0.0) -> void:
	Sfx.play(name, plane_pos, vol)


func _process(delta: float) -> void:
	if not alive:
		return
	var p := sector.player
	var dist := plane_pos.distance_to(p.plane_pos) if p.alive else 99999.0
	# Enemigos lejanos e inactivos: no se dibujan ni piensan (mapa grande).
	if not aggro and dist > 2400.0:
		visible = false
		return
	visible = true
	anim += delta
	flash = maxf(0.0, flash - delta * 4.0)
	reflecting = maxf(0.0, reflecting - delta)
	_statuses(delta)
	if not alive:
		return
	_affix_tick(delta, p, dist)
	if is_boss and aggro and p.alive:
		_boss_tick(delta, p, dist)
	# Detección: 700 u, +80 u por nivel de alerta (antes, con alerta 3 se activaba todo el mapa).
	if not aggro and not sector.showcase and dist < 700.0 + 80.0 * sector.alert:
		set_aggro()
	# Abandona la persecución si el jugador se aleja (permite retirarse a recargar escudo).
	if aggro and not is_nest and not has_meta("objective"):
		if dist > 1500.0:
			leash_t += delta
			if leash_t > 5.0:
				aggro = false
				leash_t = 0.0
				draining = false
				_set_state("move")
		else:
			leash_t = 0.0
	var move := Vector2.ZERO
	if aggro and p.alive:
		move = _behave(delta, p, dist)
	else:
		move = _wander(delta)
		draining = false
	var spd := speed * (1.0 - slow)
	if state == "dash":
		spd = speed * 4.0
	velocity = velocity.move_toward(move * spd, 600.0 * delta)
	plane_pos += (velocity + pull_vel) * delta
	pull_vel = pull_vel.move_toward(Vector2.ZERO, 400.0 * delta)
	plane_pos = sector.constrain(plane_pos, radius)
	# Con el jugador detectado, todos miran hacia él salvo durante embestidas, fase o retirada.
	var face := velocity
	if aggro and p.alive and not (state in ["dash", "phase", "retreat"]) and arch != "miner":
		face = p.plane_pos - plane_pos
	elif state == "aim":
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
	return dmg * (0.9 if weaken_time > 0.0 else 1.0) * _aura_mult()


func _wander(_delta: float) -> Vector2:
	if is_nest:
		return Vector2.ZERO
	var to := home + Vector2(cos(anim * 0.4), sin(anim * 0.3)) * 120.0 - plane_pos
	return to.normalized() * 0.35 if to.length() > 10.0 else Vector2.ZERO


func _keep_distance(p: PlayerShip, dist: float, want: float, strafe: float) -> Vector2:
	var to := (p.plane_pos - plane_pos) / maxf(dist, 1.0)
	var radial := clampf((dist - want) / 150.0, -1.0, 1.0)
	return (to * radial + to.orthogonal() * strafe * strafe_sign).limit_length(1.0)


func _shoot_at(p: PlayerShip, bullet_speed: float, size: float, mult: float = 1.0, spread: float = 0.0, sound: bool = true) -> void:
	var lead := p.plane_pos + p.velocity * (plane_pos.distance_to(p.plane_pos) / bullet_speed) * 0.5
	var aim_dir := (lead - plane_pos).normalized()
	# La proa se orienta al disparar y la bala sale del frente, a la altura visual del enemigo.
	heading = aim_dir.angle()
	var dir := aim_dir.rotated(randf_range(-spread, spread))
	# Disparos teledirigidos: persiguen a la nave con giro limitado y duran lo justo para su alcance.
	sector.spawn_enemy_bullet(plane_pos + aim_dir * radius * 0.9, dir, bullet_speed, out_dmg() * mult, size, def["accent"], height, attack_range * 1.35 / bullet_speed)
	if sound:
		sfx(shot_sfx, -4.0)
	if affixes.has("vampirico"):
		hp = minf(hp_max, hp + out_dmg() * mult * 0.5)


func _set_state(s: String) -> void:
	state = s
	state_time = 0.0


func _behave(delta: float, p: PlayerShip, dist: float) -> Vector2:
	attack_timer -= delta * atk_mult
	ability_timer -= delta
	state_time += delta
	match arch:
		"harasser":
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 1.6
				_shoot_at(p, 520.0, 6.0)
			return _keep_distance(p, dist, attack_range * 0.7, 0.6)
		"swarm":
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 1.3
				_shoot_at(p, 480.0, 5.0, 1.0, 0.15)
			return _keep_distance(p, dist, 130.0, 0.9)
		"tank":
			if state == "aim":
				if state_time > 0.7:
					_set_state("move")
					sfx("e_heavy")
					for k in 3:
						_shoot_at(p, 300.0, 10.0, 0.6, 0.25, false)
				return Vector2.ZERO
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 2.6
				_set_state("aim")
			return _keep_distance(p, dist, 200.0, 0.1)
		"hunter":
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 1.0
				_shoot_at(p, 600.0, 5.0)
			var flank := p.plane_pos + Vector2.from_angle(p.heading + PI * 0.5 * strafe_sign) * 230.0
			return (flank - plane_pos).normalized() if plane_pos.distance_to(flank) > 30.0 else Vector2.ZERO
		"charger":
			return _charger(p, dist)
		"support":
			if attack_timer <= 0.0:
				attack_timer = 3.0
				if sector.heal_allies(self, 260.0, 0.08) > 0:
					sfx("e_heal", -4.0)
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
				_set_state("arming")
				sfx("e_arm")
			return (p.plane_pos - plane_pos).normalized()
		"artillery":
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 3.2
				var aim := p.plane_pos + p.velocity * 1.0
				sector.telegraph_circle(aim, 115.0, 1.3, out_dmg(), def["accent"])
				sfx("e_launch", -2.0)
			return _keep_distance(p, dist, attack_range * 0.7, 0.3)
		"mother":
			spawn_timer -= delta
			if spawn_timer <= 0.0:
				spawn_timer = 7.0
				_spawn_children(2)
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 2.0
				sfx("e_heavy", -3.0)
				for k in 2:
					_shoot_at(p, 340.0, 8.0, 0.8, 0.3, false)
			return _keep_distance(p, dist, 300.0, 0.2)
		"nest":
			spawn_timer -= delta
			if spawn_timer <= 0.0 and spawned < 10:
				spawn_timer = 9.0 - minf(sector.alert, 4.0)
				sector.spawn_group_near(plane_pos, 2, level)
				spawned += 2
				sfx("e_spawn")
			return Vector2.ZERO
		"drainer":
			return _drainer(delta, p, dist)
		"ambusher":
			return _ambusher(p, dist)
		"defender":
			if ability_timer <= 0.0 and dist < 600.0:
				ability_timer = 6.0
				reflecting = 1.6
				sfx("e_reflect")
			if attack_timer <= 0.0 and dist < attack_range and reflecting <= 0.0:
				attack_timer = 1.8
				_shoot_at(p, 380.0, 8.0)
			return _keep_distance(p, dist, 260.0, 0.2)
		"sniper":
			return _sniper(p, dist)
		"elite":
			if state == "nova":
				if state_time >= 1.0:
					_set_state("move")
					sector.explode(plane_pos, 240.0, out_dmg() * 1.2, def["accent"], self)
				return Vector2.ZERO
			if ability_timer <= 0.0 and dist < 260.0:
				ability_timer = 7.0
				_set_state("nova")
				sfx("e_nova")
				return Vector2.ZERO
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 1.4
				sfx(shot_sfx, -2.0)
				for k in 3:
					_shoot_at(p, 460.0, 7.0, 0.7, 0.22, false)
			return _keep_distance(p, dist, 300.0, 0.5)
		"control":
			if ability_timer <= 0.0 and dist < 460.0:
				ability_timer = 5.0
				sector.fx_ring(plane_pos, 460.0, def["accent"])
				sfx("e_pulse")
				if dist < 460.0:
					p.apply_slow(2.5)
					p.external_pull += (plane_pos - p.plane_pos).normalized() * 260.0
			if attack_timer <= 0.0 and dist < attack_range:
				attack_timer = 2.0
				_shoot_at(p, 360.0, 7.0)
			return _keep_distance(p, dist, 380.0, 0.3)
		"trap":
			# Pozo: atrae lentamente a la nave y daña en el núcleo.
			if dist < 520.0:
				p.external_pull += (plane_pos - p.plane_pos).normalized() * 220.0 * delta * 4.0
				if ability_timer <= 0.0:
					ability_timer = 3.0
					sfx("e_pulse", -6.0)
				if dist < radius + p.radius + 20.0 and attack_timer <= 0.0:
					attack_timer = 0.8
					p.take_damage(out_dmg() * 0.6)
			return (p.plane_pos - plane_pos).normalized() * 0.4
	return Vector2.ZERO


func _charger(p: PlayerShip, dist: float) -> Vector2:
	match state:
		"aim":
			charge_dir = (p.plane_pos - plane_pos).normalized()
			if state_time > 0.9:
				_set_state("dash")
				sfx("e_dash")
			return Vector2.ZERO
		"dash":
			if plane_pos.distance_to(p.plane_pos) < radius + p.radius:
				p.take_damage(out_dmg() * 1.5)
				sector.fx_ring(p.plane_pos, 60.0, def["accent"])
				_set_state("recover")
			elif state_time > 0.6:
				_set_state("recover")
			return charge_dir
		"recover":
			if state_time > 1.2:
				_set_state("move")
			return Vector2.ZERO
	if attack_timer <= 0.0 and dist < 480.0:
		attack_timer = 3.5
		_set_state("aim")
		sfx("e_charge", -3.0)
	return _keep_distance(p, dist, 380.0, 0.4)


func _drainer(delta: float, p: PlayerShip, dist: float) -> Vector2:
	# Se fija en el jugador y roba escudo mientras mantiene el haz (corta a más de 420).
	if draining:
		if dist > 420.0:
			draining = false
		else:
			drain_tick -= delta
			if drain_tick <= 0.0:
				drain_tick = 0.5
				p.take_damage(out_dmg() * 0.3)
				hp = minf(hp_max, hp + out_dmg() * 0.2)
			if state_time > 1.2:
				state_time = 0.0
				sfx("e_drain", -5.0)
		return _keep_distance(p, dist, 240.0, 0.4)
	if dist < 330.0:
		draining = true
		state_time = 0.0
		sfx("e_drain", -3.0)
	return (p.plane_pos - plane_pos).normalized()


func _ambusher(p: PlayerShip, dist: float) -> Vector2:
	match state:
		"phase":
			# Oculto: se acerca por el flanco. Al salir de fase, ráfaga rápida.
			var flank := p.plane_pos + Vector2.from_angle(p.heading + PI * 0.6 * strafe_sign) * 180.0
			if state_time > 2.5 or plane_pos.distance_to(flank) < 40.0:
				phased = false
				_set_state("burst")
				sfx("e_phase", -2.0)
			return (flank - plane_pos).normalized() * 1.3
		"burst":
			if attack_timer <= 0.0:
				attack_timer = 0.22
				_shoot_at(p, 560.0, 5.0, 0.8, 0.1)
			if state_time > 0.9:
				_set_state("retreat")
			return Vector2.ZERO
		"retreat":
			if state_time > 2.0:
				_set_state("move")
			return -(p.plane_pos - plane_pos).normalized()
	if ability_timer <= 0.0 and dist < 700.0:
		ability_timer = 6.5
		phased = true
		_set_state("phase")
		sfx("e_phase", -4.0)
	return _keep_distance(p, dist, 420.0, 0.6)


func _sniper(p: PlayerShip, dist: float) -> Vector2:
	if state == "aim":
		# Sigue al objetivo y se "congela" los últimos 0.35 s: ventana para esquivar.
		if state_time < 1.05:
			aim_point = p.plane_pos
		if state_time >= 1.4:
			_set_state("move")
			sfx("e_snipe_fire")
			var dir := (aim_point - plane_pos).normalized()
			var to_p := p.plane_pos - plane_pos
			var along := to_p.dot(dir)
			var off := absf(to_p.dot(dir.orthogonal()))
			if along > 0.0 and along < 1100.0 and off < p.radius + 18.0:
				p.take_damage(out_dmg() * 2.0)
			sector.ground.add_beam(plane_pos, plane_pos + dir * 1100.0, def["accent"])
		return Vector2.ZERO
	if attack_timer <= 0.0 and dist < attack_range:
		attack_timer = 4.0
		_set_state("aim")
		aim_point = p.plane_pos
		sfx("e_snipe_charge", -3.0)
	return _keep_distance(p, dist, attack_range * 0.75, 0.25)


func _spawn_children(n: int) -> void:
	# Tope de crías por nodriza y de enemigos vivos: sin él la población crecía sin límite.
	if spawned >= 12 or sector.enemies.size() >= GameData.MAX_ENEMIES:
		return
	spawned += n
	var child: String = def.get("spawns", "chatarrax")
	sfx("e_spawn", -2.0)
	for i in n:
		var e := sector.spawn_enemy(child, plane_pos + Vector2.from_angle(randf() * TAU) * radius * 1.2, level, "base")
		e.aggro = true


## Recibe un impacto del jugador con los efectos del láser.
func take_hit(amount: float, info: Dictionary) -> void:
	if not alive:
		return
	set_aggro()
	since_hit = 0.0
	amount *= dmg_taken_mult
	if phased:
		amount *= 0.25
	if reflecting > 0.0:
		# Reflejo: absorbe la mayor parte y devuelve parte del daño (telegrafiado con el anillo).
		sector.player.take_damage(amount * 0.15)
		amount *= 0.3
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
			if arch in ["tank", "defender"]:
				amount *= 1.12
	amount = _absorb(amount, info)
	if amount <= 0.0:
		flash = 0.6
		if randf() < 0.3:
			sector.fx_spark(plane_pos, Color("4ab8ff"))
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
	sector.commanders.erase(self)
	if affixes.has("volatil"):
		sector.telegraph_circle(plane_pos, 170.0, 0.9, dmg * 1.5, AFFIX_COLORS["volatil"])
	if affixes.has("enjambrador"):
		spawned = 0
		_spawn_children(4)
	sector.on_enemy_killed(self, by_player)
	queue_free()


func _draw() -> void:
	var v: Dictionary = GameData.VARIANTS[variant]
	var alpha := 0.18 + 0.1 * sin(anim * 20.0) if phased else 1.0
	draw_shadow(radius * 0.9, 0.3 * alpha)
	if variant != "base":
		var pulse := 0.6 + 0.4 * sin(anim * 4.0)
		draw_ring(radius * 1.35, Color(v["color"], 0.5 * pulse * alpha), 3.0, height)
	var fill: Color = def["color"]
	var edge: Color = fill.lightened(0.35)
	if flash > 0.0:
		fill = fill.lerp(Color.WHITE, flash * 0.6)
	if state == "arming" and int(anim * 10.0) % 2 == 0:
		fill = Color("ff3a3a")
	var pts: Array = Shapes.ENEMY.get(def["shape"], Shapes.ENEMY["oval"])
	var rot := heading
	if is_nest or arch == "trap":
		rot = anim * (0.3 if is_nest else 1.2)
	# Pozo menor: disco de acreción bajo el sprite.
	if arch == "trap":
		draw_ring(radius * 2.2, Color(def["accent"], 0.25), 6.0)
		draw_ring(radius * 1.6, Color(def["accent"], 0.4), 3.0)
	var tex := SpriteLib.get_tex("enemies", id)
	if tex:
		var mod := Color.WHITE.lerp(Color(3, 3, 3), flash * 0.3)
		mod.a = alpha
		SpriteLib.draw(self, tex, radius, rot, height, mod)
	else:
		fill.a = alpha
		Shapes.draw_hull(self, pts, radius, rot, height, fill, edge, def["accent"])
	var eye := Vector2(0, -height)
	var p := sector.player
	# Telegraphs (4.4): todo ataque fuerte se anuncia con 0.5-1.5 s.
	if state == "aim" and arch == "charger":
		var a := Iso.to_screen(charge_dir * 520.0)
		draw_line(eye, a + eye, Color(1, 0.2, 0.2, 0.25 + 0.5 * state_time), 6.0)
	if state == "aim" and arch == "tank":
		draw_circle(eye, radius * 0.4 * state_time / 0.7, Color(def["accent"], 0.7))
	if state == "aim" and arch == "sniper":
		var tgt := Iso.to_screen(aim_point - plane_pos)
		var locked := state_time >= 1.05
		var c := Color(1, 0.9, 0.3, 0.9) if locked else Color(def["accent"], 0.25 + 0.3 * state_time)
		draw_line(eye, tgt + Vector2(0, -16), c, 2.0 if not locked else 3.5)
	if state == "nova":
		draw_ring(240.0 * clampf(state_time, 0.0, 1.0), Color(def["accent"], 0.7), 3.0)
		draw_ring(240.0, Color(def["accent"], 0.3), 1.5)
	if reflecting > 0.0:
		draw_ring(radius * 1.45, Color(0.7, 0.9, 1.0, 0.5 + 0.4 * sin(anim * 30.0)), 4.0, height)
	if draining and p.alive:
		var to := Iso.to_screen(p.plane_pos - plane_pos) + Vector2(0, -p.height)
		var wob := Vector2(sin(anim * 25.0), cos(anim * 21.0)) * 4.0
		draw_polyline(PackedVector2Array([eye, (eye + to) * 0.5 + wob, to]), Color(def["accent"], 0.75), 3.0)
	if state == "arming":
		draw_ring(140.0 * clampf(state_time, 0.0, 1.0), Color(1, 0.2, 0.2, 0.7), 2.0)
		draw_ring(140.0, Color(1, 0.2, 0.2, 0.3), 1.0)
	if burn_time > 0.0:
		draw_circle(Vector2(randf_range(-6, 6), -height - randf_range(0, 10)), 3.0, Color(1, 0.5, 0.1, 0.8))
	# Selección y barra de vida
	var selected: bool = p.target == self
	if selected:
		draw_ring(radius * 1.5, Color(1, 0.3, 0.3, 0.9), 2.0)
		if attack_range > 120.0:
			draw_ring(attack_range, Color(def["accent"], 0.16), 1.5)
	if selected or hp < hp_max or is_elite:
		var top := -height - radius * 0.8 - 12.0
		var bar_col := Color("ff4a4a")
		if variant != "base":
			bar_col = v["color"]
		elif is_elite:
			bar_col = Color("ffb84a")
		var w := maxf(40.0, radius * 1.6)
		draw_bar(top, w, hp / hp_max, bar_col)
		if shield_max > 0.0:
			draw_bar(top - 7.0, w, shield / shield_max, Color("4ab8ff"))
		# Afijos: una gema de color por afijo sobre las barras.
		for i in affixes.size():
			var x := -w * 0.5 + 5.0 + i * 11.0
			draw_circle(Vector2(x, top - (16.0 if shield_max > 0.0 else 9.0)), 4.0, AFFIX_COLORS[affixes[i]])
	if shield > 0.0 and flash > 0.0:
		draw_ring(radius * 1.25, Color(0.3, 0.7, 1.0, 0.6 * flash), 3.0, height)
	if is_boss:
		draw_ring(radius * 1.6, Color(1, 0.2, 0.3, 0.35 + 0.25 * sin(anim * 3.0)), 4.0, height)


# --- M8: escudos enemigos ---------------------------------------------------------------------
const AFFIX_NAMES := {
	"blindado": "Blindado", "frenetico": "Frenético", "regenerador": "Regenerador", "reflexivo": "Reflexivo",
	"volatil": "Volátil", "comandante": "Comandante", "vampirico": "Vampírico", "fasico": "Fásico",
	"gravitatorio": "Gravitatorio", "enjambrador": "Enjambrador",
}
const AFFIX_COLORS := {
	"blindado": Color("a0a8b8"), "frenetico": Color("ff6a3a"), "regenerador": Color("5ad16a"), "reflexivo": Color("9ad8ff"),
	"volatil": Color("ffb84a"), "comandante": Color("ffd84a"), "vampirico": Color("d03a5a"), "fasico": Color("b88aff"),
	"gravitatorio": Color("8a4aff"), "enjambrador": Color("c8ff6a"),
}


## Prismáticos y Vacío llevan escudo siempre; el resto a partir del nivel 20 (M7/M8).
func _setup_shield() -> void:
	if is_nest:
		return
	var frac := 0.0
	if sector.biome_id in ["prismaticos", "vacio"]:
		frac = 0.4
	elif level >= 20:
		frac = 0.25
	if frac <= 0.0:
		return
	shield_max = hp_max * frac * float(sector.mod.get("shield", 1.0))
	shield = shield_max
	shield_armor = 18.0 * GameData.level_dmg(1.0, sector.eff_level) * (1.3 if frac >= 0.4 else 1.0)


## Daño de un impacto contra el escudo y el casco (devuelve el daño que llega al casco).
func _absorb(amount: float, info: Dictionary) -> float:
	var effect: String = info.get("effect", "")
	if shield <= 0.0:
		return amount * (0.85 if effect == "ion" else 1.0)
	if effect == "phase" and randf() < 0.08:
		return amount
	var vs_shield := amount
	if effect == "ion":
		vs_shield *= 1.45
	elif effect == "pet_ion":
		vs_shield *= 1.35
	vs_shield *= 1.0 + float(info.get("shield_break", 0.0))
	var armor := shield_armor * (1.0 - clampf(float(info.get("pierce", 0.0)), 0.0, 0.9))
	var eff := maxf(vs_shield * 0.15, vs_shield - armor)
	if eff <= shield:
		shield -= eff
		return 0.0
	# El sobrante atraviesa al casco en proporción.
	var rest := (eff - shield) / eff * amount
	shield = 0.0
	sector.fx_ring(plane_pos, radius * 1.4, Color("4ab8ff"))
	return rest


# --- M9: afijos de élite -----------------------------------------------------------------------
func _roll_affixes(n: int) -> void:
	if n <= 0 or is_nest:
		return
	var pool: Array = AFFIX_NAMES.keys()
	pool.shuffle()
	for i in mini(n, pool.size()):
		add_affix(pool[i])


func add_affix(a: String) -> void:
	if affixes.has(a):
		return
	affixes.append(a)
	if a == "comandante":
		sector.commanders.append(self)
	match a:
		"blindado":
			dmg_taken_mult *= 0.7
			speed *= 0.8
		"frenetico":
			atk_mult *= 1.4
			speed *= 1.25
			hp_max *= 0.75
			hp = minf(hp, hp_max)
	is_elite = true


func affix_text() -> String:
	var parts: PackedStringArray = []
	for a in affixes:
		parts.append(AFFIX_NAMES[a])
	return " · ".join(parts)


func _affix_tick(delta: float, p: PlayerShip, dist: float) -> void:
	since_hit += delta
	if phase_t > 0.0:
		phase_t -= delta
		if phase_t <= 0.0:
			phased = false
	if shield_max > 0.0 and since_hit > 3.0 and shield < shield_max:
		shield = minf(shield_max, shield + shield_max * 0.08 * delta)
	if affixes.is_empty() or not aggro:
		return
	if affixes.has("regenerador") and since_hit > 3.0:
		hp = minf(hp_max, hp + hp_max * 0.02 * delta)
	affix_timer -= delta
	if affix_timer > 0.0:
		return
	affix_timer = 6.0
	if affixes.has("reflexivo"):
		reflecting = 1.4
		sfx("e_reflect", -4.0)
	if affixes.has("fasico") and not phased:
		phased = true
		phase_t = 1.5
		sfx("e_phase", -4.0)
	if affixes.has("gravitatorio") and dist < 520.0:
		p.external_pull += (plane_pos - p.plane_pos).normalized() * 280.0
		sector.fx_ring(p.plane_pos, 120.0, AFFIX_COLORS["gravitatorio"])
		sfx("e_pulse", -6.0)


## Multiplicador de daño por aura de Comandante cercano (lo calcula el sector una vez por fotograma).
func _aura_mult() -> float:
	return 1.2 if sector.commander_near(self) else 1.0


# --- M6: jefe con fases ------------------------------------------------------------------------
func make_boss() -> void:
	is_boss = true
	is_elite = true
	hp_max *= 6.0
	hp = hp_max
	shield_max *= 6.0
	shield = shield_max
	radius *= 1.4
	speed *= 0.8
	_roll_affixes(2)


func boss_name() -> String:
	return "%s — Jefe del sector" % def["name"]


func _boss_tick(delta: float, p: PlayerShip, dist: float) -> void:
	var frac := hp / hp_max
	var phase := 1 if frac > 0.66 else (2 if frac > 0.33 else 3)
	if phase != boss_phase:
		boss_phase = phase
		sector.hud.toast("¡%s entra en la FASE %d!" % [def["name"], phase], 3.0, UiTheme.BAD)
		sfx("e_nova")
		sector.fx_ring(plane_pos, radius * 3.0, def["accent"])
	boss_spiral -= delta
	boss_zone -= delta
	boss_summon -= delta
	if dist > 1300.0:
		return
	# Espiral radial: más balas y más frecuente en cada fase.
	if boss_spiral <= 0.0:
		boss_spiral = 4.2 - boss_phase * 0.9
		var n := 10 + 4 * boss_phase
		var rot := anim * 0.7
		for i in n:
			var dir := Vector2.from_angle(rot + TAU * i / n)
			sector.spawn_enemy_bullet(plane_pos + dir * radius, dir, 300.0, out_dmg() * 0.55, 8.0, def["accent"], height, 3.0)
		sfx("e_heavy", -2.0)
	if boss_phase >= 2 and boss_zone <= 0.0:
		boss_zone = 5.0
		sector.telegraph_circle(p.plane_pos, 130.0, 1.2, out_dmg() * 1.4, def["accent"])
		for k in 2:
			sector.telegraph_circle(p.plane_pos + Vector2.from_angle(randf() * TAU) * 220.0, 110.0, 1.4, out_dmg(), def["accent"])
		sfx("e_launch", -2.0)
	if boss_phase >= 2 and boss_summon <= 0.0:
		boss_summon = 9.0
		spawned = 0
		_spawn_children(3)
	if boss_phase == 3 and attack_timer <= 0.0 and dist < attack_range:
		attack_timer = 1.4
		for k in 3:
			_shoot_at(p, 520.0, 8.0, 0.7, 0.18, k == 0)
