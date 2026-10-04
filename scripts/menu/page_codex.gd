class_name PageCodex
extends VBoxContainer
## CÓDEX: las 50 especies alienígenas por facción, con arquetipo y estadísticas base.

const ARCH_NAMES := {
	"harasser": "Hostigador", "swarm": "Enjambre", "tank": "Tanque", "hunter": "Cazador", "charger": "Rompelíneas",
	"support": "Soporte", "miner": "Minador", "artillery": "Artillería", "mother": "Nodriza / Invocador",
	"drainer": "Drenador", "ambusher": "Emboscador", "defender": "Defensor", "sniper": "Francotirador",
	"elite": "Élite", "control": "Control", "trap": "Trampa",
}

var menu: StartMenu


func _ready() -> void:
	var list := W.vbox(10)
	var shown := {}   # una especie puede aparecer en dos mapas: se muestra sólo en el primero
	for bid in GameData.BIOMES.keys():
		var b: Dictionary = GameData.BIOMES[bid]
		if not b.has("enemies"):
			continue
		list.add_child(W.title("%s — %s (nivel %d+)" % [b["faction"], b["name"], b["min_level"]], 20))
		var g := W.grid(5, 8)
		for eid in b["enemies"].keys() + b["elites"]:
			if shown.has(eid):
				continue
			shown[eid] = true
			var e: Dictionary = GameData.ENEMIES[eid]
			var c := W.card(Color(0.05, 0.08, 0.13, 0.92), (e["accent"] as Color).darkened(0.4), 8)
			c.custom_minimum_size = Vector2(250, 0)
			var cv := W.vbox(2)
			c.add_child(cv)
			cv.add_child(W.pic(SpriteLib.get_tex("enemies", eid), Vector2(0, 110)))
			cv.add_child(UiTheme.label(e["name"], 16, (e["accent"] as Color).lerp(Color.WHITE, 0.4)))
			cv.add_child(UiTheme.label("%s · HP %d · DMG %d · VEL %d" % [ARCH_NAMES.get(e["arch"], e["arch"]), e["hp"], e["dmg"], e["vel"]], 12, UiTheme.MUTED))
			var nk := int(GameState.data["kills_by"].get(eid, 0))
			var ms := "  ·  ★ Maestría: +%d%% daño" % int(Prog.MASTERY_DMG * 100) if nk >= Prog.MASTERY_KILLS else "  ·  maestría %d/%d" % [nk, Prog.MASTERY_KILLS]
			cv.add_child(UiTheme.label("Derrotados: %d%s" % [nk, ms], 12, UiTheme.GOOD if nk >= Prog.MASTERY_KILLS else UiTheme.WARN))
			g.add_child(c)
		list.add_child(g)
	add_child(W.scroll(list))
