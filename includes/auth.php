<?php
/**
 * Lógica de autenticación: guardas de acceso, validación de contraseñas,
 * verificación de credenciales y creación de cuentas.
 *
 * Todas las consultas se ejecutan con PDO y consultas preparadas.
 */

if (!defined('MEW_APP')) {
    http_response_code(404);
    exit;
}

require_once __DIR__ . '/../config/database.php';

/**
 * Hash usado únicamente para igualar el tiempo de respuesta cuando el
 * correo no existe (evita enumerar cuentas midiendo los tiempos).
 */
define('MEW_DECOY_HASH', '$2y$10$92IXUNpkjO0rOQ5byMi.Ye4oKoEa3Ro9llC/.og/at2.uheWG/igi');

/* -------------------------------------------------------------------------
 * Guardas de sesión
 * ---------------------------------------------------------------------- */

/**
 * @return bool
 */
function is_logged_in()
{
    return isset($_SESSION['mew_user_id'], $_SESSION['mew_user_correo']);
}

/**
 * Redirige al inicio de sesión si no hay una sesión autenticada.
 *
 * @return void
 */
function require_login()
{
    if (!is_logged_in()) {
        redirect_to('index.php');
    }
}

/**
 * @return int
 */
function current_user_id()
{
    return (int) (isset($_SESSION['mew_user_id']) ? $_SESSION['mew_user_id'] : 0);
}

/**
 * @return string
 */
function current_user_email()
{
    return (string) (isset($_SESSION['mew_user_correo']) ? $_SESSION['mew_user_correo'] : '');
}

/* -------------------------------------------------------------------------
 * Validaciones
 * ---------------------------------------------------------------------- */

/**
 * Longitud máxima de la contraseña: bcrypt (password_hash) solo procesa
 * los primeros 72 bytes, así que se descartan las contraseñas mayores.
 */
define('MEW_MAX_PASSWORD_LENGTH', 72);

/**
 * Longitud máxima aceptada para el correo (igual que la columna de la BD).
 */
define('MEW_MAX_EMAIL_LENGTH', 190);

/**
 * Dominio de correo propio de la empresa: solo se admiten cuentas en este
 * dominio (p. ej. usuario@mew.cl). Mantener en sincronía con la constante
 * EMAIL_DOMAIN de assets/js/validation.js.
 */
define('MEW_EMAIL_DOMAIN', 'mew.cl');

/**
 * Reglas del nombre de usuario: 3–32 caracteres ASCII (letras, números,
 * punto, guion y guion bajo). Igual en cliente (validation.js) y servidor.
 *
 * @param string $username
 * @return bool
 */
function is_valid_username($username)
{
    return preg_match('/^[A-Za-z0-9._-]{3,32}$/', (string) $username) === 1;
}

/**
 * Mensaje de error cuando el nombre de usuario no cumple las reglas.
 *
 * @return string
 */
function username_error_message()
{
    return 'El nombre de usuario debe tener entre 3 y 32 caracteres y solo puede '
        . 'contener letras, números, puntos, guiones o guion bajo.';
}

/**
 * Comprueba el formato del correo.
 *
 * @param string $email
 * @return bool
 */
function is_valid_email($email)
{
    $email = trim((string) $email);

    if ($email === '' || strlen($email) > MEW_MAX_EMAIL_LENGTH) {
        return false;
    }

    return (bool) filter_var($email, FILTER_VALIDATE_EMAIL);
}

/**
 * Comprueba que el correo pertenece a la empresa (dominio propio de la
 * compañía). No distingue mayúsculas: Usuario@Mew.CL es válido.
 *
 * @param string $email
 * @return bool
 */
function is_company_email($email)
{
    $email = trim((string) $email);

    if (!is_valid_email($email)) {
        return false;
    }

    $at = strrpos($email, '@');
    if ($at === false) {
        return false;
    }

    return strtolower(substr($email, $at + 1)) === MEW_EMAIL_DOMAIN;
}

/**
 * Mensaje de error cuando el correo no es de la empresa.
 *
 * @return string
 */
function company_email_error_message()
{
    return 'El correo electrónico debe pertenecer a la empresa (@' . MEW_EMAIL_DOMAIN . ').';
}

/**
 * Devuelve los requisitos de contraseña incumplidos.
 *
 * IMPORTANTE: debe mantenerse en perfecta sincronía con las reglas de
 * assets/js/validation.js (las mismas 4 condiciones en el mismo orden).
 *
 * @param string $password
 * @return string[] Lista vacía cuando la contraseña es válida.
 */
