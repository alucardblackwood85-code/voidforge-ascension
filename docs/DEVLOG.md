# Devlog y decisiones

## v0.1.0 — Prototipo jugable (2026-10-02)
Objetivo del GDD §25 "Prioridad de prototipo": nave + láseres + enemigos + mapa procedural + drops + hangar mínimo.

**Implementado**
- Sector procedural por chunks (6-14 según nivel), forma de red/ramas, asteroides, depósitos minables.
- Bioma Cinturón Ferron con los 10 alienígenas de la facción Ferron y 9 arquetipos de IA
  (hostigador, enjambre, tanque, cazador, embestida, soporte, minador, artillería, nodriza) + nidos.
- Variantes Boss/Mega con multiplicadores de vida/daño/recompensa del GDD §12.1; escalado por nivel §12.2.
- Objetivos: Limpieza (70%) y Destruir nidos. Alerta del Sector creciente con oleadas.
- Control mouse-first, barra rápida 1-0 (munición, consumibles, minas con previsualización), Q/Espacio/E, Tab, zoom.
- 25 naves (20 + 5 especiales), 18 láseres con efectos, munición Mk-I…VI, 20 generadores, mejoras 1-16.
- Dron con roles Asalto y Recolector.
- Hangar: mapa estelar con "Poder recomendado", naves, armamento, generadores, fabricación, mejoras, barra rápida, dron, inventario.
- Guardado local, versión web (GitHub Pages) y Windows por CI.

**Decisiones provisionales (ajustables en `game_data.gd`)**
- Escudo base = 50% del casco (el GDD no define escudo base de nave).
- 1 punto de "Carga" = 20 unidades de material; créditos y Nexo no ocupan bodega.
- Morir o abandonar: se pierde el 50% del botín recogido (GDD §24.1 lo deja pendiente).
- Hacer clic en el suelo NO cancela el objetivo (permite kitear); Esc lo cancela.
- Cada disparo de láser consume 1 de munición. El dron no consume munición en el prototipo.
- Plataforma: PC primero, con soporte táctil básico para probar desde el móvil.

**Pendiente (MVP §22.1)**
- Módulos (4 familias, cajas, pity), 2 biomas más, 5 especies más, jefes con mecánicas, 2 objetivos más.
- Sprites definitivos, audio, backend online/servidor autoritativo, arrastrar y soltar en la barra rápida.
