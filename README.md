# Mew — Autenticación con PHP y MySQL

Aplicación web funcional para la empresa **Mew**: inicio de sesión y registro de
usuarios con PHP, MySQL (PDO), validación en cliente (JavaScript) y una página
protegida (`dashboard.php`). Sin frameworks ni dependencias externas: solo
HTML5, CSS3, JavaScript, PHP y MySQL.

---

## 1. Requisitos

| Requisito | Detalle |
|-----------|---------|
| Sistema | Windows con **XAMPP** (Apache, PHP, MySQL/MariaDB). También funciona con WAMP, MAMP o cualquier servidor PHP. |
| PHP | **8.1 o superior** (probado con PHP 8.2.12, el que incluye XAMPP). |
| Extensión PHP | `pdo_mysql` (incluida por defecto en XAMPP). |
| MySQL/MariaDB | Cualquier versión incluida en XAMPP (probado con MariaDB 10.4.32). |
| Navegador | Cualquiera moderno. La interfaz no necesita conexión a Internet. |

No se requiere Node.js, npm, npm install, Vite, Docker ni frameworks.

---

## 2. Instalación con XAMPP (paso a paso)

1. **Copie el proyecto** en `C:\xampp\htdocs\mew\`
   (debe quedar en `C:\xampp\htdocs\mew\index.php`).
2. **Abra el panel de control de XAMPP** (`C:\xampp\xampp-control.exe`).
3. **Inicie Apache y MySQL** (botones *Start* de cada servicio).
4. **Abra phpMyAdmin**: <http://localhost/phpmyadmin/>
5. **Importe la base de datos**:
   * Pestaña **Importar** → *Seleccionar archivo* → elija `database.sql` → **Continuar**.
   * Esto crea la base de datos `mew_db` y la tabla `usuarios`
     (columnas `nombre_usuario` y `correo`, ambas con índice único).
   * Alternativa desde consola:
     ```bat
     C:\xampp\mysql\bin\mysql.exe -u root -p < database.sql
     ```
6. **Configure las credenciales de conexión** (apartado 3).
7. **Acceda a la aplicación**: <http://localhost/mew/>

---

## 3. Configuración de la conexión a MySQL

Las credenciales viven **solo** en `config/database.php` (y opcionalmente en
`config/database.local.php`, que está excluido de Git mediante `.gitignore`).

Valores por defecto (instalación local típica de XAMPP):

```php
$settings = array(
    'host' => 'localhost',
    'name' => 'mew_db',
    'user' => 'root',
    'pass' => '',        // contraseña vacía en XAMPP por defecto
);
```

> **Importante:** compruebe su configuración local; no todas las instalaciones
> de XAMPP son iguales. Para no editar `database.php`, cree el archivo
> `config/database.local.php` (no se versiona) con este contenido:
>
> ```php
> <?php
> return array(
>     'host' => 'localhost',
>     'name' => 'mew_db',
>     'user' => 'mew_app',
>     'pass' => 'su-contraseña',
> );
> ```
>
> Este proyecto **no crea ni modifica usuarios de MySQL**: si desea un usuario
> dedicado, créelo usted mismo desde phpMyAdmin con permisos solo sobre
> `mew_db` y anótelo en `database.local.php`.

### Arranque manual sin XAMPP (opcional)

```bat
cd C:\xampp\htdocs\mew
C:\xampp\php\php.exe -S localhost:8000
```

y abra <http://localhost:8000/>. El proyecto usa rutas relativas, así que
funciona tanto en la raíz como en un subdirectorio.

---

## 4. Cómo probar la aplicación

Abra <http://localhost/mew/> y verifique los siguientes flujos:

1. **Registro correcto**: pulse *¿No tienes una cuenta? Regístrate*, escriba un
   **nombre de usuario** válido (3–32 caracteres: letras, números, punto,
   guion o guion bajo), un **correo de la empresa** (`nombre@mew.cl`; solo se
   admiten cuentas con dominio `@mew.cl`) y una contraseña que cumpla los 4
   requisitos (mín. 6 caracteres, una mayúscula, un número y un símbolo),
   repítala y pulse *Crear cuenta*. Debe mostrarse *"Cuenta creada
   correctamente"* y aparecer el formulario de acceso.
2. **Nombre de usuario duplicado**: repita el registro con el mismo nombre de
   usuario. Debe mostrarse *"Ese nombre de usuario ya está en uso."*
3. **Correo duplicado**: repita el registro con otro nombre de usuario y el
   mismo correo. Debe mostrarse *"Ese correo electrónico ya está registrado."*
4. **Datos con formato no admitido**: pruebe un nombre de usuario inválido
   (`ab` demasiado corto, `usuario con espacio`) y un correo que no sea de la
   empresa (`alguien@gmail.com`). Deben rechazarse con el mensaje
   correspondiente.
5. **Contraseña débil**: pruebe `abcdef1!` (sin mayúscula), `ABCDEFGH1` (sin
   símbolo) o `Abcdefg!` (sin número). Deben rechazarse.
6. **Confirmación distinta**: escriba contraseñas diferentes en los dos campos.
   Debe bloquearse el envío con el mensaje *"Las contraseñas no coinciden"*.
7. **Inicio de sesión correcto**: con el **nombre de usuario** y la contraseña
   creados (el correo no sirve para entrar) debe redirigir a `dashboard.php`,
   que muestra el logo, el mensaje de bienvenida, el nombre de usuario y el
   correo.
8. **Credenciales incorrectas**: una contraseña errónea muestra el mensaje
   genérico *"Nombre de usuario o contraseña incorrectos"*.
9. **Acceso sin sesión**: abra <http://localhost/mew/dashboard.php> en una
   ventana anónima. Debe redirigir al inicio de sesión.
10. **Cierre de sesión**: pulse *Cerrar sesión*; la sesión queda invalidada y
    volver a abrir `dashboard.php` redirige al inicio.
11. **Almacenamiento de contraseñas**: compruebe que no se guarda texto plano:
    ```bat
    C:\xampp\mysql\bin\mysql.exe -u root -D mew_db -e "SELECT nombre_usuario, correo, LEFT(password_hash, 7) AS prefijo FROM usuarios;"
    ```
    El prefijo debe ser `$2y$...` (hash bcrypt).
12. **Móvil**: reduzca la ventana o use las herramientas del navegador; el
    formulario se adapta y los botones siguen siendo utilizables.

---

## 5. Estructura del proyecto

```
mew/
├── index.php            Presentación: formularios de acceso y registro
├── register.php         Procesamiento del registro (POST) / redirección (GET)
├── login.php            Procesamiento del inicio de sesión (POST)
├── dashboard.php        Página protegida (requiere sesión)
├── logout.php           Destrucción de la sesión (POST + CSRF)
├── config/
│   ├── database.php     Configuración y conexión PDO (credenciales)
│   └── .htaccess        Deniega el acceso HTTP directo a esta carpeta
├── assets/
│   ├── css/style.css    Diseño, animaciones y adaptación a móviles
│   └── js/validation.js Validaciones e interfaz en el navegador
├── includes/
│   ├── session.php      Cookies seguras, tokens CSRF, mensajes flash
│   ├── auth.php         Guardas, reglas de contraseña, login/registro
│   └── .htaccess        Deniega el acceso HTTP directo a esta carpeta
├── tests/
│   ├── mew_test.ps1         Suite HTTP: 77 aserciones (registro, login, sesión)
│   ├── mew_session_test.ps1 Suite de sesión y CSRF: 14 aserciones
│   ├── mew_db_error_test.ps1 Suite de fallos de base de datos: 10 aserciones
│   └── mew_shots.ps1        Generador de capturas con Chrome headless
├── docs/
│   ├── mew-logo-eye.svg     Muestra del logotipo (ojo) del proyecto
│   └── capturas/            11 capturas en 1366/768/390/340 px
├── database.sql         Creación de mew_db y de la tabla usuarios
├── .gitignore           Excluye config/database.local.php
└── README.md            Este archivo
```

La presentación (`index.php`, `dashboard.php`), la lógica de autenticación
(`includes/`, `login.php`, `register.php`, `logout.php`) y la configuración de
la base de datos (`config/`) están separadas.

Las suites automatizadas de `tests/` se ejecutan con XAMPP en marcha, por
ejemplo: `powershell -NoProfile -ExecutionPolicy Bypass -File tests\mew_test.ps1`.
Comprueban por HTTP los mensajes exactos, la validación de contraseña, el
dominio `@mew.cl`, los tokens CSRF y el comportamiento de la sesión; el
inventario completo está en la sección 8.

---

## 6. Seguridad implementada

- Consultas preparadas con **PDO** (`ATTR_EMULATE_PREPARES = false`): sin
  inyección SQL.
- Contraseñas con **`password_hash()`** (bcrypt) y **`password_verify()`**;
  jamás se guarda ni se muestra texto plano.
- Validación **en cliente y en el servidor** (el servidor es la autoridad).
- Escapado de toda salida con `htmlspecialchars()` vía `e()`: sin XSS reflejado.
- Cookies de sesión con **`HttpOnly`**, **`SameSite=Lax`** y **`Secure`**
  automáticamente cuando la petición llega por HTTPS.
- **`session_regenerate_id(true)`** tras autenticar: sin fijación de sesión.
- **Tokens CSRF** en todos los formularios que modifican datos (login,
  registro y cierre de sesión).
- Mensajes de error **genéricos**: nunca se muestran contraseñas, hashes,
  consultas SQL ni credenciales de MySQL. Los detalles técnicos van al
  `error_log` de PHP.
- Credenciales fuera de la vista pública y fuera de Git
  (`config/database.local.php` ignorado).
- Archivos internos (`config/`, `includes/`) devuelven 404 si se piden
  directamente.
- `dashboard.php` se envía con `Cache-Control: no-store`.

### Antes de publicar en Internet

1. **HTTPS obligatorio** (certificado válido). La cookie de sesión activará
   `Secure` sola al detectar HTTPS, pero la aplicación debe servirse siempre
   por HTTPS.
2. **Cambie las credenciales de MySQL**: cree un usuario propio con permisos
   mínimos sobre `mew_db` y guárdelo en `config/database.local.php` (fuera del
   repositorio). Nunca use `root`.
3. `display_errors = Off` en el `php.ini` de producción y revisar
   `error_log`.
4. Mantener `database.local.php` fuera del repositorio (ya está en
   `.gitignore`) y no subir `database.sql` con datos reales.
5. Configurar `session.cookie_secure = 1` en el `php.ini` de producción.
6. Limitar el tamaño de las peticiones y añadir un cortafuegos/rate limiting
   a `login.php` si la página se expone públicamente.

---

## 7. Diagnóstico de problemas

| Síntoma | Causa probable | Solución |
|---------|----------------|----------|
| `http://localhost/` no responde | Apache parado o puerto 80 ocupado | Inicie Apache en el panel de XAMPP; si el puerto está ocupado, cámbielo en `httpd.conf` |
| No hay respuesta en el puerto 3306 | MySQL parado | Pulse *Start* junto a MySQL en XAMPP |
| *"La base de datos no existe"* | Falta importar el esquema | Importe `database.sql` en phpMyAdmin |
| *"Credenciales de MySQL incorrectas"* | Usuario/contraseña distintos a los de su instalación | Ajuste `config/database.php` o `config/database.local.php` |
| *"Falta la extensión PHP pdo_mysql"* | Extensión desactivada | Descomente `extension=pdo_mysql` en `php.ini` y reinicie Apache |
| Página en blanco o error 500 | Error PHP no capturado | Revise `C:\xampp\apache\logs\error.log` (destino por defecto de PHP en XAMPP) y, si `error_log` apunta a otro fichero en `php.ini`, ese archivo |

