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
var bot := false                       # playtest: piloto con decisiones (objetos, refinado, extracción)
# Métricas de playtest
var stat_damage_taken := 0.0
var stat_cargo_full_t := -1.0
var stat_objective_t := -1.0
var stat_max_enemies := 0
var stat_max_aggro := 0
var stat_spawned := 0
var stat_items_used := 0
var stat_refined := 0
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
var xp_mult := 1.0                       # multiplicador de XP (eventos, Ascensión)
var shield_buff := {"pct": 0.0, "time": 0.0}
var laser_buff := {"pct": 0.0, "charges": 0}
var asc := 0                             # M9: nivel de Ascensión de la incursión
var asc_reward := 1.0
var commanders: Array = []               # enemigos con afijo Comandante (aura de daño)
var boss: Enemy = null                   # M6: jefe del sector
var boss_dead := false
var run_modules: Array = []              # módulos encontrados en cajas legendarias / jefe
var initial_killed := 0
var commander: Enemy = null              # M5: objetivo "comandante"
var points: Array = []                   # M5/M19: balizas, socorro, convoy y puntos de interés
var mod: Dictionary = {}                 # M18: modificador semanal
# Contadores para misiones y logros (M4, M13)
var run_elites := 0
var run_boxes := 0
var run_pois := 0
var run_events := 0
var run_legendary := 0
# M19: eventos aleatorios
var event_t := 150.0
var event := ""
var event_time := 0.0
var event_tick := 0.0
var convoy_left := 0
var zoom_level := 1.15
var auto_fire := false


