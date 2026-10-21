<?php
/**
 * Arranque de la sesión y utilidades compartidas.
 *
 * Solo debe incluirse desde los puntos de entrada de la aplicación
 * (index.php, login.php, register.php, dashboard.php, logout.php).
 */

if (!defined('MEW_APP')) {
    http_response_code(404);
    exit;
}

/* -------------------------------------------------------------------------
 * Cookies de sesión: HttpOnly + SameSite, y Secure cuando se usa HTTPS.
 * ---------------------------------------------------------------------- */
if (session_status() === PHP_SESSION_NONE) {
    ini_set('session.use_strict_mode', '1');
    ini_set('session.use_only_cookies', '1');
    ini_set('session.cookie_httponly', '1');

    session_name('mew_session');
    session_set_cookie_params(array(
        'lifetime' => 0,
        'path'     => '/',
        'domain'   => '',
        'secure'   => mew_is_https(),
        'httponly' => true,
        'samesite' => 'Lax',
    ));
    session_start();
}

/**
 * Indica si la petición se está atendiendo mediante HTTPS.
 *
 * @return bool
 */
function mew_is_https()
{
    if (!empty($_SERVER['HTTPS']) && strtolower((string) $_SERVER['HTTPS']) !== 'off') {
        return true;
    }

    return (int) (isset($_SERVER['SERVER_PORT']) ? $_SERVER['SERVER_PORT'] : 0) === 443;
}

/**
 * Escapa un valor para imprimirlo con seguridad en HTML (prevención de XSS).
 *
 * @param mixed $value
 * @return string
 */
function e($value)
{
    return htmlspecialchars((string) ($value === null ? '' : $value), ENT_QUOTES | ENT_SUBSTITUTE, 'UTF-8');
}

/**
 * Redirección HTTP 302 y fin de la petición.
 *
 * @param string $url URL relativa al directorio de la aplicación.
 * @return void
 */
function redirect_to($url)
{
    if (!headers_sent()) {
        header('Location: ' . $url, true, 302);
    }
    exit;
}

/* -------------------------------------------------------------------------
 * Token CSRF
 * ---------------------------------------------------------------------- */

/**
 * Devuelve (y crea si hace falta) el token CSRF de la sesión actual.
 *
 * @return string
 */
function csrf_token()
{
    if (empty($_SESSION['_csrf'])) {
        $_SESSION['_csrf'] = bin2hex(random_bytes(32));
    }

    return $_SESSION['_csrf'];
}

/**
 * Compara el token recibido con el de la sesión de forma segura.
 *
 * @param mixed $token
 * @return bool
 */
function csrf_verify($token)
{
    return is_string($token)
        && !empty($_SESSION['_csrf'])
        && hash_equals($_SESSION['_csrf'], $token);
}

/* -------------------------------------------------------------------------
 * Mensajes flash (se muestran una sola vez tras una redirección)
 * ---------------------------------------------------------------------- */

/**
 * Guarda un mensaje para la siguiente petición.
 *
 * @param string $type    'success' | 'error'
 * @param string $message Mensaje ya redactado (sin datos sensibles).
 * @return void
 */
function flash_set($type, $message)
{
    $_SESSION['_flash'] = array(
        'type'    => ($type === 'success') ? 'success' : 'error',
        'message' => (string) $message,
    );
}

/**
 * Lee y elimina el mensaje flash pendiente.
 *
 * @return array{type: string, message: string}|null
 */
function flash_pull()
{
    if (empty($_SESSION['_flash']) || !is_array($_SESSION['_flash'])) {
        return null;
    }

    $flash = $_SESSION['_flash'];
    unset($_SESSION['_flash']);

    return $flash;
}

/**
 * Destruye por completo la sesión actual y borra su cookie.
 *
 * @return void
 */
function session_discard()
{
    $_SESSION = array();

    if (ini_get('session.use_cookies')) {
        $params = session_get_cookie_params();
        setcookie(session_name(), '', array(
            'expires'  => time() - 42000,
            'path'     => isset($params['path']) ? $params['path'] : '/',
            'domain'   => isset($params['domain']) ? $params['domain'] : '',
            'secure'   => !empty($params['secure']),
            'httponly' => !empty($params['httponly']),
            'samesite' => isset($params['samesite']) ? $params['samesite'] : 'Lax',
        ));
    }

    if (session_status() === PHP_SESSION_ACTIVE) {
        session_destroy();
    }
}
