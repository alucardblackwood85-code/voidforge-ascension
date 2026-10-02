class_name LootBox
extends Entity
## Caja de botín (estilo MMO espacial): contiene los materiales que soltó un enemigo o un depósito.
## Se recoge haciendo clic izquierdo sobre ella (la nave va hasta la caja) o con habilidades de imán.
## Lo que no cabe en la bodega se queda dentro. Desaparece tras LOOT_BOX_LIFE segundos.

var contents: Dictionary = {}
var rare := false
var life := GameData.LOOT_BOX_LIFE
var bob := 0.0


func setup(p_sector: Sector, p_contents: Dictionary, pos: Vector2, p_rare: bool) -> void:
	sector = p_sector
	contents = p_contents
	rare = p_rare
	plane_pos = pos
	radius = 22.0
	bob = randf() * TAU
	sync_screen()


func total() -> int:
	var t := 0
	for k in contents.keys():
		t += int(contents[k])
	return t


func tooltip() -> String:
	var parts: PackedStringArray = []
	for k in contents.keys():
		parts.append("%s x%d" % [GameData.mat_name(k), int(contents[k])])
	return ", ".join(parts)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0 or contents.is_empty():
		sector.remove_box(self)
		return
	bob += delta * 2.5
	visible = plane_pos.distance_to(sector.player.plane_pos) < 2300.0
	if visible:
		queue_redraw()


func _draw() -> void:
	var h := 14.0 + sin(bob) * 3.0
	var fade := clampf(life / 10.0, 0.25, 1.0)
	var glow := Color("ffb84a") if rare else Color("4affff")
	draw_shadow(16.0, 0.3 * fade)
	draw_ring(radius * (1.2 + 0.1 * sin(bob * 1.3)), Color(glow, 0.35 * fade), 2.0)
	var tex := SpriteLib.get_tex("loot", "cargo_box_rare" if rare else "cargo_box")
	if tex:
		var s := 52.0 if rare else 44.0
		draw_texture_rect(tex, Rect2(-s * 0.5, -h - s * 0.6, s, s), false, Color(1, 1, 1, fade))
	else:
		draw_rect(Rect2(-14, -h - 14, 28, 22), Color(0.2, 0.3, 0.35, fade))
		draw_rect(Rect2(-14, -h - 14, 28, 22), Color(glow, fade), false, 2.0)
	var targeted: bool = sector.collect_target == self
	if targeted or sector.hover_box == self:
		draw_ring(radius * 1.6, Color(1, 1, 1, 0.8), 2.0)
		var f := ThemeDB.fallback_font
		var txt := "%d u" % total()
		draw_string_outline(f, Vector2(-40, -h - 36), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, 3, Color.BLACK)
		draw_string(f, Vector2(-40, -h - 36), txt, HORIZONTAL_ALIGNMENT_CENTER, 80, 13, glow.lightened(0.4))