func _ready() -> void:
	level = int(params.get("level", 1))
	rng.seed = int(params.get("seed", randi()))
	demo = params.get("demo", false)
	bot = params.get("bot", false)
	if bot:
		demo = true
	showcase = params.get("showcase", false) or params.get("aimtest", false)
	aimtest = params.get("aimtest", false)
	biome_id = params.get("biome", "ferron")
	biome = GameData.BIOMES[biome_id]
	asc = int(params.get("asc", 0))
	asc_reward = pow(1.75, asc)
	xp_mult *= asc_reward
	mod = Prog.weekly_mod() if not (demo or showcase) else {}
	xp_mult *= float(mod.get("xp", 1.0))
	event_t = rng.randf_range(100.0, 160.0)
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

	# M5: seis tipos de objetivo (escolta y comandante desde el nivel 3).
	var kinds := ["limpieza", "nidos", "baliza", "socorro"]
	if level >= 3:
		kinds += ["comandante", "escolta"]
	objective = params.get("objective", kinds[rng.randi() % kinds.size()])
	var far_cells: Array = cells.keys()
	far_cells.erase(start_cell)
	far_cells.sort_custom(func(a, b): return Vector2(a - start_cell).length() > Vector2(b - start_cell).length())

	match objective:
		"nidos":
			objective_target = clampi(3 + level / 4, 3, 6)
			for i in objective_target:
				var c: Vector2i = far_cells[i % far_cells.size()]
				var nest := spawn_enemy("nest", _free_point_in(c, 0.5), level, "base")
				nests_alive += 1
				nest.set_meta("nest", true)
		"baliza":
			objective_target = 3
			var picks := far_cells.slice(0, mini(far_cells.size(), 6))
			picks.shuffle()
			for i in objective_target:
				_add_point("baliza", _free_point_in(picks[i % picks.size()], 0.5))
		"socorro":
			objective_target = 1
			_add_point("socorro", _free_point_in(far_cells[far_cells.size() / 3], 0.4))
		"escolta":
			objective_target = 1
			var cv := _add_point("convoy", gate_pos + Vector2(420, -280))
			var c_end: Vector2i = far_cells[0]
			var mid := Vector2i((start_cell.x + c_end.x) / 2, (start_cell.y + c_end.y + 1) / 2)
			cv.route = [cell_center(Vector2i(1, start_cell.y)), cell_center(mid), _free_point_in(c_end, 0.3)]
		"comandante":
			objective_target = 1

	for c in cells.keys():
		_populate_cell(c, c == start_cell)

	# Élite del sector: nodriza en la celda más lejana.
	# M6: desde el nivel 4 es un jefe con tres fases y barra propia.
	var elite_id: String = biome["elites"][0]
	var el := spawn_enemy(elite_id, _free_point_in(far_cells[0], 0.4), level, "base")
	if level >= 4:
		el.make_boss()
		boss = el

	if objective == "comandante":
		var cid: String = biome["elites"][1] if biome["elites"].size() > 1 else elite_id
		var cpos := _free_point_in(far_cells[mini(2, far_cells.size() - 1)], 0.4)
		commander = spawn_enemy(cid, cpos, level, "mega" if level >= 3 else "boss")
		commander.add_affix("comandante")
		commander.add_affix("blindado")
		commander.set_meta("objective", true)
		spawn_group_at(cpos + Vector2(120, 80), 4 + level / 8, level, true)
	if objective == "limpieza":
		objective_target = 40

	# M19: puntos de interés repartidos (alijos, pecios y vetas minerales).
	var pool: Array = cells.keys()
	pool.erase(start_cell)
	pool.shuffle()
	var n_poi := clampi(2 + map_w * map_h / 5, 3, 8)
	for i in mini(n_poi, pool.size()):
		var kind: String = ["cofre", "pecio", "veta"][rng.randi() % 3]
		var pos := _free_point_in(pool[i], 0.7)
		_add_point(kind, pos)
		if kind == "veta":
			var ore: String = biome["resources"].keys().back()
			for k in 5:
				var ap := pos + Vector2.from_angle(TAU * k / 5.0 + rng.randf()) * rng.randf_range(110.0, 220.0)
				if not is_blocked(ap, 60.0):
					_add_asteroid(pool[i], ap, rng.randf_range(38.0, 52.0), ore)


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
	# Densidad acotada: más grupos y algo mayores con el nivel, pero con tope (el mapa también crece).
	var groups := rng.randi_range(1, 2) if level < 6 else rng.randi_range(2, 3)
	if rng.randf() < float(mod.get("spawn", 1.0)) - 1.0:
		groups += 1
	for g in groups:
		spawn_group_at(_free_point_in(c, 0.8), rng.randi_range(2, 3) + mini(level / 10, 3), level, true)


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
	var r := rng.randf() / float(mod.get("elites", 1.0))
	# M9: Ultra desde el nivel 20 y Uber desde el 40 (más frecuentes con alerta y Ascensión).
	if level >= 40 and r < 0.004 + 0.002 * a + 0.002 * asc:
		return "uber"
	if level >= 20 and r < 0.01 + 0.003 * a + 0.003 * asc:
		return "ultra"
	if level >= 3 and r < 0.01 + 0.004 * a:
		return "mega"
	if r < 0.05 + 0.012 * a:
		return "boss"
	return "base"


func spawn_enemy(id: String, pos: Vector2, lvl: int, variant: String) -> Enemy:
	stat_spawned += 1
	var e := Enemy.new()
	e.setup(self, id, lvl, variant, pos)
	world.add_child(e)
	enemies.append(e)
	return e


func spawn_group_at(pos: Vector2, count: int, lvl: int, initial: bool, pool: Array = []) -> void:
	if enemies.size() >= GameData.MAX_ENEMIES:
		return
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
	if enemies.size() >= GameData.MAX_ENEMIES:
		return
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
	_update_events(delta)
	if is_instance_valid(boss) and boss.aggro and boss.plane_pos.distance_to(player.plane_pos) < 1600.0:
		Music.play("boss")
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
	if enemies.size() > GameData.MAX_ENEMIES - 20:
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
	# Sólo entre enemigos cerca de la nave (los lejanos no se ven): el coste es cuadrático.
	var near: Array[Enemy] = []
	for e in enemies:
		if e.visible and e.plane_pos.distance_squared_to(player.plane_pos) < 2000.0 * 2000.0:
			near.append(e)
	var n := near.size()
	for i in n:
		var a := near[i]
		for j in range(i + 1, n):
			var b := near[j]
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
	activate_item(id)
	hud.slot_feedback(i, true)


