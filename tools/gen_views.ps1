<#
.SYNOPSIS
  Genera las vistas direccionales (8 direcciones) de naves, enemigos y dron a partir de su sprite.

.DESCRIPTION
  Usa la API de edición de imágenes de OpenAI (gpt-image-1) con el sprite actual como referencia,
  para que todas las vistas conserven el mismo diseño. Se generan 5 vistas por modelo
  (e, ne, n, se, s); las otras 3 (w, nw, sw) son su espejo y las resuelve el motor.
  Salida: assets/sprites/views/<grupo>/<id>/<dir>.png (256x256). Requiere OPENAI_API_KEY.
  Después: .	ools
ormalize_views.ps1 (iguala el brillo), revisar con `godot -- --viewtest`,
  corregir rumbos con SpriteLib.VIEW_FIX y poner compress/mode=1 en los .import (pesan menos).

.EXAMPLE
  .\tools\gen_views.ps1 -Only ships/kestrel_a1          # un modelo
  .\tools\gen_views.ps1 -Group enemies -Shard 0 -Shards 4
#>
param(
    [string]$Only = "",
    [string]$Group = "",
    [switch]$Force,
    [int]$Shard = 0,
    [int]$Shards = 1,
    [ValidateSet("low", "medium", "high")][string]$Quality = "medium",
    [string[]]$Dirs = @("e", "ne", "n", "se", "s")
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$key = $env:OPENAI_API_KEY
if (-not $key) { $key = [Environment]::GetEnvironmentVariable("OPENAI_API_KEY", "User") }
if (-not $key) { Write-Host "Falta OPENAI_API_KEY" -ForegroundColor Red; exit 1 }

Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Drawing

$camera = "The reference shows a spaceship seen from directly above, already rotated to its final heading on screen. " +
    "Re-render this exact same spaceship as a pre-rendered 3D game sprite for an isometric MMO space shooter in the style of DarkOrbit, " +
    "KEEPING EXACTLY THE SAME HEADING ON SCREEN as the reference (do not turn the ship). " +
    "Camera: tilted three-quarter view from above, elevated about 35 degrees, positioned toward the bottom of the image, so the hull shows real depth, side surfaces and thickness. " +
    "Keep the identical design, silhouette, colors, materials, decals and proportions of the reference; only the viewing angle changes. " +
    "Detailed realistic 3D render with soft studio lighting from the top-left, subtle rim light, NOT pixel art, NOT a drawing. " +
    "The whole model is visible and centered, filling about 80% of the frame, transparent background, no shadow, no text, no frame."
$dirText = @{
    "e"  = "The nose of the ship points to the RIGHT side of the image; we see its left flank and the top surface in perspective."
    "ne" = "The nose of the ship points toward the UPPER-RIGHT corner of the image, flying away from the camera; we see its top, left flank and rear engines in perspective."
    "n"  = "The nose of the ship points straight UP in the image, flying directly away from the camera; we see the top surface and the rear engines facing the viewer."
    "se" = "The nose of the ship points toward the LOWER-RIGHT corner of the image, flying toward the camera; we see its top, left flank and front in perspective."
    "s"  = "The nose of the ship points straight DOWN in the image, flying directly toward the camera; we see the front of the ship and its top surface."
}

# Modelos que se mueven: naves (sin las siluetas genéricas por clase), enemigos (sin nidos) y dron.
$targets = @()
foreach ($g in @("ships", "enemies", "drone")) {
    foreach ($f in Get-ChildItem (Join-Path $root "assets/sprites/$g") -Filter *.png) {
        $id = $f.BaseName
        if ($g -eq "ships" -and $id -in @("caza", "tanque", "carguera", "crucero", "batalla")) { continue }
        if ($id -eq "nest") { continue }
        $targets += [pscustomobject]@{ group = $g; id = $id; src = $f.FullName }
    }
}
$targets = @($targets | Where-Object { (-not $Only -or "$($_.group)/$($_.id)" -eq $Only) -and (-not $Group -or $_.group -eq $Group) })
$jobs = @()
for ($i = 0; $i -lt $targets.Count; $i++) { if ($i % $Shards -eq $Shard) { $jobs += $targets[$i] } }

function Save-Resized([byte[]]$bytes, [string]$path, [int]$w, [int]$h) {
    $ms = New-Object IO.MemoryStream(, $bytes)
    $src = [Drawing.Image]::FromStream($ms)
    $dst = New-Object Drawing.Bitmap($w, $h, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gr = [Drawing.Graphics]::FromImage($dst)
    $gr.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.CompositingMode = [Drawing.Drawing2D.CompositingMode]::SourceCopy
    $gr.DrawImage($src, 0, 0, $w, $h)
    $dst.Save($path, [Drawing.Imaging.ImageFormat]::Png)
    $gr.Dispose(); $dst.Dispose(); $src.Dispose(); $ms.Dispose()
}

# Gira el sprite de referencia (vista cenital, proa a la derecha) para que ya apunte a la dirección pedida:
# la API conserva mucho mejor el rumbo de la referencia que una instrucción de texto.
$dirAngle = @{ "e" = 0; "ne" = -45; "n" = -90; "se" = 45; "s" = 90 }
function Rotated-Png([string]$path, [float]$deg) {
    $src = [Drawing.Image]::FromFile($path)
    $n = 1024
    $dst = New-Object Drawing.Bitmap($n, $n, [Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $gr = [Drawing.Graphics]::FromImage($dst)
    $gr.InterpolationMode = [Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $gr.TranslateTransform($n / 2, $n / 2)
    $gr.RotateTransform($deg)
    $s = $n * 0.8
    $gr.DrawImage($src, - $s / 2, - $s / 2, $s, $s)
    $ms = New-Object IO.MemoryStream
    $dst.Save($ms, [Drawing.Imaging.ImageFormat]::Png)
    $gr.Dispose(); $dst.Dispose(); $src.Dispose()
    return , $ms.ToArray()
}

$client = New-Object System.Net.Http.HttpClient
$client.Timeout = [TimeSpan]::FromSeconds(300)
$client.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Bearer", $key)

foreach ($t in $jobs) {
    foreach ($d in $Dirs) {
        $dest = Join-Path $root "assets/sprites/views/$($t.group)/$($t.id)/$d.png"
        if ((Test-Path $dest) -and -not $Force) { Write-Host "= $($t.group)/$($t.id)/$d"; continue }
        New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
        $ok = $false
        for ($try = 1; $try -le 40 -and -not $ok; $try++) {
            Write-Host "> $($t.group)/$($t.id)/$d (intento $try)" -ForegroundColor Cyan
            try {
                $form = New-Object System.Net.Http.MultipartFormDataContent
                $img = New-Object System.Net.Http.ByteArrayContent(, (Rotated-Png $t.src $dirAngle[$d]))
                $img.Headers.ContentType = [System.Net.Http.Headers.MediaTypeHeaderValue]::Parse("image/png")
                $form.Add($img, "image[]", "ref.png")
                $form.Add((New-Object System.Net.Http.StringContent("gpt-image-1")), "model")
                $form.Add((New-Object System.Net.Http.StringContent("$camera $($dirText[$d])")), "prompt")
                $form.Add((New-Object System.Net.Http.StringContent("1024x1024")), "size")
                $form.Add((New-Object System.Net.Http.StringContent("transparent")), "background")
                $form.Add((New-Object System.Net.Http.StringContent($Quality)), "quality")
                $form.Add((New-Object System.Net.Http.StringContent("high")), "input_fidelity")
                $resp = $client.PostAsync("https://api.openai.com/v1/images/edits", $form).Result
                $txt = $resp.Content.ReadAsStringAsync().Result
                if (-not $resp.IsSuccessStatusCode) {
                    if ([int]$resp.StatusCode -eq 429 -and $txt -notmatch "insufficient_quota|billing") {
                        Write-Host "  límite de velocidad, esperando..." -ForegroundColor Yellow
                        Start-Sleep -Seconds ([Math]::Min(60, 10 * $try)); continue
                    }
                    throw "HTTP $([int]$resp.StatusCode): $txt"
                }
                $json = $txt | ConvertFrom-Json
                $bytes = [Convert]::FromBase64String($json.data[0].b64_json)
                $raw = Join-Path $root "assets/source/views/$($t.group)/$($t.id)/$d.png"
                New-Item -ItemType Directory -Force (Split-Path $raw) | Out-Null
                [IO.File]::WriteAllBytes($raw, $bytes)
                Save-Resized $bytes $dest 256 256
                Write-Host "  OK" -ForegroundColor Green
                $ok = $true
            } catch {
                Write-Host "  ERROR: $($_.Exception.Message)" -ForegroundColor Red
                if ($try -ge 2) { break }
                Start-Sleep -Seconds 5
            }
        }
    }
}
Write-Host "FIN shard $Shard"
