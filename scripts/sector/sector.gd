class_name Sector
extends Node2D
## Incursión en un sector procedural (11). Mapa por chunks, objetivos, Alerta del Sector y extracción.

signal finished(result: Dictionary)

const CHUNK := 2000.0
const PICK_SCREEN_RADIUS := 26.0

var params: Dictionary = {}
var level := 1
var rng := RandomNumberGenerator.new()
var biome: Dictionary = {}
var biome_id := "ferron"

var cells: Dictionary = {}          # Vector2i -> {"visited": bool}
var start_cell := Vector2i.ZERO
var gate_pos := Vector2.ZERO
var asteroids_by_cell: Dictionary = {}

var world: Node2D
var ground: Ground
var fx_ground: Node2D
var fx_top: Node2D
var camera: Camera2D
var hud: Hud
var player: PlayerShip
var drone: Drone
var enemies: Array[Enemy] = []

# Objetivo
var objective := "limpieza"
var objective_target := 0
var objective_progress := 0
var objective_done := false
var initial_enemies: Dictionary = {}  # instance_id -> true
var nests_alive := 0

# Alerta (11.2): aumenta con el tiempo, eleva densidad y calidad.
var alert := 0.0
var wave_timer := 30.0
var elapsed := 0.0

# Botín de la incursión (todavía no asegurado)
var loot: Dictionary = {}
var cargo_used := 0
var kills := 0
var run_ammo: Dictionary = {}
var ammo_used: Dictionary = {}
var ammo_frac := 0.0
var active_ammo := "mk1"
var run_items: Dictionary = {}
var items_used: Dictionary = {}
var item_cd: Dictionary = {}
var placing := ""                   # id de desplegable en modo colocación
var mines: Array = []

var ended := false
var demo := false
var showcase := false
var aimtest := false
var demo_timer := 0.0
var right_held := false
var map_w := 4
var map_h := 3
var bounds := Rect2()
var run_xp := 0
var kills_by: Dictionary = {}
var boxes: Array = []                 # cajas de botín activas
var collect_target: LootBox = null     # caja hacia la que va la nave para recogerla
var hover_box: LootBox = null
var loot_version := 0                  # cambia cuando varía la bodega (refresca el inventario)
var shield_buff := {"pct": 0.0, "time": 0.0}
var laser_buff := {"pct": 0.0, "charges": 0}
var zoom_level := 1.15
var auto_fire := false


func _ready() -> void:
	level = int(params.get("level", 1))
	rng.seed = int(params.get("seed", randi()))
	demo = params.get("demo", false)
	showcase = params.get("showcase", false) or params.get("aimtest", false)
	aimtest = params.get("aimtest", false)
	biome_id = params.get("biome", "ferron")
	biome = GameData.BIOMES[biome_id]
	run_ammo = GameState.data["ammo"].duplicate()
	run_items = GameState.data["items"].duplicate()
	auto_fire = Controls.is_touch and GameState.data["settings"].get("auto_fire_touch", true)

	var backdrop := Backdrop.new()
	backdrop.sector = self
	add_child(backdrop)
	ground = Ground.new()
	ground.sector = self
	ground.z_index = -10
	add_child(ground)
	fx_ground = Node2D.new()
	fx_ground.z_index = -5
	add_child(fx_ground)
	world = Node2D.new()
	world.y_sort_enabled = true
	add_child(world)
	fx_top = Node2D.new()
	fx_top.z_index = 10
	add_child(fx_top)
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	add_child(camera)

	_generate()
	ground.build()

	player = PlayerShip.new()
	player.setup(self)
	player.plane_pos = gate_pos + Vector2(160, 160)
	player.died.connect(_on_player_died)
	world.add_child(player)
	player.sync_screen()
	camera.position = player.position
	camera.reset_smoothing()
	camera.zoom = Vector2.ONE * zoom_level

	var role: String = GameState.data["drone"]["role"]
	drone = Drone.new()
	drone.setup(self, role)
	world.add_child(drone)

	hud = Hud.new()
	hud.sector = self
	add_child(hud)
	# Munición activa inicial: primer slot con munición disponible.
	for e in GameState.current_loadout()["hotbar"]:
		if e is Dictionary and e.get("type") == "ammo" and int(run_ammo.get(e["id"], 0)) > 0:
			active_ammo = e["id"]
			break
	Music.play(biome_id)
	hud.toast("%s — Nivel %d" % [biome["name"], level], 3.0)
	hud.toast(_objective_text(), 4.0)
	if OS.get_cmdline_user_args().has("--showinv"):
		hud.inventory.visible = true
	if aimtest:
		_build_aimtest()
	elif showcase:
		_build_showcase()