## Usa un consumible instantáneo (barra rápida o bot de playtest). Devuelve false si no se pudo.
func activate_item(id: String) -> bool:
	if int(run_items.get(id, 0)) <= 0 or item_cd.get(id, 0.0) > 0.0:
		return false
	match id:
		"repair":
			player.repair(0.3)
		"boost":
			player.buffs["boost_item"] = 5.0
		"shield_cell":
			player.shield = minf(player.shield_max_now(), player.shield + player.shield_max * 0.4)
		_:
			return false
	_consume_item(id)
	Sfx.play("item_use")
	return true


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
	b.add_to_group("enemy_bullets")
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


## Aura de Comandante: +20% de daño a aliados en 400 u.
func commander_near(e: Enemy) -> bool:
	for c in commanders:
		if c != e and c.plane_pos.distance_squared_to(e.plane_pos) < 160000.0:
			return true
	return false


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
	if counted:
		initial_killed += 1
	if e.has_meta("convoy"):
		convoy_left -= 1
	if e == commander:
		commander = null
		if objective == "comandante":
			objective_progress += 1
	if not by_player:
		_check_objective()
		return
	kills += 1
	var v: Dictionary = GameData.VARIANTS[e.variant]
	var rmult: float = float(v["reward"]) * asc_reward * (1.0 + 0.5 * e.affixes.size())
	if e.is_elite:
		run_elites += 1
		if mod.has("elites"):
			rmult *= 1.25
	if e.has_meta("convoy"):
		rmult *= 3.0
	if e.is_boss:
		rmult *= 4.0
	if not e.is_nest:
		kills_by[e.id] = int(kills_by.get(e.id, 0)) + 1
	_award_xp(GameData.enemy_xp(float(e.def["hp"]), level, rmult))
	# Créditos y Nexo se acreditan al instante; los materiales quedan en una caja de botín.
	var credits := int(GameData.level_reward(float(e.def["credits"]), level) * rmult * GameData.CREDIT_MULT * float(mod.get("credits", 1.0)))
	_gain("credits", credits)
	var nexo_chance: float = float(e.def["nexo"]) * rmult * float(mod.get("nexo", 1.0))
	if e.variant != "base":
		nexo_chance += 0.12 * (rmult - 1.0)
	if rng.randf() < nexo_chance:
		_gain("nexo", maxi(1, int(rmult) - 1))
	var contents := {}
	for mat in e.def["drops"].keys():
		var q: float = GameData.level_reward(float(e.def["drops"][mat]), level) * rmult * float(mod.get("mats", 1.0))
		var rare: bool = GameData.MATERIALS.get(mat, {}).get("rarity", 0) >= 2
		var n := int(ceil(q)) if rare else int(round(q))
		if n > 0:
			contents[mat] = n
	spawn_box(contents, e.plane_pos, e.is_elite or e.variant != "base", _box_tier(e))
	if e.is_boss:
		_on_boss_killed(e)
	_check_objective()


## M10: niveles de caja. Oro 4%; legendaria 0,5% (5% élites, siempre el jefe).
func _box_tier(e: Enemy) -> String:
	if e.is_boss:
		return "legendary"
	var r := rng.randf()
	if r < (0.05 if e.is_elite else 0.005):
		return "legendary"
	if r < (0.15 if e.is_elite else 0.045):
		return "gold"
	return "rare" if e.is_elite else "normal"


## M6: el jefe garantiza un módulo Reliquia (o mejor) y Nexo extra.
func _on_boss_killed(_e: Enemy) -> void:
	boss = null
	boss_dead = true
	var m := GameState.roll_module(4 if rng.randf() < 0.15 else 3)
	run_modules.append(m)
	hud.toast("¡JEFE DERROTADO! Módulo obtenido: %s" % GameState.module_label(m), 5.0, UiTheme.WARN)
	_gain("nexo", 5 + level / 4)
	Sfx.play("objective")
	Music.play(biome_id)


