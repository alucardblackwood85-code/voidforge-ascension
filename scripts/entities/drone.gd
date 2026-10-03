class_name Drone
extends Entity
## Dron acompañante / pet (10). Roles: Asalto (dispara al objetivo) y Recolector (botín).
## Usa los láseres de dron equipados en Equipamiento → Pet; ataca automáticamente con la nave.

const ROLES := {
	"asalto": {"name": "Asalto", "ability": "Ráfaga: triplica la cadencia del dron 4 s.", "cd": 15.0},
	"recolector": {"name": "Recolector", "ability": "Barrido: atrae todo el botín en 600 u.", "cd": 12.0},
}
const FIRE_INTERVAL := 1.6

var role := "asalto"
var fire_timer := 0.5
var burst := 0.0
var ability_cd := 0.0
var heading := 0.0
var lasers: Array = []   # [{id, def, hits}]
# Movimiento de guardia: escolta con desplazamientos aleatorios, sale a atacar desde varios ángulos
# y vuelve con la nave (nada de orbitar como una luna).
var mode := "escort"     # escort | attack | return | fetch
var waypoint := Vector2.ZERO
var repick := 0.0
var mode_time := 0.0
var fetch_box: LootBox = null
var attack_len := 5.0
var pet_lvl := 1
var guard_t := 0.3
var locked := false       # M11: el pet se desbloquea tras 2 incursiones


func setup(p_sector: Sector, p_role: String) -> void:
	sector = p_sector
	role = p_role
	pet_lvl = GameState.pet_level()
	radius = 12.0
	height = 34.0
	plane_pos = sector.player.plane_pos + Vector2(-40, 0)
	waypoint = plane_pos
	for l in GameState.equipped_drone_lasers():
		lasers.append({"id": l["id"], "def": l["def"], "hits": 0})


func _set_mode(m: String) -> void:
	mode = m
	mode_time = 0.0
	repick = 0.0
	if m == "attack":
		attack_len = randf_range(4.0, 7.0)


func _think(delta: float, p: PlayerShip) -> void:
	mode_time += delta
	repick -= delta
	var has_target := p.target_valid() and p.target is Enemy and p.plane_pos.distance_to(p.target.plane_pos) < 900.0
	match mode:
		"escort":
			if role == "asalto" and has_target and mode_time > 0.6:
				_set_mode("attack")
			elif role == "recolector" and mode_time > 0.8:
				fetch_box = _nearest_box(p, 700.0)
				if fetch_box:
					_set_mode("fetch")
			if repick <= 0.0 or plane_pos.distance_to(waypoint) < 20.0:
				repick = randf_range(1.0, 2.4)
				waypoint = p.plane_pos + Vector2.from_angle(randf() * TAU) * randf_range(70.0, 170.0)
			else:
				# El punto de escolta se mueve con la nave.
				waypoint += p.velocity * delta
		"attack":
			if not has_target or mode_time > attack_len:
				_set_mode("return")
			elif repick <= 0.0:
				# Nuevo ángulo de ataque alrededor del objetivo.
				repick = randf_range(0.8, 1.6)
				waypoint = p.target.plane_pos + Vector2.from_angle(randf() * TAU) * randf_range(150.0, 280.0)
		"return":
			waypoint = p.plane_pos + (plane_pos - p.plane_pos).normalized() * 80.0
			if plane_pos.distance_to(p.plane_pos) < 120.0 or mode_time > 3.0:
				_set_mode("escort")
		"fetch":
			if fetch_box == null or not is_instance_valid(fetch_box) or not fetch_box.alive or fetch_box.contents.is_empty():
				_set_mode("return")
			else:
				waypoint = fetch_box.plane_pos
				if plane_pos.distance_to(waypoint) < 40.0:
					sector.collect_box(fetch_box)
					fetch_box = null
					_set_mode("return")


func _nearest_box(p: PlayerShip, r: float) -> LootBox:
	var best: LootBox = null
	var best_d := r
	for b in sector.boxes:
		var d: float = b.plane_pos.distance_to(p.plane_pos)
		if d < best_d:
			best_d = d
			best = b
	return best