# --- Generación procedural ------------------------------------------------------------
func _generate() -> void:
	# Mapa siempre rectangular (más espacio libre); crece con el nivel de amenaza.
	map_w = clampi(4 + level / 6, 4, 8)
	map_h = clampi(3 + level / 8, 3, 6)
	for x in map_w:
		for y in map_h:
			cells[Vector2i(x, y)] = {"visited": false}
	start_cell = Vector2i(0, map_h / 2)
	cells[start_cell]["visited"] = true
	bounds = Rect2(Vector2.ZERO, Vector2(map_w, map_h) * CHUNK)
	gate_pos = cell_center(start_cell)

	objective = "limpieza" if rng.randf() < 0.5 else "nidos"
	var far_cells: Array = cells.keys()
	far_cells.erase(start_cell)
	far_cells.sort_custom(func(a, b): return Vector2(a - start_cell).length() > Vector2(b - start_cell).length())

	if objective == "nidos":
		objective_target = clampi(3 + level / 4, 3, 6)
		for i in objective_target:
			var c: Vector2i = far_cells[i % far_cells.size()]
			var nest := spawn_enemy("nest", _free_point_in(c, 0.5), level, "base")
			nests_alive += 1
			nest.set_meta("nest", true)

	for c in cells.keys():
		_populate_cell(c, c == start_cell)

	# Élite del sector: nodriza en la celda más lejana.
	var elite_id: String = biome["elites"][0]
	var ev := "boss" if level >= 4 else "base"
	spawn_enemy(elite_id, _free_point_in(far_cells[0], 0.4), level, ev)

	if objective == "limpieza":
		objective_target = 70


func cell_center(c: Vector2i) -> Vector2:
	return Vector2(c) * CHUNK + Vector2.ONE * CHUNK * 0.5


func cell_of(p: Vector2) -> Vector2i:
	return Vector2i(floori(p.x / CHUNK), floori(p.y / CHUNK))


func _free_point_in(c: Vector2i, spread: float) -> Vector2:
	var center := cell_center(c)
	for i in 20:
		var p := center + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)) * CHUNK * 0.5 * spread
		if not is_blocked(p, 60.0):
			return p
	return center


func _populate_cell(c: Vector2i, is_start: bool) -> void:
	asteroids_by_cell[c] = []
	var count := rng.randi_range(9, 16)
	for i in count:
		var p := cell_center(c) + Vector2(rng.randf_range(-0.47, 0.47), rng.randf_range(-0.47, 0.47)) * CHUNK
		var r := rng.randf_range(28.0, 95.0)
		if is_start and p.distance_to(gate_pos) < 550.0:
			continue
		if is_blocked(p, r + 40.0):
			continue
		_add_asteroid(c, p, r, "")
	# Nodos de recursos
	for i in rng.randi_range(2, 4):
		var p := _free_point_in(c, 0.85)
		if is_start and p.distance_to(gate_pos) < 300.0:
			continue
		_add_asteroid(c, p, rng.randf_range(34.0, 50.0), _weighted(biome["resources"]))
	if is_start:
		# Tutorial ligero: un par de enemigos débiles cerca de la entrada.
		var weak: Array = biome["enemies"].keys().slice(0, 2)
		spawn_group_at(gate_pos + Vector2(750, 300), 2, level, true, weak)
		return
	for g in rng.randi_range(2, 4):
		spawn_group_at(_free_point_in(c, 0.8), rng.randi_range(2, 4) + level / 5, level, true)


func _add_asteroid(c: Vector2i, p: Vector2, r: float, ore: String) -> void:
	var a := Asteroid.new()
	a.setup(self, p, r, ore, rng)
	world.add_child(a)
	asteroids_by_cell[c].append(a)


func _weighted(table: Dictionary) -> String:
	var total := 0
	for k in table.keys():
		total += int(table[k])
	var roll := rng.randi() % total
	for k in table.keys():
		roll -= int(table[k])
		if roll < 0:
			return k
	return table.keys()[0]


func _roll_variant() -> String:
	var a := floorf(alert)
	var r := rng.randf()
	if level >= 3 and r < 0.01 + 0.004 * a:
		return "mega"
	if r < 0.05 + 0.012 * a:
		return "boss"
	return "base"


func spawn_enemy(id: String, pos: Vector2, lvl: int, variant: String) -> Enemy:
	var e := Enemy.new()
	e.setup(self, id, lvl, variant, pos)
	world.add_child(e)
	enemies.append(e)
	return e


func spawn_group_at(pos: Vector2, count: int, lvl: int, initial: bool, pool: Array = []) -> void:
	var id: String = pool[rng.randi() % pool.size()] if pool.size() > 0 else _weighted(biome["enemies"])
	# Enjambres en grupo mayor; tanques y artillería con escolta.
	for i in count:
		var this_id := id if i == 0 or rng.randf() < 0.6 else _weighted(biome["enemies"])
		if pool.size() > 0:
			this_id = pool[rng.randi() % pool.size()]
		var p := pos + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(20.0, 140.0)
		var e := spawn_enemy(this_id, p, lvl, "base" if initial and pool.size() > 0 else _roll_variant())
		if initial:
			initial_enemies[e.get_instance_id()] = true


func spawn_group_near(pos: Vector2, count: int, lvl: int) -> void:
	for i in count:
		var e := spawn_enemy(_weighted(biome["enemies"]), pos + Vector2.from_angle(rng.randf() * TAU) * 90.0, lvl, _roll_variant())
		e.aggro = true