Los mensajes mostrados al usuario nunca incluyen credenciales ni detalles
internos: el detalle completo se escribe en el **log de errores de PHP**,
accesible solo en el servidor.

---

## 8. Pruebas realizadas

Este proyecto se ejecutó y verificó en una instalación local real de XAMPP
(Apache, **PHP 8.2.12** con `pdo_mysql` habilitado y **MariaDB 10.4.32**),
sirviendo la aplicación en `http://localhost/mew/` con la base de datos
importada desde `database.sql`.

Comprobaciones automatizadas sobre HTTP (101 aserciones, todas en verde):

- Registro correcto y mensaje de éxito; nombre de usuario duplicado y correo
  duplicado rechazados con mensajes distintos.
- Nombres de usuario inválidos rechazados en registro y en acceso (longitud
  y caracteres no permitidos).
- **Correo rechazado si no es de la empresa**: el dominio propio `@mew.cl` es
  obligatorio en el registro (también en el navegador, sin distinguir
  mayúsculas), mientras que un correo con formato inválido muestra otro
  mensaje distinto.
- Contraseñas débiles rechazadas (sin mayúscula, sin número, sin símbolo,
  menos de 6 caracteres) y confirmación distinta rechazada con el mensaje
  *"Las contraseñas no coinciden"*.