# --- M5/M19: puntos de objetivo e interés, eventos aleatorios -------------------------------
func _add_point(kind: String, pos: Vector2) -> ObjPoint:
	var pt := ObjPoint.new()
	pt.setup(self, kind, pos)
	world.add_child(pt)
	points.append(pt)
	return pt


func on_poi(pt: ObjPoint, text: String) -> void:
	run_pois += 1
	hud.toast(text, 6.0 if pt.kind == "pecio" else 3.0, ObjPoint.COLORS[pt.kind])
	Sfx.play("pickup_rare", null, -6.0)
	_award_xp(GameData.level_kill_xp(level) * 2)


func on_point_done(pt: ObjPoint) -> void:
	objective_progress += 1
	if pt.kind == "convoy":
		_gain("credits", int(GameData.level_reward(4000.0, level) * GameData.CREDIT_MULT * asc_reward))
	if objective_progress < objective_target:
		hud.toast("%s completada (%d/%d)" % [pt.label(), objective_progress, objective_target], 2.5, UiTheme.GOOD)
	_check_objective()


func on_objective_failed(text: String) -> void:
	if objective_done:
		return
	hud.toast(text + " — nuevo objetivo: limpieza del sector", 4.0, UiTheme.BAD)
	objective = "fallido"
	objective_target = 40
	Sfx.play("ui_error")
	_check_objective()


func _update_events(delta: float) -> void:
	if showcase or demo and not bot:
		return
	if event == "":
		event_t -= delta
		if event_t <= 0.0:
			_start_event("lluvia" if rng.randf() < 0.5 else "convoy")
		return
	event_time -= delta
	match event:
		"lluvia":
			event_tick -= delta
			if event_tick <= 0.0:
				event_tick = 0.6
				var p := player.plane_pos + player.velocity * 0.8 + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(0.0, 380.0)
				telegraph_circle(p, 90.0, 1.1, GameData.level_dmg(160.0, level), Color("ff9a4a"))
			if event_time <= 0.0:
				_end_event(player.alive, "Lluvia de meteoritos superada")
		"convoy":
			if convoy_left <= 0:
				_end_event(true, "Convoy enemigo destruido")
			elif event_time <= 0.0:
				_end_event(false, "El convoy enemigo ha escapado")


func _start_event(kind: String) -> void:
	event = kind
	match kind:
		"lluvia":
			event_time = 20.0
			hud.toast("EVENTO: ¡lluvia de meteoritos! Esquiva las zonas marcadas", 4.0, Color("ff9a4a"))
		"convoy":
			event_time = 75.0
			# Convoy de cargueros enemigos que cruza el mapa: mucho botín si lo destruyes a tiempo.
			var from := constrain(player.plane_pos + Vector2.from_angle(rng.randf() * TAU) * 1100.0, 80.0)
			var to := Vector2(bounds.end.x - from.x, bounds.end.y - from.y)
			var ids: Array = biome["enemies"].keys()
			ids.sort_custom(func(a, b): return float(GameData.ENEMIES[a]["hp"]) > float(GameData.ENEMIES[b]["hp"]))
			convoy_left = 4
			for i in convoy_left:
				var e := spawn_enemy(ids[i % 2], from + Vector2(i * 70.0, i * 40.0), level, "boss")
				e.home = to
				e.speed *= 1.6
				e.set_meta("convoy", true)
			hud.toast("EVENTO: un convoy enemigo cruza el sector. ¡Destrúyelo antes de que escape!", 4.0, UiTheme.WARN)
	Sfx.play("alert", null, -8.0)


func _end_event(ok: bool, text: String) -> void:
	if ok:
		run_events += 1
		hud.toast(text + " · +XP", 3.0, UiTheme.GOOD)
		_award_xp(GameData.level_kill_xp(level) * 5)
	else:
		hud.toast(text, 3.0, UiTheme.WARN)
	if event == "convoy":
		for e in enemies.duplicate():
			if e.has_meta("convoy") and e.alive and not e.aggro:
				e.alive = false
				enemies.erase(e)
				e.queue_free()
	event = ""
	event_t = rng.randf_range(130.0, 200.0)


