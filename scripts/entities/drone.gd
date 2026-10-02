class_name Drone
extends Entity
## Dron acompañante (10). Roles del prototipo: Asalto (dispara al objetivo marcado) y Recolector.

const ROLES := {
	"asalto": {"name": "Asalto", "ability": "Ráfaga: triplica la cadencia del dron 4 s.", "cd": 15.0},
	"recolector": {"name": "Recolector", "ability": "Barrido: atrae todo el botín en 600 u.", "cd": 12.0},
}

var role := "asalto"
var orbit := 0.0
var fire_timer := 0.0
var burst := 0.0
var ability_cd := 0.0
var heading := 0.0


func setup(p_sector: Sector, p_role: String) -> void:
	sector = p_sector
	role = p_role
	radius = 10.0
	height = 34.0
	plane_pos = sector.player.plane_pos + Vector2(-40, 0)


func _process(delta: float) -> void:
	var p := sector.player
	if not p.alive:
		return
	orbit += delta * 1.4
	var want := p.plane_pos + Vector2.from_angle(orbit) * 70.0
	plane_pos = plane_pos.lerp(want, clampf(5.0 * delta, 0.0, 1.0))
	heading = lerp_angle(heading, (want - plane_pos).angle() if plane_pos.distance_to(want) > 4.0 else p.heading, 0.2)
	ability_cd = maxf(0.0, ability_cd - delta)
	burst = maxf(0.0, burst - delta)
	if role == "asalto":
		fire_timer -= delta * (3.0 if burst > 0.0 else 1.0)
		if fire_timer <= 0.0 and p.firing and p.target_valid() and plane_pos.distance_to(p.target.plane_pos) < GameData.LASER_RANGE:
			fire_timer = 0.8
			# Pet-Pulse: disparo estable, sin consumo de munición en el prototipo.
			var dmg := GameData.LASER_BASE_DAMAGE * 0.55 * sector.active_ammo_mult() * 0.5
			sector.spawn_player_bolt(plane_pos, p.target, dmg, {"effect": "", "color": Color("5affc8")})
	sync_screen()
	queue_redraw()


func use_ability() -> void:
	if ability_cd > 0.0:
		return
	ability_cd = ROLES[role]["cd"]
	if role == "asalto":
		burst = 4.0
	else:
		sector.pull_loot(sector.player.plane_pos, 600.0)
	sector.fx_ring(plane_pos, 40.0, Color("5affc8"))


func pickup_bonus() -> float:
	return 1.6 if role == "recolector" else 1.0


func _draw() -> void:
	draw_shadow(8.0, 0.25)
	var pts := [Vector2(1.0, 0), Vector2(-0.6, 0.7), Vector2(-0.3, 0), Vector2(-0.6, -0.7)]
	Shapes.draw_hull(self, pts, 12.0, heading, height, Color("2a6a5a"), Color("5affc8"), Color("ffffff"))
