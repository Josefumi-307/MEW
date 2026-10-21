# Pruebas funcionales del proyecto Mew sobre Apache (http://localhost/mew/)
$ErrorActionPreference = 'Stop'
$base = 'http://localhost/mew'
$script:pass = 0
$script:fail = 0
$script:failures = @()

# Base de datos limpia al inicio de cada ejecución (idempotencia).
& 'C:\xampp\mysql\bin\mysql.exe' -u root -D mew_db -e 'DELETE FROM usuarios;' 2>&1 | Out-Null

function Assert {
    param([bool]$Condition, [string]$Label, [string]$Detail = '')
    if ($Condition) {
        $script:pass++
        Write-Output ("  [PASS] " + $Label)
    } else {
        $script:fail++
        $script:failures += $Label
        Write-Output ("  [FAIL] " + $Label + $(if ($Detail) { "  -> " + $Detail } else { "" }))
    }
}

function Invoke-Req {
    param([string]$Uri, [string]$Method = 'GET', $Session = $null, [hashtable]$Body = $null)

    $req = [System.Net.HttpWebRequest]::Create($Uri)
    $req.Method = $Method
    $req.AllowAutoRedirect = $false      # queremos ver el 302 y la cabecera Location
    $req.Timeout = 20000
    $req.Proxy = $null                   # conexión directa a localhost
    if ($Session) { $req.CookieContainer = $Session }

    if ($Body) {
        $pairs = New-Object System.Collections.Generic.List[string]
        foreach ($key in $Body.Keys) {
            $pairs.Add([uri]::EscapeDataString([string]$key) + '=' + [uri]::EscapeDataString([string]$Body[$key]))
        }
        $bytes = [System.Text.Encoding]::UTF8.GetBytes([string]::Join('&', $pairs.ToArray()))
        $req.ContentType = 'application/x-www-form-urlencoded'
        $req.ContentLength = $bytes.Length
        $stream = $req.GetRequestStream()
        $stream.Write($bytes, 0, $bytes.Length)
        $stream.Close()
    }

    $resp = $null
    try {
        $resp = $req.GetResponse()
    } catch [System.Net.WebException] {
        $resp = $_.Exception.Response
        if (-not $resp) {
            return @{ status = 0; location = $null; body = ('EXC: ' + $_.Exception.Message) }
        }
    }

    $status = [int]$resp.StatusCode
    $location = $resp.Headers['Location']
    $content = ''
    try {
        $reader = New-Object System.IO.StreamReader($resp.GetResponseStream(), [System.Text.Encoding]::UTF8)
        $content = $reader.ReadToEnd()
        $reader.Close()
    } catch { $content = '' }
    $resp.Close()

    return @{ status = $status; location = [string]$location; body = [string]$content }
}

function New-Session { New-Object System.Net.CookieContainer }

function Get-Csrf {
    param($Session, [string]$Uri)
    $r = Invoke-Req -Uri $Uri -Session $Session
    if ($r.body -match 'name="csrf_token" value="([a-f0-9]{16,})"') { return $Matches[1] }
    return $null
}

function New-PageSession {
    param([string]$Uri)
    $s = New-Session
    $t = Get-Csrf -Session $s -Uri $Uri
    return @{ session = $s; token = $t }
}