# --- Bucle ------------------------------------------------------------------------
func _process(delta: float) -> void:
	if ended:
		return
	elapsed += delta
	_update_alert(delta)
	_handle_held_input()
	if demo:
		_demo_autopilot(delta)
	if aimtest:
		_update_aimtest(delta)
	for k in item_cd.keys():
		item_cd[k] = maxf(0.0, item_cd[k] - delta)
	_separate_enemies()
	_update_mines()
	var c := cell_of(player.plane_pos)
	if cells.has(c) and not cells[c]["visited"]:
		cells[c]["visited"] = true
	_update_loot(delta)
	Sfx.listener_pos = player.plane_pos
	Sfx.has_listener = true
	camera.position = player.position + Vector2(0, -20)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * zoom_level, clampf(8.0 * delta, 0.0, 1.0))
	_check_gate()


func _update_alert(delta: float) -> void:
	if showcase:
		return
	var before := floorf(alert)
	alert = minf(5.0, alert + delta / 75.0)
	if floorf(alert) > before:
		hud.toast("¡ALERTA DEL SECTOR %d!" % int(floorf(alert)), 3.0, UiTheme.WARN)
		Sfx.play("alert", null, -11.0)
		Sfx.voice("sector_alert")
		wave_timer = 2.0
	if alert >= 1.0:
		wave_timer -= delta
		if wave_timer <= 0.0:
			wave_timer = maxf(10.0, 28.0 - floorf(alert) * 3.5)
			_spawn_wave()


func _spawn_wave() -> void:
	if enemies.size() > 70:
		return
	# Llegan desde fuera del campo visual, en una dirección aleatoria.
	var dir := Vector2.from_angle(rng.randf() * TAU)
	var pos := constrain(player.plane_pos + dir * 900.0, 40.0)
	var count := 2 + int(floorf(alert)) + level / 6
	for i in count:
		var e := spawn_enemy(_weighted(biome["enemies"]), pos + Vector2.from_angle(rng.randf() * TAU) * 120.0, level, _roll_variant())
		e.aggro = true


func _separate_enemies() -> void:
	# Separación suave (4.4): evita apilamientos sin crear paredes imposibles.
	var n := enemies.size()
	for i in n:
		var a := enemies[i]
		for j in range(i + 1, n):
			var b := enemies[j]
			var d := a.plane_pos - b.plane_pos
			var min_d := (a.radius + b.radius) * 0.8
			var l2 := d.length_squared()
			if l2 < min_d * min_d and l2 > 0.01:
				var l := sqrt(l2)
				var push := d / l * (min_d - l) * 0.5
				var wa := 0.2 if a.arch == "tank" else 1.0
				var wb := 0.2 if b.arch == "tank" else 1.0
				if not a.is_nest:
					a.plane_pos += push * wa
				if not b.is_nest:
					b.plane_pos -= push * wb