function password_rule_errors($password)
{
    $password = (string) $password;
    $errors = array();

    if (strlen($password) < 6) {
        $errors[] = 'Tener al menos 6 caracteres.';
    }
    if (strlen($password) > MEW_MAX_PASSWORD_LENGTH) {
        $errors[] = 'No superar los ' . MEW_MAX_PASSWORD_LENGTH . ' caracteres.';
    }
    if (!preg_match('/[A-ZÁÉÍÓÚÜÑ]/', $password)) {
        $errors[] = 'Contener al menos una letra mayúscula.';
    }
    if (!preg_match('/[0-9]/', $password)) {
        $errors[] = 'Contener al menos un número.';
    }
    if (!preg_match('/[^A-Za-z0-9áéíóúüñÁÉÍÓÚÜÑ]/', $password)) {
        $errors[] = 'Contener al menos un símbolo especial (!, @, #, $ o %).';
    }

    return $errors;
}

/* -------------------------------------------------------------------------
 * Operaciones
 * ---------------------------------------------------------------------- */

/**
 * Verifica las credenciales (nombre de usuario + contraseña) en la BD.
 *
 * @param string $username
 * @param string $password
 * @return array{ok: bool, id?: int, nombre?: string, correo?: string}
 */
function authenticate($username, $password)
{
    $stmt = db()->prepare(
        'SELECT id, nombre_usuario, correo, password_hash FROM usuarios WHERE nombre_usuario = ? LIMIT 1'
    );
    $stmt->execute(array(trim((string) $username)));
    $user = $stmt->fetch();

    if (!$user) {
        // Consume tiempo comparable para no revelar si la cuenta existe.
        password_verify((string) $password, MEW_DECOY_HASH);
        return array('ok' => false);
    }

    if (!password_verify((string) $password, (string) $user['password_hash'])) {
        return array('ok' => false);
    }

    // Si los parámetros de hash cambian, se actualiza sin pedir la contraseña.
    if (password_needs_rehash((string) $user['password_hash'], PASSWORD_DEFAULT)) {
        $update = db()->prepare('UPDATE usuarios SET password_hash = ? WHERE id = ?');
        $update->execute(array(
            password_hash((string) $password, PASSWORD_DEFAULT),
            (int) $user['id'],
        ));
    }

    return array(
        'ok'     => true,
        'id'     => (int) $user['id'],
        'nombre' => (string) $user['nombre_usuario'],
        'correo' => (string) $user['correo'],
    );
}

/**
 * Crea una cuenta nueva con la contraseña almacenada como hash.
 *
 * @param string $username
 * @param string $email
 * @param string $password Contraseña en texto plano (nunca se guarda así).
 * @return array{ok: bool, error?: string, id?: int}
 */
function create_user($username, $email, $password)
{
    $username = trim((string) $username);
    $email = trim((string) $email);

    // Comprobación explícita de duplicados (más los índices UNIQUE de la BD).
    $checkUser = db()->prepare('SELECT id FROM usuarios WHERE nombre_usuario = ? LIMIT 1');
    $checkUser->execute(array($username));
    if ($checkUser->fetch()) {
        return array('ok' => false, 'error' => 'duplicated_username');
    }

    $checkEmail = db()->prepare('SELECT id FROM usuarios WHERE correo = ? LIMIT 1');
    $checkEmail->execute(array($email));
    if ($checkEmail->fetch()) {
        return array('ok' => false, 'error' => 'duplicated');
    }

    $hash = password_hash((string) $password, PASSWORD_DEFAULT);
    if ($hash === false) {
        return array('ok' => false, 'error' => 'hash');
    }

    try {
        $insert = db()->prepare(
            'INSERT INTO usuarios (nombre_usuario, correo, password_hash) VALUES (?, ?, ?)'
        );
        $insert->execute(array($username, $email, $hash));
    } catch (PDOException $e) {
        // 23000 = violación de restricción (dato duplicado a la carrera).
        if ((string) $e->getCode() === '23000') {
            $isUsername = preg_match('/uq_usuarios_nombre/', (string) $e->getMessage()) === 1;
            return array('ok' => false, 'error' => $isUsername ? 'duplicated_username' : 'duplicated');
        }
        throw $e;
    }

    return array(
        'ok'  => true,
        'id'  => (int) db()->lastInsertId(),
    );
}
