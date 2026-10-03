<#
.SYNOPSIS
  Prepara las imágenes de entrada para convertir naves, enemigos y dron en modelos 3D (Tripo).

.DESCRIPTION
  Para cada modelo que se mueve usa su sprite cenital del juego (vista desde arriba, proa a la
  derecha): es la entrada que mejor convierte TripoSR (las vistas en perspectiva salen deformes).
  La guarda a 1024x1024 con margen y fondo transparente en build/3d_inputs/<grupo>/<id>.png.

.EXAMPLE
  .\tools\prep_3d_inputs.ps1
#>
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing
$out = Join-Path $root "build/3d_inputs"
$count = 0
foreach ($g in @("ships", "enemies", "drone")) {
    foreach ($f in Get-ChildItem (Join-Path $root "assets/sprites/$g") -Filter *.png) {
        $id = $f.BaseName
        if ($g -eq "ships" -and $id -in @("caza", "tanque", "carguera", "crucero", "batalla")) { continue }
        if ($id -eq "nest") { continue }
        $src = $f.FullName
        $img = [Drawing.Image]::FromFile($src)
        $dst = New-Object Drawing.Bitmap(1024, 1024, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gr = [Drawing.Graphics]::FromImage($dst)
        $gr.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
        $gr.Clear([Drawing.Color]::Transparent)
        $gr.DrawImage($img, 72, 72, 880, 880)
        $dir = Join-Path $out $g
        New-Item -ItemType Directory -Force $dir | Out-Null
        $dst.Save((Join-Path $dir "$id.png"), [Drawing.Imaging.ImageFormat]::Png)
        $gr.Dispose(); $dst.Dispose(); $img.Dispose()
        $count++
    }
}
Write-Host "Imágenes preparadas: $count en $out"