## Mantiene una posición dentro del rectángulo del mapa y fuera de los obstáculos.
func constrain(p: Vector2, r: float) -> Vector2:
	var inner := bounds.grow(-r)
	p = Vector2(clampf(p.x, inner.position.x, inner.end.x), clampf(p.y, inner.position.y, inner.end.y))
	var c := cell_of(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			var list: Array = asteroids_by_cell.get(c + Vector2i(dx, dy), [])
			for a in list:
				if not is_instance_valid(a) or not a.alive:
					continue
				var d: Vector2 = p - a.plane_pos
				var min_d: float = a.radius * 0.85 + r
				if d.length_squared() < min_d * min_d:
					p = a.plane_pos + d.normalized() * min_d
	return p


func is_blocked(p: Vector2, margin: float = 0.0) -> bool:
	if not bounds.has_point(p):
		return true
	var c := cell_of(p)
	for dx in range(-1, 2):
		for dy in range(-1, 2):
			for a in asteroids_by_cell.get(c + Vector2i(dx, dy), []):
				if is_instance_valid(a) and a.alive and p.distance_to(a.plane_pos) < a.radius * 0.8 + margin:
					return true
	return false


# --- Entrada: clic izquierdo = objetivo, clic derecho = mover, ataque automático ---------------
func mouse_plane() -> Vector2:
	return Iso.to_plane(get_global_mouse_position())


func pick_at(screen: Vector2) -> Entity:
	var best: Entity = null
	var best_d := INF
	for e in enemies:
		if not e.alive or not e.visible:
			continue
		var d := screen.distance_to(e.position + Vector2(0, -e.height))
		if d < e.radius * 0.9 + PICK_SCREEN_RADIUS and d < best_d:
			best_d = d
			best = e
	if best:
		return best
	for c in asteroids_by_cell.values():
		for a in c:
			if is_instance_valid(a) and a.alive and a.ore != "":
				var d: float = screen.distance_to(a.position + Vector2(0, -a.radius * 0.35))
				if d < a.radius * 0.9 and d < best_d:
					best_d = d
					best = a
	return best


func _unhandled_input(event: InputEvent) -> void:
	if ended or demo:
		return  # el piloto automático ignora entradas reales para que las pruebas sean reproducibles
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				zoom_level = clampf(zoom_level + 0.08, 0.55, 1.4)
			MOUSE_BUTTON_WHEEL_DOWN:
				zoom_level = clampf(zoom_level - 0.08, 0.55, 1.4)
			MOUSE_BUTTON_LEFT:
				_left_click()
			MOUSE_BUTTON_RIGHT:
				_right_click()
	if event.is_action_pressed("cancel"):
		if placing != "":
			placing = ""
		elif player.target_valid():
			player.target = null
		else:
			hud.toggle_pause()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("boost"):
		player.try_boost()
	elif event.is_action_pressed("ability"):
		player.try_ability()
	elif event.is_action_pressed("drone"):
		drone.use_ability()
	elif event.is_action_pressed("tactical_map"):
		hud.toggle_map()
	elif event.is_action_pressed("inventory"):
		hud.toggle_inventory()
	elif event.is_action_pressed("interact"):
		_interact()
	else:
		for i in GameState.HOTBAR_SIZE:
			if event.is_action_pressed("hotbar_%d" % i):
				use_hotbar(i)
				break


## Clic izquierdo: fija objetivo (enemigo o depósito). En pantallas táctiles también mueve.
func _left_click() -> void:
	if placing != "":
		_place(placing, mouse_plane())
		return
	var box := box_at(get_global_mouse_position())
	if box:
		# Clic en una caja de botín: la nave va a recogerla.
		collect_target = box
		_move_to(box.plane_pos)
		Sfx.play("ui_select", null, -10.0)
		return
	var e := pick_at(get_global_mouse_position())
	if e:
		if e != player.target:
			Sfx.play("ui_select", null, -10.0)
		player.target = e
		return
	if _near_gate_click():
		return
	if Controls.is_touch:
		_move_to(mouse_plane())


## Clic derecho: mover la nave (mantener pulsado para guiarla).
func _right_click() -> void:
	collect_target = null
	if _near_gate_click():
		return
	_move_to(mouse_plane())
	right_held = true


func _near_gate_click() -> bool:
	if get_global_mouse_position().distance_to(Iso.to_screen(gate_pos)) < 80.0 and player.plane_pos.distance_to(gate_pos) < 200.0:
		request_extract()
		return true
	return false


func _move_to(p: Vector2) -> void:
	player.move_target = p
	player.has_move_target = true
	fx_ring(p, 26.0, Color(0.4, 1.0, 0.8, 0.6))


func _handle_held_input() -> void:
	if demo:
		return
	if right_held and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		player.move_target = mouse_plane()
		player.has_move_target = true
	else:
		right_held = false


func _interact() -> void:
	if player.plane_pos.distance_to(gate_pos) < 200.0:
		request_extract()
		return
	# Recoger manual: atrae el botín bajo el puntero.
	pull_loot(mouse_plane(), 120.0)


# --- Barra rápida (4.3) --------------------------------------------------------------
func hotbar_entry(i: int):
	return GameState.current_loadout()["hotbar"][i]


func use_hotbar(i: int) -> void:
	var entry = hotbar_entry(i)
	if not (entry is Dictionary):
		hud.slot_feedback(i, false)
		Sfx.play("ui_error", null, -8.0)
		return
	if entry["type"] == "ammo":
		if int(run_ammo.get(entry["id"], 0)) <= 0:
			hud.toast("Sin %s" % GameData.AMMO[entry["id"]]["name"], 1.5, UiTheme.BAD)
			hud.slot_feedback(i, false)
			return
		active_ammo = entry["id"]
		hud.slot_feedback(i, true)
		Sfx.play("ui_select", null, -4.0)
		return
	var id: String = entry["id"]
	var def: Dictionary = GameData.ITEMS[id]
	if int(run_items.get(id, 0)) <= 0 or item_cd.get(id, 0.0) > 0.0:
		hud.slot_feedback(i, false)
		return
	if def["kind"] == "deploy":
		placing = id
		hud.toast("Clic izquierdo para colocar (Esc cancela)", 2.0)
		return
	match id:
		"repair":
			player.repair(0.3)
		"boost":
			player.buffs["boost_item"] = 5.0
		"shield_cell":
			player.shield = minf(player.shield_max_now(), player.shield + player.shield_max * 0.4)
	_consume_item(id)
	hud.slot_feedback(i, true)
	Sfx.play("item_use")


func _consume_item(id: String) -> void:
	run_items[id] = int(run_items[id]) - 1
	items_used[id] = int(items_used.get(id, 0)) + 1
	item_cd[id] = GameData.ITEMS[id]["cd"]


func _place(id: String, p: Vector2) -> void:
	if is_blocked(p) or p.distance_to(player.plane_pos) > 500.0:
		hud.toast("Posición no válida", 1.0, UiTheme.BAD)
		return
	placing = ""
	_consume_item(id)
	mines.append({"pos": p, "arm": 1.0})
	Sfx.play("deploy")
	fx_ring(p, 40.0, Color("ff5a5a"))


func _update_mines() -> void:
	for m in mines.duplicate():
		m["arm"] = maxf(0.0, m["arm"] - get_process_delta_time())
		if m["arm"] > 0.0:
			continue
		for e in enemies:
			if e.alive and e.plane_pos.distance_to(m["pos"]) < 90.0 + e.radius:
				player_explosion(m["pos"], 180.0, 2500.0 * GameData.level_hp(1.0, level) * 0.5)
				mines.erase(m)
				break
	ground.mines = mines


func consume_ammo(cost: float) -> bool:
	if int(run_ammo.get(active_ammo, 0)) <= 0:
		# Se agotó: volver a munición x1 si queda.
		if active_ammo != "mk1" and int(run_ammo.get("mk1", 0)) > 0:
			active_ammo = "mk1"
			hud.toast("Munición agotada: cambiando a Mk-I", 1.5, UiTheme.WARN)
		else:
			hud.toast("¡Sin munición!", 1.0, UiTheme.BAD)
			return false
	ammo_frac += cost
	var whole := int(ammo_frac)
	ammo_frac -= whole
	if whole > 0:
		run_ammo[active_ammo] = int(run_ammo[active_ammo]) - whole
		ammo_used[active_ammo] = int(ammo_used.get(active_ammo, 0)) + whole
	return true


func active_ammo_mult() -> float:
	return float(GameData.AMMO[active_ammo]["mult"])


# --- Combate ------------------------------------------------------------------------
func spawn_player_bolt(origin: Vector2, target: Entity, dmg: float, info: Dictionary, dir: Vector2 = Vector2.ZERO) -> void:
	var b := Projectile.new()
	b.sector = self
	b.plane_pos = origin
	b.target = target
	b.damage = dmg
	b.info = info
	b.color = info.get("color", Color.RED)
	b.speed = 1600.0
	b.life = 0.9
	if info.get("effect", "") == "pierce":
		b.pierce_left = 3
	if target == null:
		b.dir = dir
		b.life = 0.45
	else:
		b.dir = (target.plane_pos - origin).normalized()
	b.position = Iso.to_screen(origin)
	fx_top.add_child(b)


func spawn_enemy_bullet(origin: Vector2, dir: Vector2, spd: float, dmg: float, size: float, color: Color, h: float = 16.0, life: float = 2.4) -> void:
	var b := Projectile.new()
	b.sector = self
	b.hostile = true
	b.plane_pos = origin
	b.dir = dir
	b.speed = spd
	b.damage = dmg
	b.size = size
	b.color = color
	b.life = clampf(life, 0.6, 3.5)
	b.homing = GameData.ENEMY_BULLET_TURN
	b.lift_h = h
	b.position = Iso.to_screen(origin)
	fx_top.add_child(b)


func enemy_at(p: Vector2, r: float, exclude: Array) -> Enemy:
	for e in enemies:
		if e.alive and not exclude.has(e) and p.distance_to(e.plane_pos) < e.radius + r:
			return e
	return null


func chain_from(from: Entity, dmg: float, info: Dictionary, jumps: int) -> void:
	var hit: Array = [from]
	var cur := from
	for j in jumps:
		var best: Enemy = null
		var best_d := 300.0
		for e in enemies:
			if e.alive and not hit.has(e):
				var d := e.plane_pos.distance_to(cur.plane_pos)
				if d < best_d:
					best_d = d
					best = e
		if best == null:
			return
		ground.add_arc(cur.plane_pos, best.plane_pos, info.get("color", Color.WHITE))
		best.take_hit(dmg, {"color": info.get("color", Color.WHITE)})
		dmg *= 0.7
		hit.append(best)
		cur = best


func heal_allies(src: Enemy, r: float, frac: float) -> int:
	var healed := 0
	for e in enemies:
		if e.alive and e != src and e.hp < e.hp_max and e.plane_pos.distance_to(src.plane_pos) < r:
			e.hp = minf(e.hp_max, e.hp + e.hp_max * frac)
			ground.add_arc(src.plane_pos, e.plane_pos, Color("4ab8ff"))
			healed += 1
	return healed


func nearest_ally(src: Enemy) -> Enemy:
	var best: Enemy = null
	var best_d := 800.0
	for e in enemies:
		if e.alive and e != src and e.arch != "support" and not e.is_nest:
			var d := e.plane_pos.distance_to(src.plane_pos)
			if d < best_d:
				best_d = d
				best = e
	return best


func explode(p: Vector2, r: float, dmg: float, color: Color, _src) -> void:
	fx_explosion(p, r, color)
	Sfx.play("explosion_m", p, -2.0)
	if player.alive and player.plane_pos.distance_to(p) < r + player.radius * 0.5:
		player.take_damage(dmg)


func player_explosion(p: Vector2, r: float, dmg: float) -> void:
	fx_explosion(p, r, Color("ffb84a"))
	Sfx.play("explosion_m", p, -2.0)
	for e in enemies.duplicate():
		if e.alive and e.plane_pos.distance_to(p) < r + e.radius:
			e.take_hit(dmg, {})


func telegraph_circle(p: Vector2, r: float, t: float, dmg: float, color: Color) -> void:
	var f := Fx.new()
	f.kind = "telegraph"
	f.plane_pos = p
	f.r = r
	f.life = t
	f.max_life = t
	f.dmg = dmg
	f.color = color
	f.sector = self
	fx_ground.add_child(f)


func gravity_well(p: Vector2, r: float, dur: float) -> void:
	for e in enemies:
		if e.alive and not e.is_nest and e.plane_pos.distance_to(p) < r:
			if e.radius < 30.0:
				e.pull_vel = (p - e.plane_pos).normalized() * 350.0
			e.slow = 0.4
			e.slow_time = dur
	fx_ring(p, r, Color("8a4aff"))


# --- Botín (13) -----------------------------------------------------------------------
func on_enemy_killed(e: Enemy, by_player: bool) -> void:
	enemies.erase(e)
	if player.target == e:
		player.target = null
	ship_explosion(e.plane_pos, e.radius * 1.6)
	var counted := initial_enemies.has(e.get_instance_id())
	if e.has_meta("nest"):
		nests_alive -= 1
		objective_progress += 1
		hud.toast("Nido destruido (%d/%d)" % [objective_progress, objective_target], 2.0, UiTheme.GOOD)
	elif counted and objective == "limpieza":
		objective_progress += 1
	if not by_player:
		return
	kills += 1
	var v: Dictionary = GameData.VARIANTS[e.variant]
	var rmult: float = float(v["reward"])
	if not e.is_nest:
		kills_by[e.id] = int(kills_by.get(e.id, 0)) + 1
	var xp := GameData.enemy_xp(float(e.def["hp"]), level, rmult)
	run_xp += xp
	if GameState.add_xp(xp) > 0:
		hud.toast("¡ASCENSO! %s — Nivel %d" % [GameState.rank_name(), GameState.level()], 4.0, UiTheme.WARN)
		Sfx.play("objective")
		Sfx.voice("rank_up", true)
	# Créditos y Nexo se acreditan al instante; los materiales quedan en una caja de botín.
	var credits := int(GameData.level_reward(float(e.def["credits"]), level) * rmult)
	_gain("credits", credits)
	var nexo_chance: float = float(e.def["nexo"]) * rmult
	if e.variant != "base":
		nexo_chance += 0.12 * (rmult - 1.0)
	if rng.randf() < nexo_chance:
		_gain("nexo", maxi(1, int(rmult) - 1))
	var contents := {}
	for mat in e.def["drops"].keys():
		var q: float = GameData.level_reward(float(e.def["drops"][mat]), level) * rmult
		var rare: bool = GameData.MATERIALS.get(mat, {}).get("rarity", 0) >= 2
		var n := int(ceil(q)) if rare else int(round(q))
		if n > 0:
			contents[mat] = n
	spawn_box(contents, e.plane_pos, e.is_elite or e.variant != "base")
	_check_objective()


func _clear_percent() -> int:
	if initial_enemies.is_empty():
		return 100
	return int(100.0 * objective_progress / initial_enemies.size())


func _check_objective() -> void:
	if objective_done:
		return
	var done := false
	if objective == "limpieza":
		done = _clear_percent() >= objective_target
	else:
		done = objective_progress >= objective_target
	if done:
		objective_done = true
		hud.toast("OBJETIVO COMPLETADO — vuelve al portal para extraer", 5.0, UiTheme.GOOD)
		Sfx.play("objective")
		Sfx.voice("objective")


func _objective_text() -> String:
	if objective == "limpieza":
		return "Limpieza: %d%% / %d%%" % [_clear_percent(), objective_target]
	return "Destruir nidos: %d / %d" % [objective_progress, objective_target]


func objective_text() -> String:
	return ("✔ " if objective_done else "") + _objective_text()


func on_ore_mined(a: Asteroid) -> void:
	Sfx.play("explosion_s", a.plane_pos)
	fx_explosion(a.plane_pos, a.radius, GameData.mat_color(a.ore))
	var contents := {a.ore: int(GameData.level_reward(rng.randf_range(15.0, 30.0), level))}
	if rng.randf() < 0.35:
		contents["nanoespuma"] = 6
	spawn_box(contents, a.plane_pos, false)
	if player.target == a:
		player.target = null


# --- Botín: cajas, bodega, refinado ----------------------------------------------------------
## Monedas (créditos, Nexo, sellos): no ocupan bodega y se suman al instante.
func _gain(item: String, amount: int) -> void:
	if amount <= 0:
		return
	loot[item] = int(loot.get(item, 0)) + amount
	hud.pickup(item, amount)
	Sfx.play("pickup_rare" if item == "nexo" else "pickup", null, -10.0)


func spawn_box(contents: Dictionary, p: Vector2, rare: bool) -> void:
	if contents.is_empty():
		return
	var b := LootBox.new()
	b.setup(self, contents, p + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)), rare)
	world.add_child(b)
	boxes.append(b)


