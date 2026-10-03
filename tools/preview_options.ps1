<#
.SYNOPSIS
  Convierte las propuestas de rediseño en modelos 3D y monta una hoja para elegir.

.DESCRIPTION
  Lee build/redesign/<grupo>/<id>_<n>.png, genera un modelo con TripoSR por propuesta, lo renderiza en
  8 ángulos con Blender (mismo refinado que el juego) y monta build/redesign/<grupo>/opciones_<id>.png
  con la imagen de cada propuesta y su modelo desde 4 ángulos.

.EXAMPLE
  .\tools\preview_options.ps1 -Group enemies
#>
param([string]$Group = "enemies", [string]$Only = "", [switch]$SheetsOnly)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$tsr = "D:\Proyectos\herramientas\TripoSR"
$py = "D:\Proyectos\herramientas\triposr_env\Scripts\python.exe"
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$env:PYTHONIOENCODING = "utf-8"
$dir = Join-Path $root "build/redesign/$Group"
# Orgánicos o de formas altas: refinado suave (no se recorta el cuerpo).
$soft = @("leviatan_genesis", "monje_graviton", "campana_vacio")
$opts = @(Get-ChildItem $dir -Filter "*_?.png" | Where-Object { $_.BaseName -match '^(.+)_(\d)$' -and (-not $Only -or $Matches[1] -eq $Only) })
# 1. Modelos (una tanda por cada 12 imágenes)
if (-not $SheetsOnly) {
for ($i = 0; $i -lt $opts.Count; $i += 12) {
    $batch = @($opts[$i..([Math]::Min($i + 11, $opts.Count - 1))])
    $tmp = Join-Path $dir "_tanda"
    if (Test-Path $tmp) { Remove-Item -Recurse -Force -LiteralPath $tmp }
    Push-Location $tsr
    & $py run.py @($batch | ForEach-Object { $_.FullName }) --output-dir $tmp --model-save-format glb --bake-texture --texture-resolution 2048 --mc-resolution 384 2>&1 | Out-Null
    Pop-Location
    for ($k = 0; $k -lt $batch.Count; $k++) {
        $m = Join-Path $dir "modelos/$($batch[$k].BaseName)"
        New-Item -ItemType Directory -Force $m | Out-Null
        Move-Item -Force (Join-Path $tmp "$k/mesh.glb") (Join-Path $m "mesh.obj")
        Move-Item -Force (Join-Path $tmp "$k/texture.png") (Join-Path $m "texture.png")
        Write-Host "modelo $($batch[$k].BaseName)"
    }
}
# 2. Render de 8 ángulos por propuesta
foreach ($o in $opts) {
    $null = $o.BaseName -match '^(.+)_(\d)$'; $id = $Matches[1]
    $profile = if ($soft -contains $id) { "soft" } else { "refine" }
    & $blender -b -P (Join-Path $PSScriptRoot "blender_ship.py") -- spin (Join-Path $dir "modelos/$($o.BaseName)") (Join-Path $dir "frames/$($o.BaseName)") 0 -90 270 8 55 $profile 2>&1 | Out-Null
    Write-Host "render $($o.BaseName)"
}
}
# 3. Hoja de opciones por enemigo
Add-Type -AssemblyName System.Drawing
foreach ($id in ($opts | ForEach-Object { $null = $_.BaseName -match '^(.+)_(\d)$'; $Matches[1] } | Sort-Object -Unique)) {
    $mine = @($opts | Where-Object { $_.BaseName -like "$($id)_*" } | Sort-Object Name)
    $h = 30 + 250 * $mine.Count
    $bmp = New-Object Drawing.Bitmap(1300, $h)
    $g = [Drawing.Graphics]::FromImage($bmp)
    $g.Clear([Drawing.Color]::FromArgb(14, 18, 30))
    $fT = New-Object Drawing.Font("Arial", 16, [Drawing.FontStyle]::Bold)
    $fL = New-Object Drawing.Font("Arial", 13, [Drawing.FontStyle]::Bold)
    $g.DrawString("$id - propuestas (imagen y modelo 3D desde 4 angulos)", $fT, [Drawing.Brushes]::White, 8, 4)
    for ($r = 0; $r -lt $mine.Count; $r++) {
        $y = 30 + $r * 250
        $n = $mine[$r].BaseName.Substring($mine[$r].BaseName.Length - 1)
        $g.DrawString("Opcion $n", $fL, [Drawing.Brushes]::Gold, 8, $y + 4)
        $im = [Drawing.Image]::FromFile($mine[$r].FullName); $g.DrawImage($im, 8, $y + 26, 220, 220); $im.Dispose()
        $c = 0
        foreach ($f in 0, 1, 2, 6) {
            $p = Join-Path $dir ("frames/$($mine[$r].BaseName)/{0:D2}.png" -f $f)
            if (Test-Path $p) { $im = [Drawing.Image]::FromFile($p); $g.DrawImage($im, 250 + $c * 260, $y + 6, 240, 240); $im.Dispose() }
            $c++
        }
    }
    $bmp.Save((Join-Path $dir "opciones_$id.png"))
    $g.Dispose(); $bmp.Dispose()
    Write-Host "hoja $id"
}
Write-Host "FIN preview"
