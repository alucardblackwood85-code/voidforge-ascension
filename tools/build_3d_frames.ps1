<#
.SYNOPSIS
  Convierte naves, enemigos y dron en modelos 3D (TripoSR local) y los renderiza en 32 ángulos (Blender).

.DESCRIPTION
  1. tools/prep_3d_inputs.ps1 prepara los sprites cenitales a 1024x1024.
  2. TripoSR (D:\Proyectos\herramientas) genera un modelo con textura por imagen en build/3d_models/<grupo>/<id>.
  3. Blender renderiza cada modelo con cámara ortográfica fija (55°) en 32 ángulos de giro:
     build/3d_frames/<grupo>/<id>/00..31.png (fotograma i = proa a i*11,25° antihorario desde la derecha).
  4. tools/pack_frames.ps1 los empaqueta en assets/sprites/frames/<grupo>/<id>.webp (hoja 8x4).
  Los modelos ya generados o renderizados se saltan (usar -Force para repetir).

.EXAMPLE
  .\tools\build_3d_frames.ps1
  .\tools\build_3d_frames.ps1 -Only ships/kestrel_a1 -Force
#>
param([string]$Only = "", [switch]$Force, [switch]$SkipModels, [int]$Frames = 32, [int]$Elev = 55)

# Perfil de render por modelo (por defecto "refine"): raw = sin refinar (formas que el refinado rompe),
# soft = refinado suave para orgánicos, smooth = extra liso, polish = material pulido brillante (combinables con +).
$Profiles = @{
    "ships/mule_c1" = "raw"
    "ships/specter_x" = "smooth+polish"
    "ships/seraph_prime" = "smooth+polish"
    "enemies/campana_vacio" = "raw"
    "enemies/monje_graviton" = "raw"
}

# Continue: TripoSR y Blender escriben su registro en stderr (en PowerShell 5.1 "Stop" lo trata como error)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$tsr = "D:\Proyectos\herramientas\TripoSR"
$py = "D:\Proyectos\herramientas\triposr_env\Scripts\python.exe"
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$env:PYTHONIOENCODING = "utf-8"

& (Join-Path $PSScriptRoot "prep_3d_inputs.ps1")

$inputs = @()
foreach ($f in Get-ChildItem (Join-Path $root "build/3d_inputs") -Recurse -Filter *.png) {
    $key = "$($f.Directory.Name)/$($f.BaseName)"
    if ($Only -and $key -ne $Only) { continue }
    $inputs += [pscustomobject]@{ key = $key; path = $f.FullName; model = Join-Path $root "build/3d_models/$key" }
}

# 2. Modelos 3D (una sola llamada por tanda: el modelo de TripoSR se carga una vez)
if (-not $SkipModels) {
    $todo = @($inputs | Where-Object { $Force -or -not (Test-Path (Join-Path $_.model "texture.png")) })
    for ($i = 0; $i -lt $todo.Count; $i += 12) {
        $batch = @($todo[$i..([Math]::Min($i + 11, $todo.Count - 1))])
        $tmp = Join-Path $root "build/3d_models/_tanda"
        if (Test-Path $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp }
        Push-Location $tsr
        & $py run.py @($batch | ForEach-Object { $_.path }) --output-dir $tmp --model-save-format glb --bake-texture --texture-resolution 2048 --mc-resolution 384 2>&1 |
            Select-String "Exporting mesh and texture finished|Error|Traceback" | ForEach-Object { Write-Host "  $_" }
        Pop-Location
        for ($k = 0; $k -lt $batch.Count; $k++) {
            $from = Join-Path $tmp "$k"
            if (-not (Test-Path (Join-Path $from "texture.png"))) { Write-Host "FALLO modelo $($batch[$k].key)" -ForegroundColor Red; continue }
            New-Item -ItemType Directory -Force $batch[$k].model | Out-Null
            Move-Item -Force (Join-Path $from "mesh.glb") (Join-Path $batch[$k].model "mesh.obj")
            Move-Item -Force (Join-Path $from "texture.png") (Join-Path $batch[$k].model "texture.png")
            Write-Host "modelo OK $($batch[$k].key)" -ForegroundColor Green
        }
    }
}

# 3. Fotogramas
foreach ($it in $inputs) {
    $out = Join-Path $root "build/3d_frames/$($it.key)"
    if (-not (Test-Path (Join-Path $it.model "mesh.obj"))) { continue }
    if (-not $Force -and (Test-Path (Join-Path $out ("{0:D2}.png" -f ($Frames - 1))))) { continue }
    $extra = if ($Profiles.ContainsKey($it.key)) { $Profiles[$it.key] } else { "refine" }
    & $blender -b -P (Join-Path $PSScriptRoot "blender_ship.py") -- spin $it.model $out 0 -90 270 $Frames $Elev $extra 2>&1 |
        Select-String "Error|Traceback" | ForEach-Object { Write-Host "  $_" -ForegroundColor Red }
    Write-Host "fotogramas OK $($it.key)" -ForegroundColor Green
}
& (Join-Path $PSScriptRoot "pack_frames.ps1") -Only $Only
Write-Host "FIN build_3d_frames"