func remove_box(b: LootBox) -> void:
	boxes.erase(b)
	if collect_target == b:
		collect_target = null
	if hover_box == b:
		hover_box = null
	b.queue_free()


func box_at(screen: Vector2) -> LootBox:
	var best: LootBox = null
	var best_d := 40.0
	for b in boxes:
		if not b.visible:
			continue
		var d := screen.distance_to(b.position + Vector2(0, -22))
		if d < best_d:
			best_d = d
			best = b
	return best


func cargo_capacity() -> int:
	return int(player.stats["cargo"])


## Pasa a la bodega todo lo que quepa (primero lo más valioso). Lo demás se queda en la caja.
func collect_box(b: LootBox) -> void:
	var keys: Array = b.contents.keys()
	keys.sort_custom(func(x, y): return GameData.MATERIALS.get(x, {}).get("rarity", 0) > GameData.MATERIALS.get(y, {}).get("rarity", 0))
	var got := 0
	for mat in keys:
		var free := cargo_capacity() - cargo_used
		if free <= 0:
			break
		var take := mini(free, int(b.contents[mat]))
		loot[mat] = int(loot.get(mat, 0)) + take
		cargo_used += take
		got += take
		hud.pickup(mat, take)
		b.contents[mat] = int(b.contents[mat]) - take
		if int(b.contents[mat]) <= 0:
			b.contents.erase(mat)
	if got > 0:
		Sfx.play("pickup", null, -6.0)
		loot_version += 1
	if not b.contents.is_empty():
		hud.toast("Bodega llena — abre Inventario/Refinado (%s) para tirar o refinar" % Controls.key_label("inventory"), 2.5, UiTheme.WARN)
		Sfx.play("ui_error", null, -10.0)
	if collect_target == b:
		collect_target = null
	if b.contents.is_empty():
		remove_box(b)


