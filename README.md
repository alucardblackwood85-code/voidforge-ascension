# VOIDFORGE: ASCENSION

Shooter espacial isométrico 2D con progresión persistente, hecho en **Godot 4.7** (GDScript).
Diseño completo en [`docs/GDD_VOIDFORGE_ASCENSION_v0_2_final.docx`](docs/GDD_VOIDFORGE_ASCENSION_v0_2_final.docx).

▶ **Jugar en el navegador (también en el móvil):** https://alucardblackwood85-code.github.io/voidforge-ascension/

Cada `push` a `main` compila automáticamente la versión web (GitHub Pages) y una build de Windows
(descargable como artefacto en la pestaña *Actions*).

## Controles (mouse-first, GDD §4.2)
| Acción | Control |
|---|---|
| Mover | Clic izquierdo en el mapa (mantener para guiar) · WASD opcional |
| Seleccionar objetivo | Clic izquierdo sobre enemigo o depósito de recursos |
| Disparar | Mantener clic derecho |
| Habilidad de nave / Impulso / Dron | Q / Espacio / E |
| Barra rápida | 1-0 (munición, consumibles, minas) |
| Mapa táctico / Interactuar / Zoom | Tab / F / rueda |
| Cancelar objetivo / Pausa | Esc |

En móvil: toca para mover/seleccionar; botones en pantalla para FUEGO (auto), impulso, habilidad y dron.

## Estructura
```
scripts/autoload/  game_data.gd (tablas de balance del GDD) · game_state.gd (perfil y guardado) · controls.gd
scripts/sector/    sector.gd (mapa procedural, oleadas, alerta, botín, extracción) · ground.gd · backdrop.gd
scripts/entities/  player_ship · enemy (arquetipos de IA) · projectile · loot · asteroid · drone · fx
scripts/ui/        hud.gd · hotbar_slot.gd · ui_theme.gd
scripts/hangar/    hangar.gd
tools/             gen_art.ps1 + art_manifest.json (sprites con la API de OpenAI)
```

## Arte
Las naves usan siluetas procedurales hasta que existan sprites en `assets/sprites/<grupo>/<id>.png`
(vista cenital, frente hacia la derecha, fondo transparente). Generarlos:
```powershell
[Environment]::SetEnvironmentVariable("OPENAI_API_KEY", "sk-...", "User")   # una sola vez
.\tools\gen_art.ps1
```

## Desarrollo
- Abrir `project.godot` con Godot 4.7.
- Demo automática (para pruebas): `godot -- --sector`
- Registro de decisiones: [`docs/DEVLOG.md`](docs/DEVLOG.md)
