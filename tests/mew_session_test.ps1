# Prueba: flags de la cookie de sesion y regeneracion del identificador tras el login
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
    try { $resp = $req.GetResponse() } catch [System.Net.WebException] { $resp = $_.Exception.Response; if (-not $resp) { return @{ status = 0; location = ''; body = ''; setCookie = '' } } }
    $status = [int]$resp.StatusCode; $loc = $resp.Headers['Location']; $sc = $resp.Headers['Set-Cookie']
    $content = ''
    try { $rd = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8); $content = $rd.ReadToEnd(); $rd.Close() } catch { $content = '' }
    $resp.Close()
    return @{ status = $status; location = [string]$loc; body = [string]$content; setCookie = [string]$sc }
}

Write-Output '=== 1. Flags de la cookie de sesion ==='
$jar = New-Object System.Net.CookieContainer
$index = Invoke-Req -Uri "$base/index.php" -Session $jar
Assert ($index.setCookie -match 'mew_session=') ('se emite la cookie mew_session: ' + $index.setCookie)
Assert ($index.setCookie -match 'HttpOnly') 'cookie con HttpOnly'
Assert ($index.setCookie -match 'SameSite=Lax') 'cookie con SameSite=Lax'
Assert ($index.setCookie -match 'Path=/') 'cookie con Path=/'
Assert ($index.setCookie -notmatch 'Secure') 'sin Secure en HTTP (se activa automaticamente en HTTPS)'
Assert ($index.setCookie -notmatch 'Expires=') 'cookie de sesion (caduca al cerrar el navegador)'

$token = $null
if ($index.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $token = $Matches[1] }

Write-Output ''
Write-Output '=== 2. Regeneracion del identificador tras autenticar ==='
$cookiesBefore = @{}
foreach ($c in $jar.GetCookies([uri]"$base/index.php")) { $cookiesBefore[$c.Name] = $c.Value }

# Crea una cuenta para poder iniciar sesion
$jarReg = New-Object System.Net.CookieContainer
$idxReg = Invoke-Req -Uri "$base/index.php?form=register" -Session $jarReg
$tokenReg = $null
if ($idxReg.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $tokenReg = $Matches[1] }
Invoke-Req -Uri "$base/register.php" -Method POST -Session $jarReg -Body @{
    csrf_token = $tokenReg; nombre_usuario = 'usuario.sesion'; correo = 'sesion@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
} | Out-Null

$jarLogin = New-Object System.Net.CookieContainer
$idxLogin = Invoke-Req -Uri "$base/index.php" -Session $jarLogin
$tokenLogin = $null
if ($idxLogin.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $tokenLogin = $Matches[1] }
$idBefore = ''
foreach ($c in $jarLogin.GetCookies([uri]"$base/index.php")) { if ($c.Name -eq 'mew_session') { $idBefore = $c.Value } }

$login = Invoke-Req -Uri "$base/login.php" -Method POST -Session $jarLogin -Body @{
    csrf_token = $tokenLogin; nombre_usuario = 'usuario.sesion'; contrasena = 'Mew2024!'
}
$idAfter = ''
foreach ($c in $jarLogin.GetCookies([uri]"$base/dashboard.php")) { if ($c.Name -eq 'mew_session') { $idAfter = $c.Value } }
if ($idAfter -eq '') { foreach ($c in $jarLogin.GetCookies([uri]"$base/index.php")) { if ($c.Name -eq 'mew_session') { $idAfter = $c.Value } } }

Assert ($login.status -eq 302 -and $login.location -eq 'dashboard.php') ('acceso correcto (status=' + $login.status + ')')
Assert ($idBefore -ne '' ) ('identificador previo al login: ' + $idBefore.Substring(0, [Math]::Min(12, $idBefore.Length)) + '...')
Assert ($idAfter -ne '') ('identificador tras el login: ' + $idAfter.Substring(0, [Math]::Min(12, $idAfter.Length)) + '...')
Assert ($idBefore -ne $idAfter) 'session_regenerate_id(true): el identificador CAMBIA tras autenticar'
Assert ($login.setCookie -match 'mew_session=' -and $login.setCookie -match 'HttpOnly') 'el login reenvia la cookie renovada con HttpOnly'

$dash = Invoke-Req -Uri "$base/dashboard.php" -Session $jarLogin
Assert ($dash.status -eq 200) ('la sesion renovada sigue siendo valida (status=' + $dash.status + ')')

Write-Output ''
Write-Output '=== 3. Sesion invalida despues de cerrar ==='
$tokenDash = $null
if ($dash.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { $tokenDash = $Matches[1] }
$logout = Invoke-Req -Uri "$base/logout.php" -Method POST -Session $jarLogin -Body @{ csrf_token = $tokenDash }
Assert ($logout.setCookie -match 'mew_session=') ('el cierre elimina la cookie (Set-Cookie: ' + $logout.setCookie.Split(';')[0] + ')')
$after = Invoke-Req -Uri "$base/dashboard.php" -Session $jarLogin
Assert ($after.status -eq 302) ('dashboard tras cerrar sesion (status=' + $after.status + ')')

# Limpieza de la cuenta de prueba
cmd /c "C:\xampp\mysql\bin\mysql.exe -u root -D mew_db -e ""DELETE FROM usuarios;"""

Write-Output ''
Write-Output ('RESULTADO: ' + $script:pass + ' pasan, ' + $script:fail + ' fallan')
