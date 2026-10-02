<#
.SYNOPSIS
  Corrige la orientación de sprites generados (el frente debe mirar a la DERECHA).
.DESCRIPTION
  Rota el original (assets/source/<out>_src.png) sobre un lienzo amplio para no recortar puntas,
  recorta al contenido opaco, centra en un cuadrado y reescala a 256 px en assets/<out>.png.
  Ángulo en grados, sentido horario (90 = la nariz que apuntaba abajo… pasa a apuntar a la izquierda).
.EXAMPLE
  .\tools\reorient.ps1 -Fixes @{ "sprites/ships/bastion_h" = -90 }
#>
param([hashtable]$Fixes, [int]$Size = 256)
Add-Type -AssemblyName System.Drawing
$root = Split-Path -Parent $PSScriptRoot

foreach ($k in $Fixes.Keys) {
    $src = Join-Path $root "assets/source/$k`_src.png"
    if (-not (Test-Path $src)) { $src = Join-Path $root ("assets/source/" + ($k -replace "^sprites/", "") + "_1024.png") }
    if (-not (Test-Path $src)) { Write-Host "Sin original: $k" -ForegroundColor Red; continue }
    $img = [Drawing.Image]::FromFile($src)
    $w = $img.Width; $diag = [int][math]::Ceiling([math]::Sqrt(2) * $w)
    $big = New-Object Drawing.Bitmap($diag, $diag, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($big)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.TranslateTransform($diag / 2, $diag / 2); $g.RotateTransform([float]$Fixes[$k]); $g.TranslateTransform(-$w / 2, -$img.Height / 2)
    $g.DrawImage($img, 0, 0, $w, $img.Height); $g.Dispose(); $img.Dispose()
    # Recorte al contenido opaco (muestreo cada 4 px para ir rápido).
    $minX = $diag; $minY = $diag; $maxX = 0; $maxY = 0
    for ($y = 0; $y -lt $diag; $y += 4) { for ($x = 0; $x -lt $diag; $x += 4) {
        if ($big.GetPixel($x, $y).A -gt 24) { if ($x -lt $minX) { $minX = $x }; if ($x -gt $maxX) { $maxX = $x }; if ($y -lt $minY) { $minY = $y }; if ($y -gt $maxY) { $maxY = $y } } } }
    $side = [math]::Max($maxX - $minX, $maxY - $minY) + 40
    $cx = ($minX + $maxX) / 2; $cy = ($minY + $maxY) / 2
    $out = New-Object Drawing.Bitmap($Size, $Size, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g2 = [Drawing.Graphics]::FromImage($out)
    $g2.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $scale = $Size / ($side / 0.85)   # el objeto ocupa ~85% del lienzo final
    $g2.TranslateTransform($Size / 2, $Size / 2); $g2.ScaleTransform($scale, $scale); $g2.TranslateTransform(-$cx, -$cy)
    $g2.DrawImage($big, 0, 0, $diag, $diag); $g2.Dispose(); $big.Dispose()
    $dest = Join-Path $root "assets/$k.png"
    $out.Save($dest, [Drawing.Imaging.ImageFormat]::Png); $out.Dispose()
    Write-Host "OK $k ($($Fixes[$k])°)" -ForegroundColor Green
}