func _process(delta: float) -> void:
	if locked:
		visible = false
		return
	var p := sector.player
	if not p.alive:
		return
	_think(delta, p)
	_guard(delta, p)
	var to := waypoint - plane_pos
	var dist := to.length()
	var top := 560.0 if mode in ["attack", "fetch"] else maxf(320.0, p.velocity.length() * 1.3)
	var desired := to / maxf(dist, 1.0) * top * clampf(dist / 90.0, 0.0, 1.0)
	velocity = velocity.move_toward(desired, 1400.0 * delta)
	plane_pos += velocity * delta
	var face := (p.target.plane_pos - plane_pos) if (p.target_valid() and mode == "attack") else velocity
	if face.length() > 4.0:
		heading = lerp_angle(heading, face.angle(), clampf(10.0 * delta, 0.0, 1.0))
	ability_cd = maxf(0.0, ability_cd - delta)
	burst = maxf(0.0, burst - delta)
	if role == "asalto" and not lasers.is_empty():
		fire_timer -= delta * (3.0 if burst > 0.0 else 1.0)
		if fire_timer <= 0.0 and p.firing and p.target_valid() and plane_pos.distance_to(p.target.plane_pos) < GameData.LASER_RANGE:
			fire_timer = FIRE_INTERVAL * (1.0 - GameData.PET_RATE_PER_LEVEL * (pet_lvl - 1))
			_fire(p)
	sync_screen()
	queue_redraw()


func _fire(p: PlayerShip) -> void:
	for l in lasers:
		var def: Dictionary = l["def"]
		var dmg: float = GameData.LASER_BASE_DAMAGE * float(def["dmg"]) * sector.active_ammo_mult() * 0.5 * FIRE_INTERVAL * (1.0 + GameData.PET_DMG_PER_LEVEL * (pet_lvl - 1))
		l["hits"] += 1
		var info := {"effect": "", "color": def["color"]}
		match def["effect"]:
			"stinger":
				if l["hits"] % 5 == 0:
					dmg *= 2.0
					info["crit"] = true
			"chain":
				info["effect"] = "chain"
			"pet_ion":
				info["effect"] = "pet_ion"
			"marker":
				p.marked = p.target
				p.marked_time = 3.0
		sector.spawn_player_bolt(plane_pos, p.target, dmg, info)
	Sfx.play("laser_drone", plane_pos, -9.0)


func use_ability() -> void:
	if locked:
		return
	if ability_cd > 0.0:
		return
	ability_cd = ROLES[role]["cd"]
	Sfx.play("drone_ability")
	if role == "asalto":
		burst = 4.0
	else:
		sector.pull_loot(sector.player.plane_pos, 600.0)
	sector.fx_ring(plane_pos, 40.0, Color("5affc8"))


func pickup_bonus() -> float:
	return (1.6 + 0.05 * (pet_lvl - 1)) if role == "recolector" else 1.0


func _draw() -> void:
	var tex := SpriteLib.get_tex("drone", "drone")
	if tex:
		SpriteLib.draw_dir(self, "drone", "drone", tex, 14.0, heading, height)
	else:
		var pts := [Vector2(1.0, 0), Vector2(-0.6, 0.7), Vector2(-0.3, 0), Vector2(-0.6, -0.7)]
		Shapes.draw_hull(self, pts, 12.0, heading, height, Color("2a6a5a"), Color("5affc8"), Color("ffffff"))


## Pet-Guard: cada 0,3 s, 5% de destruir cada proyectil enemigo cerca de la nave.
func _guard(delta: float, p: PlayerShip) -> void:
	guard_t -= delta
	if guard_t > 0.0:
		return
	guard_t = 0.3
	var has := false
	for l in lasers:
		if l["def"]["effect"] == "guard":
			has = true
	if not has:
		return
	for b in get_tree().get_nodes_in_group("enemy_bullets"):
		var pr := b as Projectile
		if pr.hostile and pr.plane_pos.distance_to(p.plane_pos) < 260.0 and randf() < 0.05:
			sector.fx_spark(pr.plane_pos, Color("e8e8f0"))
			pr.queue_free()
