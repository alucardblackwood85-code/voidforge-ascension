class_name PageSettings
extends HBoxContainer
## AJUSTES: volumen (general, música, efectos, láseres, voz), teclas reasignables y escala de
## interfaz (M16), copia de seguridad por código (M17) y reinicio del progreso.

var menu: StartMenu
var _waiting := ""            # acción que espera una tecla nueva
var _wait_btn: Button = null


func _ready() -> void:
	add_theme_constant_override("separation", 14)
	var left := W.vbox(10)
	left.custom_minimum_size.x = 620
	var afr: Array = W.frame("Sonido")
	var audio: Control = afr[0]
	var av: VBoxContainer = afr[1]
	av.add_child(AudioPanel.new())
	av.add_child(UiTheme.label("La música cambia según el bioma y se intensifica en combate y contra el jefe.", 13, UiTheme.MUTED))
	left.add_child(audio)
	# Escala de interfaz
	var sfr: Array = W.frame("Pantalla")
	var sc: Control = sfr[0]
	var sv: VBoxContainer = sfr[1]
	var row := W.hbox(10)
	row.add_child(UiTheme.label("Escala de interfaz", 15))
	var slider := HSlider.new()
	slider.min_value = 0.75
	slider.max_value = 1.6
	slider.step = 0.05
	slider.value = Controls.ui_scale()
	slider.custom_minimum_size.x = 260
	slider.focus_mode = Control.FOCUS_NONE
	var val := UiTheme.label("%d%%" % int(slider.value * 100), 15, UiTheme.ACCENT)
	slider.value_changed.connect(func(v): val.text = "%d%%" % int(v * 100))
	slider.drag_ended.connect(func(_c): Controls.set_ui_scale(slider.value))
	row.add_child(slider)
	row.add_child(val)
	sv.add_child(row)
	sv.add_child(UiTheme.label("Aumenta la escala en móviles y tabletas para pulsar los botones con comodidad.", 12, UiTheme.MUTED))
	left.add_child(sc)
	# Copia de seguridad
	var bfr: Array = W.frame("Copia de seguridad")
	var bk: Control = bfr[0]
	var bv: VBoxContainer = bfr[1]
	bv.add_child(UiTheme.label("Exporta tu partida como código para guardarla o pasarla a otro dispositivo.", 12, UiTheme.MUTED))
	var code := TextEdit.new()
	code.custom_minimum_size = Vector2(0, 70)
	code.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	code.placeholder_text = "Pega aquí un código para importar…"
	bv.add_child(code)
	var brow := W.hbox(8)
	var do_export := func():
		code.text = GameState.export_code()
		DisplayServer.clipboard_set(code.text)
		Sfx.play("ui_click")
		_toast(bv, "Código copiado al portapapeles.", UiTheme.GOOD)
	brow.add_child(W.btn("Exportar y copiar", do_export, "primary", 200))
	var do_import := func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "¿Reemplazar la partida actual por la del código?"
		dlg.confirmed.connect(func():
			if GameState.import_code(code.text):
				Sfx.play("objective")
			else:
				Sfx.play("ui_error")
				_toast(bv, "Código no válido.", UiTheme.BAD))
		menu.add_child(dlg)
		dlg.popup_centered()
	brow.add_child(W.btn("Importar", do_import, "normal", 150))
	bv.add_child(brow)
	left.add_child(bk)
	add_child(W.scroll(left))

	var right := W.vbox(10)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var cfr: Array = W.frame("Controles")
	var ctl: Control = cfr[0]
	var cv: VBoxContainer = cfr[1]
	var th := W.hbox(10)
	th.add_child(W.spacer())
	var reset_keys := func():
		Controls.reset_keys()
		menu.refresh()
	th.add_child(W.btn("Teclas por defecto", reset_keys, "normal", 200, 14))
	cv.add_child(th)
	cv.add_child(UiTheme.rich("[b]Clic izquierdo[/b]: fijar objetivo o recoger cajas · [b]Clic derecho[/b]: mover la nave · [b]Rueda[/b]: zoom · [b]Esc[/b]: soltar objetivo / pausa\nAtaque automático: una andanada cada %.1f s con la munición seleccionada." % GameData.VOLLEY_INTERVAL, 14))
	cv.add_child(UiTheme.label("Haz clic en una tecla y pulsa la nueva (Esc cancela). Si ya estaba en uso, se intercambian.", 12, UiTheme.MUTED))
	var g := W.grid(4, 6)
	for pair in Controls.REBINDABLE:
		var action: String = pair[0]
		var l := UiTheme.label(pair[1], 14)
		l.custom_minimum_size.x = 180
		g.add_child(l)
		var b := Button.new()
		b.text = Controls.key_label(action)
		UiTheme.style_button(b, "normal")
		b.custom_minimum_size = Vector2(120, 34)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_start_wait.bind(action, b))
		g.add_child(b)
	cv.add_child(g)
	right.add_child(ctl)
	var dfr: Array = W.frame("Zona de peligro", UiTheme.BAD)
	var danger: Control = dfr[0]
	var dv: VBoxContainer = dfr[1]
	var reset := func():
		var dlg := ConfirmationDialog.new()
		dlg.dialog_text = "¿Borrar todo el progreso guardado? (se conservan los ajustes de sonido)"
		dlg.confirmed.connect(GameState.reset_profile)
		menu.add_child(dlg)
		dlg.popup_centered()
	dv.add_child(W.btn("Reiniciar todo el progreso", reset, "danger", 280))
	right.add_child(danger)
	right.add_child(UiTheme.label("Versión %s · guardado local (usa la copia de seguridad para no perderlo)" % ProjectSettings.get_setting("application/config/version"), 13, UiTheme.MUTED))
	add_child(right)


func _start_wait(action: String, b: Button) -> void:
	if _wait_btn:
		_wait_btn.text = Controls.key_label(_waiting)
	_waiting = action
	_wait_btn = b
	b.text = "Pulsa una tecla…"


func _input(event: InputEvent) -> void:
	if _waiting == "" or not (event is InputEventKey) or not event.pressed or event.echo:
		return
	get_viewport().set_input_as_handled()
	var k: InputEventKey = event
	var code := k.physical_keycode if k.physical_keycode != KEY_NONE else k.keycode
	if code != KEY_ESCAPE:
		Controls.rebind(_waiting, code)
		Sfx.play("ui_click")
	_waiting = ""
	_wait_btn = null
	menu.refresh()


func _toast(parent: Control, text: String, color: Color) -> void:
	var l := UiTheme.label(text, 13, color)
	parent.add_child(l)
	get_tree().create_timer(3.0).timeout.connect(l.queue_free)