- Validación de campos vacíos, de formato de correo y de nombre de usuario
  **en el servidor**.
- Formularios protegidos por CSRF (POST sin token rechazado).
- Inicio de sesión con el **nombre de usuario** → `dashboard.php` (el correo
  no sirve para entrar); credenciales erróneas y usuario inexistente →
  mensaje genérico idéntico, sin fugas de información.
- `dashboard.php` muestra nombre de usuario y correo escapados, redirige sin
  sesión; el cierre de sesión destruye la cookie y la sesión deja de ser
  válida; `logout.php` por GET no destruye nada.
- Cookie de sesión emitida con `HttpOnly` y `SameSite=Lax` (y sin `Secure`
  en HTTP, que se activa automáticamente en HTTPS).
- El identificador de sesión **cambia** tras autenticar
  (`session_regenerate_id(true)`).
- Las contraseñas solo existen como hash bcrypt (`$2y$…`) en la tabla.
- `config/` e `includes/` devuelven 403 si se piden por HTTP.
- Errores de configuración de MySQL (credenciales erróneas o base de datos
  inexistente): mensaje genérico en pantalla y detalle completo solo en el
  log del servidor; la contraseña nunca aparece en la página ni en el log.

Interacción verificada en navegador real:

- Alternancia entre los dos formularios sin recargar (URL, título y foco
  actualizados), y navegación con los enlaces cuando no hay JavaScript.