## Recogida remota (imán, compresor, dron recolector, tecla F): cajas en un radio.
func pull_loot(p: Vector2, r: float) -> void:
	for b in boxes.duplicate():
		if b.plane_pos.distance_to(p) < r:
			collect_box(b)


func cargo_materials() -> Array:
	var out: Array = []
	for k in loot.keys():
		if k in ["credits", "nexo", "seals"] or int(loot[k]) <= 0:
			continue
		out.append(k)
	out.sort_custom(func(x, y): return GameData.MATERIALS.get(x, {}).get("rarity", 0) < GameData.MATERIALS.get(y, {}).get("rarity", 0))
	return out


func _remove_cargo(mat: String, qty: int) -> int:
	qty = mini(qty, int(loot.get(mat, 0)))
	if qty <= 0:
		return 0
	loot[mat] = int(loot[mat]) - qty
	if int(loot[mat]) <= 0:
		loot.erase(mat)
	cargo_used = maxi(0, cargo_used - qty)
	loot_version += 1
	return qty


## Desecha material de la bodega para liberar espacio.
func jettison(mat: String, qty: int) -> void:
	if _remove_cargo(mat, qty) > 0:
		Sfx.play("deploy", null, -6.0)


## Refina material: "shield" = +% de escudo máximo durante 5 min por unidad (acumulable en tiempo);
## "laser" = +% de daño en un disparo de láser por unidad. Más raro el material → más bonificación.
func refine(mat: String, qty: int, kind: String) -> void:
	var n := _remove_cargo(mat, qty)
	if n <= 0:
		return
	var r: int = GameData.MATERIALS.get(mat, {}).get("rarity", 0)
	if kind == "shield":
		var p: float = GameData.REFINE_SHIELD_PCT[r]
		var t := GameData.REFINE_SHIELD_TIME * n
		# Media ponderada por tiempo restante: mezclar materiales nunca supera el mejor porcentaje.
		var total_t: float = float(shield_buff["time"]) + t
		shield_buff["pct"] = (shield_buff["pct"] * shield_buff["time"] + p * t) / total_t
		shield_buff["time"] = minf(GameData.REFINE_SHIELD_CAP, total_t)
		player.shield = minf(player.shield_max_now(), player.shield + player.shield_max * p * 0.5)
	else:
		var p: float = GameData.REFINE_LASER_PCT[r]
		var total_c: float = float(laser_buff["charges"]) + n
		laser_buff["pct"] = (laser_buff["pct"] * laser_buff["charges"] + p * n) / total_c
		laser_buff["charges"] = laser_buff["charges"] + n
	Sfx.play("craft", null, -4.0)
	fx_ring(player.plane_pos, 70.0, Color("3aa0ff") if kind == "shield" else Color("ff5a5a"))


