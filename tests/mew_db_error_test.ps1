# Prueba: errores de configuración de la base de datos sin filtrar información sensible
$ErrorActionPreference = 'Stop'
$base = 'http://localhost/mew'
$script:pass = 0
$script:fail = 0

function Assert {
    param([bool]$Condition, [string]$Label, [string]$Detail = '')
    if ($Condition) { $script:pass++; Write-Output ('  [PASS] ' + $Label) }
    else { $script:fail++; Write-Output ('  [FAIL] ' + $Label + $(if ($Detail) { '  -> ' + $Detail } else { '' })) }
}

function Invoke-Req {
    param([string]$Uri, [string]$Method = 'GET', $Session = $null, [hashtable]$Body = $null)
    $req = [System.Net.HttpWebRequest]::Create($Uri)
    $req.Method = $Method; $req.AllowAutoRedirect = $false; $req.Timeout = 20000; $req.Proxy = $null
    if ($Session) { $req.CookieContainer = $Session }
    if ($Body) {
        $pairs = New-Object System.Collections.Generic.List[string]
        foreach ($key in $Body.Keys) { $pairs.Add([uri]::EscapeDataString([string]$key) + '=' + [uri]::EscapeDataString([string]$Body[$key])) }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]::Join('&', $pairs.ToArray()))
        $req.ContentType = 'application/x-www-form-urlencoded'; $req.ContentLength = $bytes.Length
        $st = $req.GetRequestStream(); $st.Write($bytes, 0, $bytes.Length); $st.Close()
    }
    $resp = $null
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { return @{ status = 0; location = ''; body = ('EXC: ' + $_.Exception.Message) } } }
    $status = [int]$resp.StatusCode; $loc = $resp.Headers['Location']; $content = ''
    try { $rd = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8); $content = $rd.ReadToEnd(); $rd.Close() } catch { $content = '' }
    $resp.Close()
    return @{ status = $status; location = [string]$loc; body = [string]$content }
}

Write-Output '=== A. Credenciales de MySQL incorrectas (database.local.php) ==='
# Configuración local temporal con una contraseña errónea (mecanismo de sobrescritura real)
$localWrong = @'
<?php
// Prueba temporal: credenciales de MySQL incorrectas.
return array(
    'host' => 'localhost',
    'name' => 'mew_db',
    'user' => 'root',
    'pass' => 'contraseña_del_todo_errónea',
);
'@
[System.IO.File]::WriteAllText('C:\xampp\htdocs\MEW\config\database.local.php', $localWrong, (New-Object System.Text.UTF8Encoding($false)))
Assert (Test-Path 'C:\xampp\htdocs\MEW\config\database.local.php') 'database.local.php de prueba creado (sobrescritura de credenciales)'

$jar = New-Object System.Net.CookieContainer
$index = Invoke-Req -Uri "$base/index.php" -Session $jar
Assert ($index.status -eq 200) ('la pagina de acceso se sigue mostrando con la BD caida (status=' + $index.status + ')')
$token = $null
if ($index.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $token = $Matches[1] }
Assert ($null -ne $token) 'token CSRF disponible'

# Usuario existente previamente registrado (la prueba anterior dejo uno)
$post = Invoke-Req -Uri "$base/login.php" -Method POST -Session $jar -Body @{
    csrf_token = $token; nombre_usuario = 'navegador'; contrasena = 'Mew2024!'
}
Assert ($post.status -eq 302) ('el login responde redireccion aunque falle la BD (status=' + $post.status + ')')
$page = Invoke-Req -Uri ("$base/" + $post.location) -Session $jar
Assert ($page.body -match 'No es posible iniciar') 'mensaje generico y accionable para el usuario'
$leak = [regex]::Match($page.body, 'SQLSTATE|Access denied|pdo_mysql|contraseña_del_todo|root@|password_hash').Success
Assert (-not $leak) 'la pagina no filtra credenciales ni detalles internos de la BD'
Write-Output ('        mensaje mostrado: ' + ([regex]::Match($page.body, 'alert--error"[^>]*>\s*([^<]+)').Groups[1].Value.Trim()))

Write-Output ''
Write-Output '=== B. Base de datos inexistente ==='
# Base de datos inexistente
$localContent = @'
<?php
// Prueba temporal: base de datos que no existe.
return array(
    'host' => 'localhost',
    'name' => 'mew_que_no_existe',
    'user' => 'root',
    'pass' => '',
);
'@
[System.IO.File]::WriteAllText('C:\xampp\htdocs\MEW\config\database.local.php', $localContent, (New-Object System.Text.UTF8Encoding($true)))

$jar2 = New-Object System.Net.CookieContainer
$index2 = Invoke-Req -Uri "$base/index.php" -Session $jar2
$token2 = $null
if ($index2.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $token2 = $Matches[1] }
$post2 = Invoke-Req -Uri "$base/register.php" -Method POST -Session $jar2 -Body @{
    csrf_token = $token2; nombre_usuario = 'otro_usuario'; correo = 'otro@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$page2 = Invoke-Req -Uri ("$base/" + $post2.location) -Session $jar2
Assert ($page2.body -match 'No se pudo crear la cuenta') 'el registro informa de un error controlado'
$leak2 = [regex]::Match($page2.body, 'SQLSTATE|mew_que_no_existe|pdo_mysql|root@|Unknown database').Success
Assert (-not $leak2) 'la pagina no revela el nombre interno de la base de datos ni la consulta'

# Limpieza de la configuración de prueba
Remove-Item 'C:\xampp\htdocs\MEW\config\database.local.php' -Force
Assert (-not (Test-Path 'C:\xampp\htdocs\MEW\config\database.local.php')) 'database.local.php eliminado tras la prueba'

Write-Output ''
Write-Output '=== C. Registro de errores en el log (diagnostico del administrador) ==='
$logCandidates = 'C:\xampp\php\logs\php_error_log', 'C:\xampp\apache\logs\error.log'
$found = $false
$evidence = ''
foreach ($log in $logCandidates) {
    if (Test-Path $log) {
        $tail = Get-Content $log -Tail 200 -Encoding UTF8 -ErrorAction SilentlyContinue
        $hit = $tail | Select-String -Pattern '\[Mew\]' | Select-Object -Last 3
        if ($hit) { $found = $true; $lines = @($hit | ForEach-Object { $_.Line }); $evidence = [string]::Join(' | ', $lines); if ($evidence.Length -gt 220) { $evidence = $evidence.Substring(0, 220) }; break }
    }
}
Assert $found 'los detalles completos quedan en el log de PHP/Apache para el administrador'
if ($evidence) { Write-Output ('        log: ' + $evidence) }
if (-not (Test-Path 'C:\xampp\php\logs\php_error_log')) { Write-Output '        (no se creo C:\xampp\php\logs\php_error_log)' }

Write-Output ''
Write-Output ('RESULTADO: ' + $script:pass + ' pasan, ' + $script:fail + ' fallan')