func _clear_percent() -> int:
	if initial_enemies.is_empty():
		return 100
	return int(100.0 * initial_killed / initial_enemies.size())


func _check_objective() -> void:
	if objective_done:
		return
	var done := false
	if objective in ["limpieza", "fallido"]:
		done = _clear_percent() >= objective_target
	else:
		done = objective_progress >= objective_target
	if done:
		objective_done = true
		hud.toast("OBJETIVO COMPLETADO — vuelve al portal para extraer", 5.0, UiTheme.GOOD)
		_award_xp(GameData.level_kill_xp(level) * GameData.OBJECTIVE_XP_KILLS)
		Sfx.play("objective")
		Sfx.voice("objective")


func _objective_text() -> String:
	match objective:
		"limpieza":
			return "Limpieza: %d%% / %d%%" % [_clear_percent(), objective_target]
		"nidos":
			return "Destruir nidos: %d / %d" % [objective_progress, objective_target]
		"baliza":
			var cur := ""
			for pt in points:
				if pt.kind == "baliza" and pt.started and not pt.done:
					cur = "  (activando %d%%)" % int(pt.progress * 100.0)
			return "Activar balizas: %d / %d%s" % [objective_progress, objective_target, cur]
		"socorro":
			for pt in points:
				if pt.kind == "socorro" and pt.started and not pt.done:
					return "Resiste junto a la señal: %d%%" % int(pt.progress * 100.0)
			return "Responde a la señal de socorro"
		"escolta":
			for pt in points:
				if pt.kind == "convoy":
					return "Escolta el convoy: %d%% · casco %d%%" % [int(pt.progress * 100.0), int(100.0 * maxf(0.0, pt.hp) / pt.hp_max)]
			return "Escolta el convoy"
		"comandante":
			return "Elimina al comandante enemigo"
		"fallido":
			return "Objetivo fallido — limpia el sector: %d%% / %d%%" % [_clear_percent(), objective_target]
	return ""


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


func spawn_box(contents: Dictionary, p: Vector2, rare: bool, tier: String = "") -> void:
	if tier == "":
		tier = "rare" if rare else "normal"
	var extra := {}
	if tier == "gold":
		for k in contents.keys():
			contents[k] = int(contents[k]) * 2
		extra["nexo"] = 1
	elif tier == "legendary":
		for k in contents.keys():
			contents[k] = int(contents[k]) * 3
		extra["nexo"] = 3 + level / 5
		extra["module"] = 2 if rng.randf() < 0.7 else 3
	# 5% de premio gordo: contenido x5.
	if tier != "normal" and rng.randf() < 0.05:
		for k in contents.keys():
			contents[k] = int(contents[k]) * 5
		extra["jackpot"] = true
	if contents.is_empty() and extra.is_empty():
		return
	var b := LootBox.new()
	b.setup(self, contents, p + Vector2(rng.randf_range(-12, 12), rng.randf_range(-12, 12)), rare or tier != "normal")
	b.tier = tier
	b.extra = extra
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
	if not b.counted:
		b.counted = true
		run_boxes += 1
		if b.tier == "legendary":
			run_legendary += 1
	_claim_box_extra(b)
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


