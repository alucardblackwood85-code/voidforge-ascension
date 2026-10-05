<#
.SYNOPSIS
  Modelos 3D del hangar: exporta cada nave de Tripo (build/tripo_models/ships/<id>/model.glb) ya orientada,
  con el sprite proyectado y reducida a ~15.000 caras a assets/models/hangar/<id>.glb (~0,5 MB), para que
  el hangar la gire en tiempo real (scripts/menu/ship_spin.gd) en lugar de usar hojas de fotogramas.

.EXAMPLE
  .\tools\build_hangar_glb.ps1
  .\tools\build_hangar_glb.ps1 -Only kestrel_a1 -Faces 20000
#>
param([string]$Only = "", [int]$Faces = 30000)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
foreach ($m in Get-ChildItem (Join-Path $root "build/tripo_models/ships") -Directory) {
    $id = $m.Name
    if ($Only -and $id -ne $Only) { continue }
    if (-not (Test-Path (Join-Path $m.FullName "model.glb"))) { continue }
    $out = Join-Path $root "assets/models/hangar/$id.glb"
    # Con textura de Tripo (model_tex.glb, tools/tripo_ships.py --retexture) se conserva su material PBR;
    # si no, el sprite proyectado desde arriba (perfil hy3d).
    $hasTex = Test-Path (Join-Path $m.FullName "model_tex.glb")
    $prof = if ($hasTex) { "raw+tex" } else { "hy3d" }
    $glbArg = if ($hasTex) { "glbname=model_tex.glb" } else { "glbname=model.glb" }
    # Blender con 2 hilos y prioridad mínima: el PC sigue usable (ver la memoria de límites de recursos).
    $p = Start-Process -FilePath $blender -ArgumentList @("-b", "-t", "2", "-P", (Join-Path $PSScriptRoot "blender_ship.py"), "--", "spin", $m.FullName, (Join-Path $root "build/tmp_glb"), "0", "0", "0", "1", "26", $prof, $glbArg, "glb=$out", "faces=$Faces") -WindowStyle Hidden -PassThru
    Start-Sleep -Milliseconds 300
    try { $p.PriorityClass = "Idle"; $p.ProcessorAffinity = [IntPtr]0x0C } catch {}
    $p.WaitForExit()
    if (Test-Path $out) { "OK $id ($prof)  {0:N0} KB" -f ((Get-Item $out).Length / 1KB) } else { "FALLO $id" }
}
"FIN"
