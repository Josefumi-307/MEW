# mew_shots.ps1 — Genera las capturas de pantalla del proyecto Mew con Chrome
# en modo headless y verifica por pixeles que la tarjeta nunca toque el borde
# derecho (sin "corte" horizontal) de la imagen.
#
# Requisitos:
#   - XAMPP en marcha con la aplicacion en http://localhost/mew/
#   - Google Chrome (o Edge) instalado
#   - El archivo temporal _shot.php en la raiz del proyecto (no versionado):
#     wrapper con <iframe> del ancho pedido, porque Chrome headless no permite
#     ventanas por debajo de ~500 px. Las consultas medias responden al ancho
#     del iframe, igual que en un movil real.
#
# Uso:
#   1. Inicia sesion en http://localhost/mew/ y copia el valor de la cookie
#      mew_session (o genera uno con un registro/login via HTTP).
#   2. powershell -NoProfile -ExecutionPolicy Bypass -File tests\mew_shots.ps1 <sid>
#
# Salida: docs/capturas/*.png (login, registro, panel y foco en 1366/768/390/340 px)

$dir     = Join-Path $PSScriptRoot '..\docs\capturas'
$profile = Join-Path $env:TEMP 'mew-chrome-profile'
$sid     = $args[0]
if (-not $sid) { Write-Output 'FALTA sid (cookie mew_session)'; exit 1 }

$cromos = @(
    'C:\Program Files\Google\Chrome\Application\chrome.exe',
    "$env:LOCALAPPDATA\Google\Chrome\Application\chrome.exe",
    'C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe'
)
$chrome = $cromos | Where-Object { Test-Path $_ } | Select-Object -First 1
if (-not $chrome) { Write-Output 'No se encontro Chrome ni Edge'; exit 1 }

New-Item -ItemType Directory -Force -Path $dir | Out-Null
Add-Type -AssemblyName System.Drawing

$base = 'http://localhost/mew/_shot.php?mode=frame'
$shots = @(
    @{ name = 'login-1366';     w = 1366; h = 900;  crop = $false; url = 'http://localhost/mew/index.php' },
    @{ name = 'registro-1366';  w = 1366; h = 1150; crop = $false; url = 'http://localhost/mew/index.php?form=register' },
    @{ name = 'login-768';      w = 768;  h = 1024; crop = $false; url = 'http://localhost/mew/index.php' },
    @{ name = 'registro-768';   w = 768;  h = 1250; crop = $false; url = 'http://localhost/mew/index.php?form=register' },
    @{ name = 'login-390';      w = 390;  h = 844;  crop = $true;  url = "$base&w=390&h=844&url=index.php" },
    @{ name = 'login-340';      w = 340;  h = 844;  crop = $true;  url = "$base&w=340&h=844&url=index.php" },
    @{ name = 'registro-390';   w = 390;  h = 1250; crop = $true;  url = "$base&w=390&h=1250&url=index.php?form=register" },
    @{ name = 'dashboard-390';  w = 390;  h = 780;  crop = $true;  url = "$base&w=390&h=780&url=dashboard.php&sid=$sid" },
    @{ name = 'dashboard-768';  w = 768;  h = 1024; crop = $false; url = "$base&w=768&h=1024&url=dashboard.php&sid=$sid" },
    @{ name = 'dashboard-1366'; w = 1366; h = 900;  crop = $false; url = "$base&w=1366&h=900&url=dashboard.php&sid=$sid" },
    @{ name = 'foco-390';       w = 390;  h = 844;  crop = $true;  url = "$base&w=390&h=844&url=index.php&focus=1" }
)

$results = @()
foreach ($s in $shots) {
    $winW = if ($s.crop) { 520 } else { $s.w }
    $raw = Join-Path $dir ($s.name + '.raw.png')
    $out = Join-Path $dir ($s.name + '.png')
    if (Test-Path $raw) { Remove-Item $raw -Force }
    if (Test-Path $out) { Remove-Item $out -Force }

    $p = Start-Process -FilePath $chrome -ArgumentList @(
        '--headless', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
        '--force-device-scale-factor=1', "--user-data-dir=$profile",
        '--virtual-time-budget=5000', "--window-size=$winW,$($s.h)",
        "--screenshot=$raw", $s.url
    ) -Wait -PassThru -WindowStyle Hidden

    if (-not (Test-Path $raw)) {
        $results += "$($s.name): FALLO (sin archivo, exit=$($p.ExitCode))"
        continue
    }

    # Las capturas estrechas se disparan a 520 px de ventana (minimo real de
    # Chrome headless) y se recortan al ancho pedido; las anchas ya salen bien.
    $bmp = New-Object System.Drawing.Bitmap($raw)
    if ($s.crop) {
        $rect = New-Object System.Drawing.Rectangle(0, 0, [int]$s.w, [int]$s.h)
        $c2 = $bmp.Clone($rect, $bmp.PixelFormat)
        $bmp.Dispose()
        $c2.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $c2.Dispose()
    } else {
        $bmp.Save($out, [System.Drawing.Imaging.ImageFormat]::Png)
        $bmp.Dispose()
    }
    Remove-Item $raw -Force

    # Verificacion: la tarjeta (blanco puro) no debe llegar al borde derecho.
    $chk = New-Object System.Drawing.Bitmap($out)
    $maxX = -1
    for ($y = 0; $y -lt $chk.Height; $y += 4) {
        for ($x = 0; $x -lt $chk.Width; $x += 2) {
            $c = $chk.GetPixel($x, $y)
            if ($c.R -gt 250 -and $c.G -gt 250 -and $c.B -gt 250) { if ($x -gt $maxX) { $maxX = $x } }
        }
    }
    $dims = "$($chk.Width)x$($chk.Height)"
    $chk.Dispose()
    $limite = [int]$s.w - 6
    $ok = ($maxX -ge 0) -and ($maxX -le $limite) -and ($dims -eq "$($s.w)x$($s.h)")
    $mark = if ($ok) { 'OK  ' } else { 'FALLO' }
    $results += "$mark $($s.name) ($dims) tarjeta maxX=$maxX (limite $limite)"
    Start-Sleep -Milliseconds 200
}

$results | ForEach-Object { Write-Output $_ }
$fallos = @($results | Where-Object { $_ -like 'FALLO*' }).Count
Write-Output ("TOTAL: " + ($results.Count - $fallos) + " ok, " + $fallos + " fallos")
