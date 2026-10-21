<?php
/**
 * Cierre de sesión.
 *
 * Solo acepta POST con token CSRF (bloquea los cierres forzados por GET).
 * Destruye la sesión, borra la cookie y redirige al formulario de acceso.
 */

define('MEW_APP', true);

require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/auth.php';

if (
    isset($_SERVER['REQUEST_METHOD'])
    && $_SERVER['REQUEST_METHOD'] === 'POST'
    && csrf_verify(isset($_POST['csrf_token']) ? $_POST['csrf_token'] : null)
) {
    session_discard();
}

redirect_to('index.php?form=login');
