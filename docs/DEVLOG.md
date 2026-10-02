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

## v0.1.1 — Primer lote de arte (2026-10-02)
- Estilo base: naves 3D prerenderizadas, metálicas y brillantes, con iluminación cinematográfica,
  referencia de look tipo DarkOrbit (sin pixel art). Generado con `tools/gen_art.ps1` (gpt-image-1).
- 16 sprites: 5 clases de nave del jugador, 10 alienígenas Ferron y el nido. Originales en 1024 px en `assets/source/`.
- Los sprites se dibujan con menos aplastamiento iso (0.65) y escala visual 1.35x para conservar volumen.
- Modo vitrina de depuración: `godot -- --showcase`.

## v0.2.0 — Audio, 50 alienígenas, 5 biomas y mapa espacial (2026-10-02)
**Audio**
- OpenAI no ofrece generación de efectos de sonido (su API de audio es voz/transcripción), así que los SFX se
  sintetizan por procedimiento con `scripts/tools/gen_sfx.gd` → `assets/audio/sfx/*.wav` (58 sonidos).
  Se pueden reemplazar por archivos externos con el mismo nombre sin tocar código.
- Cada láser (L-01…L-18) tiene firma sonora propia; dron, disparos por facción, embestida, curación, minas,
  artillería, invocación, drenaje, fase, francotirador, reflejo, pulsos, nova, explosiones, impactos, botín,
  alerta, objetivo, extracción e interfaz. Autoload `Sfx` con atenuación por distancia y anti-saturación.
**Contenido**
- Bestiario completo del GDD: 50 especies en 5 facciones. Nuevos arquetipos: drenador, emboscador, defensor,
  francotirador, élite, control y trampa, todos con telegraph visual.
- Biomas jugables: Cinturón Ferron (1+), Nebulosa Vesper (8+), Campos Prismáticos (16+), Fractura del Vacío (24+),
  Jardín Leviatán (32+), cada uno con jefe propio. Los otros 5 biomas del GDD quedan para expansión.
- Sprite único para cada una de las 25 naves y para los 50 alienígenas; Códex en el hangar.
- Color único por láser (18 tonos distintos), un solo tono por disparo.
**Mapa**
- Sin rejilla/cuadrantes: fondo espacial por bioma (imagen generada) con parallax + estrellas.
- Mapa más grande: chunks de 2000 u y 9-20 chunks por sector. Barrera de energía sólo en el borde exterior.
- La munición ya no colisiona con el terreno; sólo nave/terreno colisionan.
**UI**
- Iconos de munición Mk-I…VI (prueba) en barra rápida y fabricación.
- Modos de depuración: `-- --sector=<bioma>` y `-- --showcase=<bioma>`.

## v0.3.0 — Controles, INICIO, economía, rangos y audio completo (2026-10-02)
**Controles (mouse + 1-0, sin WASD)**
- Clic izquierdo: fijar objetivo. Clic derecho: mover (mantener para guiar). Ataque automático.
- La nave dispara una andanada con todos sus láseres cada 1.2 s; la cadencia del GDD de cada láser se
  convierte en daño por andanada para conservar el balance. Con objetivo, la proa siempre le apunta.
**Combate**
- Enemigos: todos encaran al jugador al disparar, la bala sale del frente y a su altura visual (antes
  algunos arquetipos disparaban mirando hacia donde se movían).
- Explosión universal de nave (animación + sonido) para jugador y alienígenas; la nave desaparece.
- Voz robótica femenina (OpenAI TTS + filtro): casco crítico, escudos agotados, alerta, objetivo, ascenso.
- Muerte: se pierde el 90% de todo lo recolectado en el sector, sin ventana ni aviso; vuelta al INICIO.
  La experiencia de las bajas se conserva.
**Mapa**
- Sectores rectangulares (4-8 x 3-6 chunks de 2000 u). Obstáculos con sprites: rocas, chatarra, restos,
  depósitos minerales y elementos propios de cada bioma.
**Audio**
- Banda sonora procedural en bucle por bioma + menú (`scripts/tools/gen_music.gd`).
- Buses y deslizadores: General, Música, Efectos, Láseres y Voz (Ajustes y menú de pausa).
**INICIO (sustituye al hangar)**
- Hangar (vista previa animada + estadísticas comparadas + confirmar), Equipamiento con arrastrar y soltar
  (láseres, generadores, módulos, pet y barra rápida), Tienda por subventanas, Crafteo con inventario de
  materiales, cajas de módulos con probabilidades y pity, mejoras 1-16, Estadísticas, Códex, Ajustes y JUGAR.
- Tienda = créditos/Nexo (precio derivado de la receta); Crafteo = materiales. Mk-V/VI y cajas sólo se fabrican.
**Progresión**
- XP por bajas (proporcional a la vida base, nivel y variante). XP total para nivel N = 10 000 x 2^(N-1),
  máximo nivel 21. 21 rangos militares con insignias dibujadas por código. Bajas por tipo de enemigo.
- Módulos (4 familias, 5 rarezas, líneas secundarias) aplicados a la nave; un módulo por color.
