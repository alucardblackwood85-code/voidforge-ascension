class_name Projectile
extends Node2D
## Rayo del jugador (guiado o recto) o proyectil enemigo (lento y visible: 4.4).

var sector: Sector
var plane_pos := Vector2.ZERO
var dir := Vector2.RIGHT
var speed := 1500.0
var damage := 0.0
var info: Dictionary = {}
var target: Entity = null
var hostile := false
var size := 4.0
var color := Color.RED
var life := 1.2
var pierce_left := 0
var hit_list: Array = []
var trail := Vector2.ZERO
var lift_h := 16.0   # altura visual (igual a la del que dispara)
var src := "?"      # arquetipo que lo disparó (diagnóstico)
var homing := 0.0   # rad/s de giro hacia la nave (proyectiles enemigos teledirigidos)


func _process(delta: float) -> void:
	life -= delta
	if life <= 0.0:
		queue_free()
		return
	if target and is_instance_valid(target) and target.alive:
		var to := target.plane_pos - plane_pos
		if to.length() <= speed * delta + target.radius * 0.5:
			_hit_enemy(target)
			return
		dir = to.normalized()
	elif target != null:
		target = null
	# La munición atraviesa el terreno: sólo las naves colisionan con asteroides.
	plane_pos += dir * speed * delta
	if hostile and homing > 0.0 and sector.player.alive and not sector.player.invulnerable:
		var want := (sector.player.plane_pos - plane_pos).angle()
		dir = Vector2.from_angle(rotate_toward(dir.angle(), want, homing * delta))
	if hostile:
		var p := sector.player
		if p.alive and plane_pos.distance_to(p.plane_pos) < p.radius + size:
			if p.try_reflect(damage):
				hostile = false
				homing = 0.0
				dir = -dir
				sector.fx_spark(plane_pos, Color("9ad8ff"))
				return
			sector.cur_src = "disparo-" + src
			p.take_damage(damage)
			sector.fx_spark(plane_pos, color)
			queue_free()
			return
	elif target == null:
		var e := sector.enemy_at(plane_pos, size, hit_list)
		if e:
			_hit_enemy(e)
			return
	position = Iso.to_screen(plane_pos)
	queue_redraw()


func _hit_enemy(e: Entity) -> void:
	if damage > 0.0:
		e.take_hit(damage, info)
		sector.fx_spark(e.plane_pos, color)
	if info.get("effect", "") == "chain":
		sector.chain_from(e, damage * 0.7, info, 2)
	if info.get("effect", "") == "pierce" and pierce_left > 0:
		pierce_left -= 1
		hit_list.append(e)
		target = null
		return
	queue_free()


func _draw() -> void:
	var tail := Iso.to_screen(-dir * (14.0 if hostile else 36.0))
	var lift := Vector2(0, -lift_h)
	if hostile:
		draw_circle(lift, size * 1.6, Color(color, 0.25))
		draw_circle(lift, size, color.lightened(0.3))
		draw_line(lift, lift + tail, Color(color, 0.5), size)
	else:
		# Un solo color por láser: halo y núcleo del mismo tono.
		draw_line(lift, lift + tail, Color(color, 0.35), 7.0)
		draw_line(lift, lift + tail * 0.85, color.lightened(0.2), 3.0)