- El logotipo es un **ojo blanco sobre fondo morado** (SVG en la insignia y
  en el favicon) y se muestra también en el panel protegido.
- Los 4 requisitos de la contraseña cambian de estado mientras se escribe, y
  un correo que no termina en `@mew.cl` muestra en vivo el mensaje
  *"El correo electrónico debe pertenecer a la empresa (@mew.cl)."*
  (`JUAN@MEW.CL` se acepta: no distingue mayúsculas).
- El envío se bloquea y coloca el foco en el campo inválido, con el mensaje
  exacto *"Las contraseñas no coinciden"*.
- Registro con nombre de usuario, inicio de sesión con ese nombre, panel con
  nombre y correo, y cierre de sesión completos en el navegador; después de
  cerrar, `dashboard.php` vuelve a redirigir. Sin errores de consola.

La adaptación a móviles está implementada con las consultas medias
`@media (max-width: 480px)`, `@media (max-width: 340px)` y
`@media (prefers-reduced-motion: reduce)`, y se comprobó de dos formas:

- **Medición en el motor de renderizado**: en iframes de 320, 340, 390, 480,
  768, 1024 y 1366 px, `scrollWidth` coincide con el ancho de la ventana (no
  hay desplazamiento horizontal) y las consultas medias activan su bloque en
  el punto de corte correcto.
- **11 capturas reales** con Chrome 155 en modo *headless* (script
  `tests/mew_shots.ps1`, imágenes en `docs/capturas/`): inicio de sesión,
  registro, panel y estado de foco en 1366, 768, 390 y 340 px. Cada captura
  se verificó por píxeles: la tarjeta nunca toca el borde derecho. Chrome
  headless no permite ventanas por debajo de ~500 px, así que las capturas
  estrechas se tomaron con un iframe del ancho pedido (las consultas medias
  responden al ancho del iframe, igual que en un móvil real) y recorte
  posterior.

Único punto no fotografiado en este entorno: el estado `:focus` de los
campos. La ventana del navegador no tiene foco de sistema
(`document.hasFocus()` es `false`) y Chrome omite entonces los estilos
`:focus`; la regla `.field__input:focus` (borde de marca y `box-shadow` con
`--ring`) está implementada y verificada en la hoja de estilos.

---

## 9. Notas de compatibilidad

- **Base de datos creada con una versión anterior** de `database.sql` (sin la
  columna `nombre_usuario`): ejecute una sola vez
  ```bat
  C:\xampp\mysql\bin\mysql.exe -u root -D mew_db -e "ALTER TABLE usuarios ADD COLUMN nombre_usuario VARCHAR(50) NOT NULL AFTER id, ADD UNIQUE KEY uq_usuarios_nombre (nombre_usuario);"
  ```
  Reimportar `database.sql` sobre una base ya existente no altera los datos:
  el script usa `CREATE DATABASE IF NOT EXISTS` y `CREATE TABLE IF NOT EXISTS`.
- Rutas **relativas**: la aplicación funciona en `http://localhost/mew/` o en
  la raíz del servidor sin cambios.
- Sin servicios externos: no pide CDNs, fuentes web ni APIs de terceros.
- Solo se requieren los ficheros de este repositorio; no hay proceso de
  build.
