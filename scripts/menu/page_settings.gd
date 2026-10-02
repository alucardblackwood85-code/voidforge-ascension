class_name PageSettings
extends HBoxContainer
## AJUSTES: volumen (general, música, efectos, láseres, voz), controles y reinicio del progreso.

var menu: StartMenu


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var audio := W.card()
	audio.custom_minimum_size.x = 620
	var av := W.vbox(10)
	audio.add_child(av)
	av.add_child(W.title("Sonido"))
	av.add_child(AudioPanel.new())
	av.add_child(UiTheme.label("La música cambia según el bioma; el menú tiene su propio tema.", 13, UiTheme.MUTED))
	add_child(audio)
	var right := W.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var ctl := W.card()
	var cv := W.vbox(6)
	ctl.add_child(cv)
	cv.add_child(W.title("Controles"))
	cv.add_child(UiTheme.rich("[b]Clic izquierdo[/b]: fijar objetivo (enemigo o depósito)\n[b]Clic derecho[/b]: mover la nave (mantén pulsado para guiarla)\n[b]Ataque automático[/b]: una andanada cada %.1f s con la munición seleccionada\n[b]1 - 0[/b]: cambiar munición / usar objetos de la barra rápida\n[b]%s[/b] habilidad de nave · [b]%s[/b] impulso · [b]%s[/b] habilidad del pet\n[b]%s[/b] mapa táctico · [b]%s[/b] interactuar / extraer · [b]Rueda[/b] zoom · [b]Esc[/b] soltar objetivo / pausa" % [
		GameData.VOLLEY_INTERVAL, Controls.key_label("ability"), Controls.key_label("boost"), Controls.key_label("drone"), Controls.key_label("tactical_map"), Controls.key_label("interact")], 15))
	right.add_child(ctl)
	var danger := W.card(Color(0.1, 0.04, 0.05, 0.9), UiTheme.BAD)
	var dv := W.vbox(6)
	danger.add_child(dv)
	dv.add_child(UiTheme.label("Zona de peligro", 18, UiTheme.BAD))
	var reset := W.button("Reiniciar todo el progreso", func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "¿Borrar todo el progreso guardado? (se conservan los ajustes de sonido)"
		dlg.confirmed.connect(GameState.reset_profile)
		menu.add_child(dlg)
		dlg.popup_centered())
	dv.add_child(reset)
	right.add_child(danger)
	right.add_child(UiTheme.label("Versión %s · guardado local" % ProjectSettings.get_setting("application/config/version"), 13, UiTheme.MUTED))
	add_child(right)