## Nexo y módulo de las cajas de oro / legendarias (no ocupan bodega, se cobran al abrirlas).
func _claim_box_extra(b: LootBox) -> void:
	if b.extra.is_empty():
		return
	if b.extra.get("jackpot", false):
		hud.toast("¡PREMIO GORDO! Contenido x5", 3.0, UiTheme.WARN)
		Sfx.play("jackpot")
	_gain("nexo", int(b.extra.get("nexo", 0)))
	if b.extra.has("module"):
		var m := GameState.roll_module(int(b.extra["module"]))
		run_modules.append(m)
		hud.toast("Caja legendaria: %s" % GameState.module_label(m), 4.0, Color("ff8a2a"))
		Sfx.play("pickup_rare")
	b.extra = {}


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
		# M12: con seguro de carga se conserva el 50%; sin él, sólo el 10%.
		var keep := GameData.INSURED_KEEP if params.get("insured", false) else 1.0 - GameData.DEATH_LOOT_LOSS
		for k in final_loot.keys():
			final_loot[k] = int(final_loot[k] * keep)
	var result := {
		"outcome": outcome, "level": level, "loot": final_loot, "raw_loot": loot,
		"ammo_used": ammo_used, "items_used": items_used, "kills": kills,
		"objective_done": objective_done and outcome != "death", "time": elapsed,
		"xp": run_xp, "kills_by": kills_by, "biome": biome_id, "asc": asc,
		"modules": run_modules if outcome != "death" or params.get("insured", false) else [],
		"boss_killed": boss_dead, "elites": run_elites, "boxes": run_boxes, "pois": run_pois,
		"events": run_events, "legendary": run_legendary,
	}
	if outcome == "extract":
		hud.show_result(result)
		await hud.result_closed
	finished.emit(result)


# --- Demo (captura automática / CI) --------------------------------------------------------
func _demo_autopilot(delta: float) -> void:
	demo_timer -= delta
	if bot:
		_bot_tick(delta)
		if objective_done or (player.hull / player.hull_max < 0.15 and int(run_items.get("repair", 0)) == 0):
			collect_target = null
			player.target = null
			player.move_target = gate_pos
			player.has_move_target = true
			if player.plane_pos.distance_to(gate_pos) < 200.0:
				request_extract()
			return
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


# --- Bot de playtest: decide como un jugador razonable y registra métricas ---------------------
func _bot_tick(_delta: float) -> void:
	stat_max_enemies = maxi(stat_max_enemies, enemies.size())
	var ag := 0
	for e in enemies:
		if e.aggro:
			ag += 1
	stat_max_aggro = maxi(stat_max_aggro, ag)
	if stat_cargo_full_t < 0.0 and cargo_used >= cargo_capacity() * 0.98:
		stat_cargo_full_t = elapsed
	if stat_objective_t < 0.0 and objective_done:
		stat_objective_t = elapsed
	var hp := player.hull / player.hull_max
	if hp < 0.45 and activate_item("repair"):
		stat_items_used += 1
	if player.shield <= 1.0 and activate_item("shield_cell"):
		stat_items_used += 1
	if player.ability_cd <= 0.0 and player.target_valid():
		player.try_ability()
	if hp < 0.35:
		player.try_boost()
	# Munición fuerte contra élites, básica contra el resto.
	var elite: bool = player.target is Enemy and (player.target as Enemy).is_elite
	if elite and int(run_ammo.get("mk2", 0)) > 50:
		active_ammo = "mk2"
	elif int(run_ammo.get("mk1", 0)) > 0:
		active_ammo = "mk1"
	# Bodega casi llena: refina lo menos valioso (escudo si no hay buff, si no láser).
	if cargo_used > cargo_capacity() * 0.85:
		var mats := cargo_materials()
		if not mats.is_empty():
			refine(mats.front(), 20, "shield" if shield_buff["time"] < 600.0 else "laser")
			stat_refined += 20
	if drone.ability_cd <= 0.0 and player.target_valid():
		drone.use_ability()


## Suma XP (jugador y pet) y avisa de ascensos con sus recompensas (M2, M3).
func _award_xp(xp: int) -> void:
	xp = int(xp * xp_mult)
	run_xp += xp
	var pet_before := GameState.pet_level()
	if GameState.add_xp(xp) > 0:
		var log: Array = GameState.data["rank_log"]
		var last: Dictionary = log.back() if not log.is_empty() else {}
		hud.toast("¡ASCENSO! %s — Nivel %d" % [GameState.rank_name(), GameState.level()], 4.0, UiTheme.WARN)
		if not last.is_empty():
			hud.toast("Recompensa: " + ", ".join(last["rewards"]), 5.0, UiTheme.GOOD)
		Sfx.play("objective")
		Sfx.voice("rank_up", true)
	if GameState.pet_level() > pet_before:
		hud.toast("Tu pet sube al nivel %d" % GameState.pet_level(), 3.0, Color("5affc8"))
