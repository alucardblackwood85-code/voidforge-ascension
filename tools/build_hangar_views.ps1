<#
.SYNOPSIS
  Giros 3D de las naves para el hangar: vista semifrontal (elevación baja) y 36 fotogramas por vuelta.

.DESCRIPTION
  Reutiliza los modelos de build/3d_models/ships y el mismo refinado que el juego (perfiles de
  build_3d_frames.ps1). Renderiza con Blender a 384 px desde una elevación de 18° (la nave se ve de
  tres cuartos, con sus ejes), y empaqueta los 36 fotogramas en una hoja 6x6 de 256 px:
  assets/sprites/hangar/<id>.webp. El fotograma i tiene la proa girada i*10° en sentido antihorario.
  Blender va con prioridad baja y 8 hilos para no cargar el PC.

.EXAMPLE
  .\tools\build_hangar_views.ps1
  .\tools\build_hangar_views.ps1 -Only kestrel_a1 -Force
#>
param([string]$Only = "", [switch]$Force, [int]$Frames = 36, [int]$Elev = 26, [int]$FrameSize = 256, [switch]$Hy3d)
$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$blender = "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe"
$ffmpeg = "C:\Users\FOFO\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe"
$Profiles = @{ "mule_c1" = "raw"; "specter_x" = "smooth+polish"; "seraph_prime" = "smooth+polish" }
$outDir = Join-Path $root "assets/sprites/hangar"
New-Item -ItemType Directory -Force $outDir | Out-Null
Add-Type -AssemblyName System.Drawing
$cols = [Math]::Ceiling([Math]::Sqrt($Frames))
$rows = [Math]::Ceiling($Frames / $cols)
foreach ($m in Get-ChildItem (Join-Path $root "build/3d_models/ships") -Directory) {
    $id = $m.Name
    # -Hy3d: modelo limpio con el sprite proyectado (perfil «hy3d»): el de Tripo (model.glb) si existe,
    # si no el de TripoSG (mesh.obj). La orientación sale de tools/tripo_fix.json o hy3d_fix.json.
    $hyDir = Join-Path $root "build/tripo_models/ships/$id"
    if (-not (Test-Path (Join-Path $hyDir "model.glb"))) { $hyDir = Join-Path $root "build/tsg_models/ships/$id" }
    $useHy = $Hy3d -and ((Test-Path (Join-Path $hyDir "mesh.obj")) -or (Test-Path (Join-Path $hyDir "model.glb")))
    $modelDir = if ($useHy) { $hyDir } else { $m.FullName }
    if ($Only -and $id -ne $Only) { continue }
    $dest = Join-Path $outDir "$id.webp"
    if ((Test-Path $dest) -and -not $Force) { continue }
    $raw = Join-Path $root "build/hangar_frames/$id"
    $last = Join-Path $raw ("{0:D2}.png" -f ($Frames - 1))
    if ($Force -or -not (Test-Path $last)) {
        $prof = if ($useHy) { "hy3d" } elseif ($Profiles.ContainsKey($id)) { $Profiles[$id] } else { "refine" }
        $rot = if ($useHy) { @("0", "0", "0") } else { @("0", "-90", "270") }
        $p = Start-Process -FilePath $blender -ArgumentList @("-b", "-t", "8", "-P", (Join-Path $PSScriptRoot "blender_ship.py"), "--", "spin", $modelDir, $raw, $rot[0], $rot[1], $rot[2], "$Frames", "$Elev", $prof) -WindowStyle Hidden -PassThru
        Start-Sleep -Milliseconds 400
        try { $p.PriorityClass = "BelowNormal" } catch {}
        $p.WaitForExit()
    }
    if (-not (Test-Path $last)) { Write-Host "FALLO $id" -ForegroundColor Red; continue }
    $sheet = New-Object Drawing.Bitmap(($cols * $FrameSize), ($rows * $FrameSize), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($sheet)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    for ($i = 0; $i -lt $Frames; $i++) {
        $im = [Drawing.Image]::FromFile((Join-Path $raw ("{0:D2}.png" -f $i)))
        $g.DrawImage($im, ($i % $cols) * $FrameSize, [Math]::Floor($i / $cols) * $FrameSize, $FrameSize, $FrameSize)
        $im.Dispose()
    }
    $g.Dispose()
    $tmp = Join-Path $raw "sheet.png"
    $sheet.Save($tmp)
    $sheet.Dispose()
    & $ffmpeg -loglevel error -y -i $tmp -c:v libwebp -quality 85 -lossless 0 $dest
    Write-Host "OK $id"
}
Write-Host "FIN hangar"
