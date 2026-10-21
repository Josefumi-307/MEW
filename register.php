<?php
/**
 * Procesamiento del registro de cuentas.
 *
 * POST → valida en el servidor (campos, nombre de usuario, correo, requisitos
 *        de la contraseña, confirmación y unicidad), guarda la contraseña con
 *        password_hash() e inserta con PDO/consulta preparada. Éxito: mensaje
 *        de bienvenida y vuelta al inicio de sesión. Fallo: PRG con el error.
 * GET  → redirige al formulario de registro.
 */

define('MEW_APP', true);

require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/auth.php';

if (isset($_SERVER['REQUEST_METHOD']) && $_SERVER['REQUEST_METHOD'] !== 'POST') {
    redirect_to('index.php?form=register');
}

/**
 * Registra el error y devuelve al formulario conservando los datos escritos.
 *
 * @param string $message
 * @param string $username
 * @param string $email
 * @return void
 */
$fail = function ($message, $username = '', $email = '') {
    flash_set('error', $message);
    if ($username !== '') {
        $_SESSION['old_username'] = $username;
    }
    if ($email !== '') {
        $_SESSION['old_email'] = $email;
    }
    redirect_to('index.php?form=register');
};

// 1) Protección CSRF.
if (!csrf_verify(isset($_POST['csrf_token']) ? $_POST['csrf_token'] : null)) {
    $fail('Su sesión ha expirado. Vuelva a intentarlo.');
}

$username           = trim((string) (isset($_POST['nombre_usuario']) ? $_POST['nombre_usuario'] : ''));
$email              = trim((string) (isset($_POST['correo']) ? $_POST['correo'] : ''));
$password           = (string) (isset($_POST['contrasena']) ? $_POST['contrasena'] : '');
$confirmPassword    = (string) (isset($_POST['confirmar_contrasena']) ? $_POST['confirmar_contrasena'] : '');

// 2) Todos los campos son obligatorios.
if ($username === '' || $email === '' || $password === '' || $confirmPassword === '') {
    $fail('Complete todos los campos.', $username, $email);
}

// 3) Formato del nombre de usuario.
if (!is_valid_username($username)) {
    $fail(username_error_message(), $username, $email);
}

// 4) Formato del correo.
if (!is_valid_email($email)) {
    $fail('Introduzca un correo electrónico válido.', $username, $email);
}

// 5) El correo debe ser propio de la empresa (dominio @mew.cl).
if (!is_company_email($email)) {
    $fail(company_email_error_message(), $username, $email);
}

// 6) Requisitos de la contraseña.
$ruleErrors = password_rule_errors($password);
if (!empty($ruleErrors)) {
    $fail('La contraseña no cumple los requisitos: ' . implode(' ', $ruleErrors), $username, $email);
}

// 7) La confirmación debe coincidir exactamente.
if (!hash_equals($password, $confirmPassword)) {
    $fail('Las contraseñas no coinciden', $username, $email);
}

// 8) Creación de la cuenta.
try {
    $result = create_user($username, $email, $password);
} catch (Throwable $e) {
    error_log('[Mew] Registro: ' . $e->getMessage());
    $fail('No se pudo crear la cuenta en este momento. Inténtelo de nuevo más tarde.', $username, $email);
}

if (empty($result['ok'])) {
    if (isset($result['error']) && $result['error'] === 'duplicated_username') {
        $fail('Ese nombre de usuario ya está en uso.', $username, $email);
    }
    if (isset($result['error']) && $result['error'] === 'duplicated') {
        $fail('Ese correo electrónico ya está registrado.', $username, $email);
    }
    $fail('No se pudo crear la cuenta. Inténtelo de nuevo más tarde.', $username, $email);
}

// 9) Éxito: se informa y se vuelve al inicio de sesión.
unset($_SESSION['old_username'], $_SESSION['old_email']);
flash_set('success', 'Cuenta creada correctamente. Ya puedes iniciar sesión.');

redirect_to('index.php?form=login');
