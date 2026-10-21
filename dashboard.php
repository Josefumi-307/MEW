<?php
/**
 * Página protegida: se muestra únicamente con una sesión autenticada.
 *
 * El correo mostrado proviene del registro autenticado y se escapa con e()
 * antes de imprimirse en HTML.
 */

define('MEW_APP', true);

require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/auth.php';

// Sin sesión válida → redirección al formulario de inicio de sesión.
require_login();

// Se recuperan los datos desde la base de datos por el id de la sesión.
try {
    $stmt = db()->prepare('SELECT nombre_usuario, correo FROM usuarios WHERE id = ? LIMIT 1');
    $stmt->execute(array(current_user_id()));
    $user = $stmt->fetch();
} catch (Throwable $e) {
    error_log('[Mew] Dashboard: ' . $e->getMessage());
    $user = false;
}

// Cuenta eliminada o sesión huérfana: se invalida y se vuelve al acceso.
if (!$user) {
    session_discard();
    redirect_to('index.php?form=login');
}

$nombre = (string) $user['nombre_usuario'];
$email  = (string) $user['correo'];
$csrf   = csrf_token();

// Evita que el navegador muestre la página desde la caché tras cerrar sesión.
header('Cache-Control: no-store, no-cache, must-revalidate, private');
header('Pragma: no-cache');
header('X-Content-Type-Options: nosniff');
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Mew — Panel</title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><circle cx='32' cy='32' r='30' fill='%234f46e5'/><path d='M10 32Q32 8 54 32Q32 56 10 32Z' fill='white'/><circle cx='32' cy='32' r='9' fill='%234c1d95'/><circle cx='35.5' cy='28.5' r='3' fill='white'/></svg>">
    <link rel="stylesheet" href="assets/css/style.css">
</head>
<body class="page">
    <div class="page__glow page__glow--one" aria-hidden="true"></div>
    <div class="page__glow page__glow--two" aria-hidden="true"></div>

    <main class="shell">
        <section class="card dashboard" aria-labelledby="dashboard-title">
            <p class="brand"><span class="brand__badge" aria-hidden="true"><svg class="brand__eye" viewBox="0 0 24 24" focusable="false"><path d="M1.4 12Q12 1.5 22.6 12Q12 22.5 1.4 12Z" fill="#fff"/><circle cx="12" cy="12" r="3.8" fill="#4c1d95"/><circle cx="13.6" cy="10.4" r="1.3" fill="#fff"/></svg></span><span class="brand__name">Mew</span></p>

            <h1 class="panel__title" id="dashboard-title">Bienvenido a Mew</h1>
            <p class="panel__subtitle">Has iniciado sesión correctamente.</p>

            <div class="account">
                <div class="account__row">
                    <p class="account__label">Nombre de usuario</p>
                    <p class="account__value"><?php echo e($nombre); ?></p>
                </div>
                <div class="account__row">
                    <p class="account__label">Correo electrónico</p>
                    <p class="account__value"><?php echo e($email); ?></p>
                </div>
            </div>

            <form class="form" action="logout.php" method="post">
                <input type="hidden" name="csrf_token" value="<?php echo e($csrf); ?>">
                <button class="btn btn--primary" type="submit">Cerrar sesión</button>
            </form>
        </section>
    </main>
</body>
</html>