Write-Output ''
Write-Output '=== 1. PAGINAS Y ESTRUCTURA ==='
$r = Invoke-Req -Uri "$base/index.php"
Assert ($r.status -eq 200) 'index.php responde 200'
Assert ($r.body -match 'Bienvenido a Mew') 'index muestra el titulo "Bienvenido a Mew"'
Assert ($r.body -match 'Mew' ) 'index muestra el logotipo Mew'
Assert ($r.body -match 'id="login-form"' -and $r.body -match 'action="login.php"') 'formulario de login apunta a login.php'
Assert ($r.body -match 'id="register-form"' -and $r.body -match 'action="register.php"') 'formulario de registro apunta a register.php'
Assert ($r.body -match 'name="csrf_token"') 'los formularios incluyen token CSRF'
$loginBlock = [regex]::Match($r.body, '(?s)<form class="form" id="login-form".*?</form>').Value
$regBlock = [regex]::Match($r.body, '(?s)<form class="form" id="register-form".*?</form>').Value
Assert ($loginBlock -match 'id="login-username" name="nombre_usuario"' -and $loginBlock -match 'Nombre de Usuario') 'login: campo "Nombre de Usuario"'
Assert ($loginBlock -notmatch 'type="email"' -and $loginBlock -notmatch 'name="correo"') 'login: sin campo de correo (solo nombre de usuario)'
Assert ($regBlock -match 'id="register-username"' -and $regBlock -match 'id="register-email"' -and $regBlock -match 'id="register-password"' -and $regBlock -match 'id="register-confirm"') 'registro: nombre de usuario, correo, contraseña y confirmación'
Assert ($regBlock -match 'type="email"') 'el registro conserva el correo con type=email'
Assert (($r.body -split 'Nombre de Usuario').Count -eq 3) 'la etiqueta "Nombre de Usuario" aparece en los dos formularios'
Assert ($r.body -match '<a class="link" id="link-register" href="register.php">') 'enlace "Registrate" presente'
Assert ($r.body -match 'No tienes una cuenta') 'texto del enlace de registro'
Assert ($r.body -match 'id="panel-register"[^>]*hidden') 'panel de registro oculto por defecto'
Assert ($r.body -match 'M.nimo 6 caracteres' -and $r.body -match 'letra may.scula' -and $r.body -match 'un n.mero' -and $r.body -match 's.mbolo') 'lista de requisitos de contrase.a visible'
Assert ($r.body -match 'assets/css/style.css' -and $r.body -match 'assets/js/validation.js') 'CSS y JS enlazados con rutas relativas'

$r = Invoke-Req -Uri "$base/index.php?form=register"
Assert ($r.status -eq 200) 'index.php?form=register responde 200'
Assert ($r.body -match 'id="panel-register">' -and $r.body -match 'id="panel-login"[^>]*hidden') 'el parametro form=register muestra el registro'

$r = Invoke-Req -Uri "$base/config/database.php"
Assert (($r.status -eq 403) -or ($r.status -eq 404)) ('config/database.php es inaccesible directamente (status=' + $r.status + ')')
Assert ($r.body -notmatch 'db_settings|pdo_mysql|password_hash =') 'config/database.php no revela configuracion'
$r = Invoke-Req -Uri "$base/includes/auth.php"
Assert (($r.status -eq 403) -or ($r.status -eq 404)) ('includes/auth.php es inaccesible directamente (status=' + $r.status + ')')
$r = Invoke-Req -Uri "$base/includes/session.php"
Assert (($r.status -eq 403) -or ($r.status -eq 404)) ('includes/session.php es inaccesible directamente (status=' + $r.status + ')')

Write-Output ''
Write-Output '=== 2. VALIDACIONES EN EL SERVIDOR (registro) ==='

$p = New-PageSession "$base/index.php?form=register"
Assert ($null -ne $p.token) 'token CSRF obtenido'
$regBody = @{ csrf_token = $p.token; nombre_usuario = 'usuario.prueba'; correo = 'Usuario.Prueba@Mew.CL'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!' }
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $p.session -Body $regBody
Assert ($r.status -eq 302) ('registro valido redirige (302), status=' + $r.status)
Assert ($r.location -match 'form=login') ('el registro valido vuelve al login: ' + $r.location)
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.body -match 'Cuenta creada correctamente') 'mensaje de registro exitoso visible'
Assert ($r2.body -match 'id="panel-login">' -and $r2.body -match 'id="panel-register"[^>]*hidden') 'tras el registro se muestra el formulario de inicio de sesion'

