<#
.SYNOPSIS
  Empaqueta los 32 fotogramas de cada modelo en una hoja WebP (8x4) para el juego.

.DESCRIPTION
  Lee build/3d_frames/<grupo>/<id>/00..31.png (render de Blender a 256 px), reduce cada fotograma a
  FrameSize px y los coloca en una hoja de 8 columnas x 4 filas (fotograma i en columna i%8, fila i/8).
  Guarda assets/sprites/frames/<grupo>/<id>.webp (calidad 88, con transparencia).
  Así las ~2.400 imágenes pasan de ~140 MB a unos pocos MB.

.EXAMPLE
  .\tools\pack_frames.ps1
  .\tools\pack_frames.ps1 -Only ships/kestrel_a1
#>
param([string]$Only = "", [int]$FrameSize = 192, [int]$Quality = 88)

$ErrorActionPreference = "Continue"
$root = Split-Path -Parent $PSScriptRoot
$ffmpeg = "C:\Users\FOFO\AppData\Local\Microsoft\WinGet\Links\ffmpeg.exe"
Add-Type -AssemblyName System.Drawing
$raw = Join-Path $root "build/3d_frames"
$n = 0
foreach ($dir in Get-ChildItem $raw -Directory | ForEach-Object { Get-ChildItem $_.FullName -Directory }) {
    $key = "$($dir.Parent.Name)/$($dir.Name)"
    if ($Only -and $key -ne $Only) { continue }
    if (-not (Test-Path (Join-Path $dir.FullName "31.png"))) { continue }
    $sheet = New-Object Drawing.Bitmap((8 * $FrameSize), (4 * $FrameSize), [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [Drawing.Graphics]::FromImage($sheet)
    $g.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $g.Clear([Drawing.Color]::Transparent)
    for ($i = 0; $i -lt 32; $i++) {
        $im = [Drawing.Image]::FromFile((Join-Path $dir.FullName ("{0:D2}.png" -f $i)))
        $g.DrawImage($im, ($i % 8) * $FrameSize, [Math]::Floor($i / 8) * $FrameSize, $FrameSize, $FrameSize)
        $im.Dispose()
    }
    $g.Dispose()
    $tmp = Join-Path $env:TEMP "sheet_$($dir.Name).png"
    $sheet.Save($tmp, [Drawing.Imaging.ImageFormat]::Png)
    $sheet.Dispose()
    $outDir = Join-Path $root "assets/sprites/frames/$($dir.Parent.Name)"
    New-Item -ItemType Directory -Force $outDir | Out-Null
    & $ffmpeg -y -loglevel error -i $tmp -c:v libwebp -quality $Quality -lossless 0 -pix_fmt yuva420p (Join-Path $outDir "$($dir.Name).webp")
    Remove-Item -LiteralPath $tmp
    $n++
}
Write-Host "Hojas empaquetadas: $n"
