<?php
/**
 * Procesamiento del inicio de sesión (nombre de usuario + contraseña).
 *
 * POST → valida, comprueba credenciales con password_verify() y crea la
 *        sesión. Éxito: redirige a dashboard.php. Fallo: vuelve al
 *        formulario con un mensaje genérico (patrón PRG).
 * GET  → redirige al formulario de inicio de sesión.
 */

define('MEW_APP', true);

require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/auth.php';

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    redirect_to('index.php?form=login');
}

/**
 * Registra el error y devuelve al formulario con el mensaje.
 *
 * @param string      $message
 * @param string|null $username Nombre a conservar en el formulario.
 * @return void
 */
$fail = function ($message, $username = null) {
    flash_set('error', $message);
    if ($username !== null && $username !== '') {
        $_SESSION['old_username'] = $username;
    }
    redirect_to('index.php?form=login');
};

// 1) Protección CSRF.
if (!csrf_verify(isset($_POST['csrf_token']) ? $_POST['csrf_token'] : null)) {
    $fail('Su sesión ha expirado. Vuelva a intentarlo.');
}

$username = trim((string) (isset($_POST['nombre_usuario']) ? $_POST['nombre_usuario'] : ''));
$password = (string) (isset($_POST['contrasena']) ? $_POST['contrasena'] : '');

// 2) Campos obligatorios.
if ($username === '' || $password === '') {
    $fail('Complete todos los campos.', $username);
}

// 3) Formato del nombre de usuario.
if (!is_valid_username($username)) {
    $fail(username_error_message(), $username);
}

// 4) Credenciales (mensaje genérico: no revela si la cuenta existe).
try {
    $result = authenticate($username, $password);
} catch (Throwable $e) {
    error_log('[Mew] Login: ' . $e->getMessage());
    $fail('No es posible iniciar sesión en este momento. Inténtelo de nuevo más tarde.', $username);
}

if (empty($result['ok'])) {
    $fail('Nombre de usuario o contraseña incorrectos.', $username);
}

// 5) Sesión autenticada: se regenera el identificador para evitar fijación.
session_regenerate_id(true);

$_SESSION['mew_user_id']     = $result['id'];
$_SESSION['mew_user_correo'] = $result['correo'];

unset($_SESSION['old_username']);

redirect_to('dashboard.php');