# Nombre de usuario duplicado (sesion propia, token propio)
$p2 = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $p2.session -Body @{
    csrf_token = $p2.token; nombre_usuario = 'usuario.prueba'; correo = 'distinto@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p2.session
Assert ($r2.body -match 'ya est. en uso') ('nombre de usuario duplicado rechazado -> ' + ($r2.body -replace '(?s).*alert--error">(.{0,90}).*', '$1'))

# Correo duplicado usando otro nombre de usuario
$p2b = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $p2b.session -Body @{
    csrf_token = $p2b.token; nombre_usuario = 'otro_usuario'; correo = 'usuario.prueba@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p2b.session
Assert ($r2.body -match 'ya est. registrado') ('correo duplicado rechazado -> ' + ($r2.body -replace '(?s).*alert--error">(.{0,90}).*', '$1'))

# Nombres de usuario invalidos
$badNames = @('ab', 'espacio con', 'usue@rio', 'abcdefghij1234567890abcdefghij1234567890')
$badLabels = @('demasiado corto (2)', 'con espacio', 'con arroba', 'demasiado largo (40)')
for ($i = 0; $i -lt $badNames.Length; $i++) {
    $px = New-PageSession "$base/index.php?form=register"
    $r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
        csrf_token = $px.token; nombre_usuario = $badNames[$i]; correo = ('nombre' + $i + '@mew.cl'); contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
    }
    $r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
    Assert ($r2.body -match 'nombre de usuario debe tener entre 3 y 32') ("nombre de usuario invalido rechazado (" + $badLabels[$i] + ")")
}

# Contraseñas debiles (una por requisito incumplido)
$weak = @('abcdef1!', 'ABCDEFGH1', 'Abcdefg!x')
$weakLabels = @('sin mayuscula', 'sin numero', 'sin simbolo')
for ($i = 0; $i -lt $weak.Length; $i++) {
    $pw = $weak[$i]
    $px = New-PageSession "$base/index.php?form=register"
    $r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
        csrf_token = $px.token; nombre_usuario = ('debil' + $i); correo = ('debil' + $i + '@mew.cl'); contrasena = $pw; confirmar_contrasena = $pw
    }
    $r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
    Assert ($r2.body -match 'no cumple los requisitos') ("contraseña debil rechazada (" + $weakLabels[$i] + ": " + $pw + ")")
}

# Contraseña demasiado corta
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = 'cortousr'; correo = 'corta@mew.cl'; contrasena = 'A1!aa'; confirmar_contrasena = 'A1!aa'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'no cumple los requisitos') 'contraseña de 5 caracteres rechazada'

# Confirmacion distinta
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = 'confirm1'; correo = 'confirmacion@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Distinta1!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'Las contrase.as no coinciden') 'confirmacion distinta -> "Las contraseñas no coinciden"'
Assert ($r.location -eq 'index.php?form=register') ('la confirmacion fallida vuelve al registro: ' + $r.location)

# Campos vacios
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = ''; correo = ''; contrasena = ''; confirmar_contrasena = ''
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'Complete todos los campos') 'campos vacios -> mensaje de error'

# Nombre de usuario vacio con el resto correcto
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = ''; correo = 'sinnombre@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'Complete todos los campos') 'nombre de usuario vacio rechazado'

# Correo con formato invalido
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = 'correoinv'; correo = 'no-es-un-correo'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'correo electr.nico v.lido') 'correo invalido rechazado en el servidor'

# Correo que no pertenece a la empresa (dominio propio obligatorio)
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = $px.token; nombre_usuario = 'correoajeno'; correo = 'alguien@gmail.com'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'debe pertenecer a la empresa \(@mew\.cl\)') 'correo ajeno a la empresa rechazado (dominio @mew.cl obligatorio)'
Assert ($r2.body -notmatch 'ya est. registrado') 'el rechazo por dominio no se confunde con duplicado'

