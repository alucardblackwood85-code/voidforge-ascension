<#
.SYNOPSIS
  Iguala el brillo de las vistas direccionales de cada modelo.

.DESCRIPTION
  La generación ilumina cada vista de forma algo distinta (una puede salir más oscura que las
  demás). Este script iguala sólo el BRILLO de cada vista con la mediana de las vistas del mismo
  modelo (ganancia uniforme limitada a 0,8–1,3), sin tocar el tono de color.
  Trabaja siempre desde la copia sin ajustar (assets/source/views_raw), así se puede repetir.

.EXAMPLE
  .\tools\normalize_views.ps1
  .\tools\normalize_views.ps1 -Only ships/kestrel_a1
#>
param([string]$Only = "")

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
Add-Type -AssemblyName System.Drawing

function Mean-Color([Drawing.Bitmap]$bmp) {
    $r = 0.0; $g = 0.0; $b = 0.0; $n = 0
    for ($y = 0; $y -lt $bmp.Height; $y += 2) {
        for ($x = 0; $x -lt $bmp.Width; $x += 2) {
            $c = $bmp.GetPixel($x, $y)
            if ($c.A -gt 200) { $r += $c.R; $g += $c.G; $b += $c.B; $n++ }
        }
    }
    if ($n -eq 0) { return @(1.0, 1.0, 1.0) }
    return @(($r / $n), ($g / $n), ($b / $n))
}

$viewsDir = Join-Path $root "assets/sprites/views"
$rawDir = Join-Path $root "assets/source/views_raw"
foreach ($modelDir in Get-ChildItem $viewsDir -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory }) {
    $group = $modelDir.Parent.Name
    $id = $modelDir.Name
    if ($Only -and "$group/$id" -ne $Only) { continue }
    $files = @(Get-ChildItem $modelDir.FullName -Filter *.png)
    if ($files.Count -lt 2) { continue }
    # Copia sin ajustar y brillo medio (luminancia) de cada vista.
    $lum = @{}
    foreach ($f in $files) {
        $raw = Join-Path $rawDir "$group/$id/$($f.Name)"
        if (-not (Test-Path $raw)) {
            New-Item -ItemType Directory -Force (Split-Path $raw) | Out-Null
            Copy-Item $f.FullName $raw
        }
        $bmp = New-Object Drawing.Bitmap($raw)
        $m = Mean-Color $bmp
        $bmp.Dispose()
        $lum[$f.Name] = 0.299 * $m[0] + 0.587 * $m[1] + 0.114 * $m[2]
    }
    $sorted = @($lum.Values | Sort-Object)
    $target = $sorted[[int][Math]::Floor($sorted.Count / 2)]
    foreach ($f in $files) {
        $raw = Join-Path $rawDir "$group/$id/$($f.Name)"
        $gain = [Math]::Max(0.8, [Math]::Min(1.3, $target / [Math]::Max(1.0, $lum[$f.Name])))
        $src = New-Object Drawing.Bitmap($raw)
        $cm = New-Object Drawing.Imaging.ColorMatrix
        $cm.Matrix00 = $gain; $cm.Matrix11 = $gain; $cm.Matrix22 = $gain; $cm.Matrix33 = 1; $cm.Matrix44 = 1
        $ia = New-Object Drawing.Imaging.ImageAttributes
        $ia.SetColorMatrix($cm)
        $dst = New-Object Drawing.Bitmap($src.Width, $src.Height, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
        $gr = [Drawing.Graphics]::FromImage($dst)
        $gr.DrawImage($src, (New-Object Drawing.Rectangle(0, 0, $src.Width, $src.Height)), 0, 0, $src.Width, $src.Height, [Drawing.GraphicsUnit]::Pixel, $ia)
        $gr.Dispose(); $src.Dispose()
        $dst.Save($f.FullName, [Drawing.Imaging.ImageFormat]::Png)
        $dst.Dispose()
        Write-Host ("{0}/{1}/{2}: brillo x{3:N2}" -f $group, $id, $f.BaseName, $gain)
    }
}