## Bonificación de láser para un disparo (consume una carga).
func take_laser_charge() -> float:
	if laser_buff["charges"] <= 0:
		return 0.0
	laser_buff["charges"] -= 1
	return laser_buff["pct"]


func shield_bonus() -> float:
	return shield_buff["pct"] if shield_buff["time"] > 0.0 else 0.0


# --- Efectos -------------------------------------------------------------------------
func _fx(kind: String, p: Vector2, r: float, color: Color, life: float, top: bool = true) -> Fx:
	var f := Fx.new()
	f.kind = kind
	f.plane_pos = p
	f.r = r
	f.color = color
	f.life = life
	f.max_life = life
	(fx_top if top else fx_ground).add_child(f)
	return f


func fx_ring(p: Vector2, r: float, color: Color) -> void:
	_fx("ring", p, r, color, 0.45, false)


func fx_spark(p: Vector2, color: Color) -> void:
	_fx("spark", p, 10.0, color, 0.25)


## Explosión universal de nave (misma animación y sonido para todas; escala con el tamaño).
func ship_explosion(p: Vector2, size: float) -> void:
	var ex := ShipExplosion.new()
	ex.plane_pos = p
	ex.size = size
	fx_top.add_child(ex)
	Sfx.play("ship_explode", p, clampf(-14.0 + size * 0.12, -12.0, 0.0), 0.08)