# Sin token CSRF
$px = New-PageSession "$base/index.php?form=register"
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{
    csrf_token = 'token-falso'; nombre_usuario = 'csrfuser'; correo = 'csrf@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'sesi.n ha expirado') 'POST sin CSRF valido rechazado'
$r = Invoke-Req -Uri "$base/register.php" -Method POST -Session $px.session -Body @{ nombre_usuario = 'csrfuser2'; correo = 'csrf2@mew.cl'; contrasena = 'Mew2024!'; confirmar_contrasena = 'Mew2024!' }
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $px.session
Assert ($r2.body -match 'sesi.n ha expirado') 'POST sin token CSRF rechazado'

Write-Output ''
Write-Output '=== 3. INICIO DE SESION ==='

# Credenciales incorrectas
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = 'usuario.prueba'; contrasena = 'PasswordIncorrecta1!'
}
Assert ($r.status -eq 302) 'login con credenciales erroneas redirige (302)'
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.body -match 'Nombre de usuario o contrase.a incorrectos') 'mensaje generico de credenciales incorrectas'
Assert ($r2.body -notmatch 'SQLSTATE|password_hash|pdo_mysql|mew_db') 'no se filtra informacion interna'
Assert ($r2.body -match 'value="usuario.prueba"') 'el nombre de usuario se conserva en el formulario tras un login fallido'
Assert ($r2.body -notmatch 'value="[^"]*@mew.cl"') 'el correo NO aparece reflejado en el formulario de login'

# Usuario inexistente (mismo mensaje generico)
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = 'no.existe'; contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.body -match 'Nombre de usuario o contrase.a incorrectos') 'usuario inexistente -> mismo mensaje generico'

# El correo ya no sirve para iniciar sesión (solo nombre de usuario)
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = 'usuario.prueba@mew.cl'; contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.status -eq 200 -and $r2.body -match 'nombre de usuario debe tener entre 3 y 32') 'login con correo como nombre de usuario -> formato rechazado'

# Nombre de usuario con formato invalido en el login
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = 'a b'; contrasena = 'Mew2024!'
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.body -match 'nombre de usuario debe tener entre 3 y 32') 'nombre de usuario invalido rechazado en el login'

# Campos vacios
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = ''; contrasena = ''
}
$r2 = Invoke-Req -Uri "$base/$($r.location)" -Session $p.session
Assert ($r2.body -match 'Complete todos los campos') 'login con campos vacios rechazado'

# Credenciales validas (se entra con el nombre de usuario, no con el correo)
$p = New-PageSession "$base/index.php"
$r = Invoke-Req -Uri "$base/login.php" -Method POST -Session $p.session -Body @{
    csrf_token = $p.token; nombre_usuario = 'usuario.prueba'; contrasena = 'Mew2024!'
}
Assert ($r.status -eq 302 -and $r.location -match 'dashboard.php') ('login valido redirige a dashboard.php: ' + $r.location)

Write-Output ''
Write-Output '=== 4. PAGINA PROTEGIDA Y CIERRE DE SESION ==='

$dash = Invoke-Req -Uri "$base/dashboard.php" -Session $p.session
Assert ($dash.status -eq 200) ('dashboard accesible con sesion valida, status=' + $dash.status)
Assert ($dash.body -match 'Bienvenido a Mew') 'dashboard muestra el mensaje de bienvenida'
Assert ($dash.body -match 'Nombre de usuario') 'dashboard muestra la etiqueta del nombre de usuario'
Assert ($dash.body -match '>usuario.prueba<') 'dashboard muestra el nombre del usuario autenticado'
Assert ($dash.body -match 'usuario.prueba@mew.cl') 'dashboard muestra el correo del usuario autenticado'
Assert ($dash.body -match 'Cerrar sesi.n') 'dashboard muestra el boton cerrar sesion'
Assert ($dash.body -match 'action="logout.php"') 'el cierre de sesion es un POST a logout.php'

$anon = New-Session
$noSession = Invoke-Req -Uri "$base/dashboard.php" -Session $anon
Assert ($noSession.status -eq 302 -and $noSession.location -match 'index.php') ('dashboard sin sesion redirige al login: ' + $noSession.location)
$noSession2 = Invoke-Req -Uri "$base/dashboard.php"
Assert ($noSession2.status -eq 302) 'dashboard sin cookie de sesion redirige (302)'

