class_name AudioPanel
extends VBoxContainer
## Controles de volumen (General, Música, Efectos, Láseres, Voz) en 10 cuadritos de 10% (VolumeBars).
## Se usa en Ajustes y en la pausa.

const CHANNELS := [["master", "General"], ["music", "Música"], ["sfx", "Efectos"], ["lasers", "Láseres"], ["voice", "Voz de la IA"]]


func _ready() -> void:
	add_theme_constant_override("separation", 8)
	var a: Dictionary = GameState.data["settings"]["audio"]
	for ch in CHANNELS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var l := UiTheme.label(ch[1], 16)
		l.custom_minimum_size.x = 130
		row.add_child(l)
		var bars := VolumeBars.new()
		bars.set_level(int(round(float(a.get(ch[0], 0.8)) * VolumeBars.COUNT)))
		bars.custom_minimum_size = Vector2(VolumeBars.COUNT * 26 + (VolumeBars.COUNT - 1) * VolumeBars.GAP, 26)
		bars.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(bars)
		var gap := Control.new()
		gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(gap)
		var pct := UiTheme.label("%d%%" % (bars.level * 10), 16, UiTheme.ACCENT if bars.level > 0 else UiTheme.MUTED)
		pct.custom_minimum_size.x = 60
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(pct)
		var key: String = ch[0]
		bars.level_changed.connect(func(lv: int):
			var v := lv / float(VolumeBars.COUNT)
			Sfx.set_volume(key, v)
			pct.text = "%d%%" % (lv * 10)
			pct.add_theme_color_override("font_color", UiTheme.ACCENT if lv > 0 else UiTheme.MUTED)
			if key == "lasers":
				Sfx.play("laser_mk1", null, 0.0, 0.0)
			elif key == "sfx":
				Sfx.play("pickup", null, 0.0, 0.0)
			elif key == "voice" and not bars.has_meta("tested"):
				bars.set_meta("tested", true)
				Sfx.voice("shield_down"))
		bars.released.connect(GameState.save_game)
		add_child(row)