func fx_explosion(p: Vector2, r: float, color: Color) -> void:
	_fx("explosion", p, r, color, 0.6)


func fx_number(p: Vector2, amount: float, crit: bool) -> void:
	var f := _fx("number", p + Vector2(randf_range(-10, 10), randf_range(-10, 10)), 0.0, Color("ffe04a") if crit else Color.WHITE, 0.7)
	f.text = GameData.format_num(amount)


# --- Fin de incursión -------------------------------------------------------------------
func _check_gate() -> void:
	var near := player.plane_pos.distance_to(gate_pos) < 200.0
	hud.set_gate_hint(near, objective_done)
	if near and objective_done and player.alive:
		request_extract()


func request_extract() -> void:
	if ended:
		return
	_finish("extract")


func _on_player_died() -> void:
	# Sin avisos: la nave estalla, desaparece y se vuelve al inicio (se pierde el 90% del botín).
	drone.visible = false
	await get_tree().create_timer(2.6).timeout
	_finish("death")


func _finish(outcome: String) -> void:
	if ended:
		return
	ended = true
	Sfx.has_listener = false
	if outcome == "extract":
		Sfx.play("warp")
	var final_loot := loot.duplicate()
	if outcome == "death":
		for k in final_loot.keys():
			final_loot[k] = int(final_loot[k] * (1.0 - GameData.DEATH_LOOT_LOSS))
	var result := {
		"outcome": outcome, "level": level, "loot": final_loot, "raw_loot": loot,
		"ammo_used": ammo_used, "items_used": items_used, "kills": kills,
		"objective_done": objective_done and outcome != "death", "time": elapsed,
		"xp": run_xp, "kills_by": kills_by, "biome": biome_id,
	}
	if outcome == "extract":
		hud.show_result(result)
		await hud.result_closed
	finished.emit(result)


# --- Demo (captura automática / CI) --------------------------------------------------------
func _demo_autopilot(delta: float) -> void:
	demo_timer -= delta
	if not player.target_valid():
		var best: Enemy = null
		var best_d := INF
		for e in enemies:
			var d := e.plane_pos.distance_to(player.plane_pos)
			if d < best_d:
				best_d = d
				best = e
		player.target = best
	if player.target_valid():
		var d := player.plane_pos.distance_to(player.target.plane_pos)
		if demo_timer <= 0.0:
			demo_timer = 0.8
			# Si no hay amenaza cercana, recoge el botín más próximo para probar la recolección.
			var box := _nearest_box_demo(450.0)
			if d > 500.0 and box:
				collect_target = box
				player.move_target = box.plane_pos
			else:
				var ang := (player.plane_pos - player.target.plane_pos).angle() + 0.6
				player.move_target = player.target.plane_pos + Vector2.from_angle(ang) * 380.0
			player.has_move_target = true


func _nearest_box_demo(max_d: float) -> LootBox:
	var best: LootBox = null
	var best_d := max_d
	for b in boxes:
		var d: float = b.plane_pos.distance_to(player.plane_pos)
		if d < best_d:
			best_d = d
			best = b
	return best


# --- Vitrina de arte (depuración: godot -- --showcase) -------------------------------------
func _build_showcase() -> void:
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	alert = 0.0
	var ids: Array = biome["enemies"].keys() + biome["elites"]
	ids.append("nest")
	var origin := player.plane_pos
	for i in ids.size():
		var col := i % 4
		var row := i / 4
		var pos := origin + Vector2(300 + col * 300, -450 + row * 300).rotated(-PI * 0.25)
		var e := spawn_enemy(ids[i], pos, 1, "base")
		e.heading = PI * 0.25
		e.home = pos


# --- Prueba de puntería (depuración: godot -- --aimtest) ------------------------------------
var aim_dummy: Enemy = null
var aim_t := 0.0


func _build_aimtest() -> void:
	for e in enemies.duplicate():
		e.queue_free()
	enemies.clear()
	alert = 0.0
	aim_dummy = spawn_enemy("xenomita", player.plane_pos + Vector2(420, 0), 1, "base")
	aim_dummy.hp_max = 1e9
	aim_dummy.hp = 1e9
	player.target = aim_dummy


func _update_aimtest(delta: float) -> void:
	if aim_dummy == null or not is_instance_valid(aim_dummy):
		return
	aim_t += delta * 0.5
	aim_dummy.plane_pos = player.plane_pos + Vector2.from_angle(aim_t) * 420.0
	aim_dummy.home = aim_dummy.plane_pos
	player.target = aim_dummy


func _update_loot(delta: float) -> void:
	shield_buff["time"] = maxf(0.0, shield_buff["time"] - delta)
	hover_box = box_at(get_global_mouse_position()) if not demo else null
	if collect_target and is_instance_valid(collect_target) and player.alive:
		if player.plane_pos.distance_to(collect_target.plane_pos) < 70.0:
			collect_box(collect_target)
		elif not right_held:
			player.move_target = collect_target.plane_pos
			player.has_move_target = true
	# Imán / compresor: recoge solo las cajas cercanas.
	if player.buffs.has("magnet"):
		pull_loot(player.plane_pos, player.pickup_radius())