# Cierre de sesion con CSRF
$tokenDash = Get-Csrf -Session $p.session -Uri "$base/dashboard.php"
$r = Invoke-Req -Uri "$base/logout.php" -Method POST -Session $p.session -Body @{ csrf_token = $tokenDash }
Assert ($r.status -eq 302 -and $r.location -match 'index.php') ('logout redirige al inicio: ' + $r.location)
$after = Invoke-Req -Uri "$base/dashboard.php" -Session $p.session
Assert ($after.status -eq 302) 'tras cerrar sesion, dashboard.php vuelve a redirigir'
$afterLogin = Invoke-Req -Uri "$base/login.php" -Session $p.session
Assert ($afterLogin.status -eq 302 -and $afterLogin.location -match 'form=login') 'GET login.php redirige al formulario'

# GET en logout no destruye la sesion de terceros (fuerza bruta por URL)
$p3 = New-PageSession "$base/index.php"
Invoke-Req -Uri "$base/login.php" -Method POST -Session $p3.session -Body @{
    csrf_token = $p3.token; nombre_usuario = 'usuario.prueba'; contrasena = 'Mew2024!'
} | Out-Null
$r = Invoke-Req -Uri "$base/logout.php" -Session $p3.session
Assert ($r.status -eq 302) 'GET logout.php solo redirige (no destruye sin POST+CSRF)'
$still = Invoke-Req -Uri "$base/dashboard.php" -Session $p3.session
Assert ($still.status -eq 200) 'la sesion sigue activa tras un GET a logout.php'

Write-Output ''
Write-Output '=== 5. ALMACENAMIENTO DE CONTRASENAS ==='

$hashes = & 'C:\xampp\mysql\bin\mysql.exe' -u root -D mew_db -N -B -e 'SELECT correo FROM usuarios WHERE password_hash = ''Mew2024!'' OR password_hash NOT LIKE ''$2y%'';'
Assert ([string]::IsNullOrWhiteSpace([string]$hashes)) ('ninguna contraseña se guarda en texto plano ni sin prefijo bcrypt' + $(if ($hashes) { ': ' + $hashes } else { '' }))
$hashRows = & 'C:\xampp\mysql\bin\mysql.exe' -u root -D mew_db -N -B -e 'SELECT COUNT(*) FROM usuarios WHERE password_hash LIKE ''$2y$%'' AND LENGTH(password_hash) > 50;'
Assert ([int]$hashRows -ge 1) 'los hashes bcrypt estan almacenados correctamente'
$dup = & 'C:\xampp\mysql\bin\mysql.exe' -u root -D mew_db -N -B -e 'SELECT COUNT(*) FROM usuarios;'
Assert ([int]$dup -eq 1) ('solo existe la cuenta de prueba (no se crearon duplicados), hay ' + $dup)

Write-Output ''
Write-Output '=== 6. PAGINAS GET DE ENTRADA ==='
$r = Invoke-Req -Uri "$base/register.php"
Assert ($r.status -eq 302 -and $r.location -match 'form=register') 'GET register.php redirige al formulario de registro'
$r = Invoke-Req -Uri "$base/login.php"
Assert ($r.status -eq 302 -and $r.location -match 'form=login') 'GET login.php redirige al formulario de login'
$r = Invoke-Req -Uri "$base/assets/css/style.css"
Assert ($r.status -eq 200) 'style.css responde 200'
$r = Invoke-Req -Uri "$base/assets/js/validation.js"
Assert ($r.status -eq 200) 'validation.js responde 200'

Write-Output ''
Write-Output ('RESULTADO: ' + $script:pass + ' pasan, ' + $script:fail + ' fallan')
if ($script:fail -gt 0) { $script:failures | ForEach-Object { Write-Output ('   FALLO: ' + $_) } }
