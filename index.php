<?php
/**
 * Página principal de Mew.
 *
 * Presenta los dos formularios (inicio de sesión y registro) con la misma
 * identidad visual. El formulario visible se controla con el parámetro
 * ?form=register y, adicionalmente, con assets/js/validation.js, que
 * alterna entre ellos sin recargar la página. Sin JavaScript, los enlaces
 * navegan normalmente a register.php / login.php, que redirigen aquí.
 */

define('MEW_APP', true);

require_once __DIR__ . '/includes/session.php';
require_once __DIR__ . '/includes/auth.php';

// Quien ya tiene sesión va directo al panel protegido.
if (is_logged_in()) {
    redirect_to('dashboard.php');
}

$view         = ((isset($_GET['form']) ? $_GET['form'] : '') === 'register') ? 'register' : 'login';
$flash        = flash_pull();
$oldUsername  = (string) (isset($_SESSION['old_username']) ? $_SESSION['old_username'] : '');
$oldEmail     = (string) (isset($_SESSION['old_email']) ? $_SESSION['old_email'] : '');
$csrf         = csrf_token();

unset($_SESSION['old_username'], $_SESSION['old_email']);
?>
<!DOCTYPE html>
<html lang="es">
<head>
    <meta charset="utf-8">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <meta name="robots" content="noindex, nofollow">
    <title>Mew — <?php echo $view === 'register' ? 'Crear cuenta' : 'Iniciar sesión'; ?></title>
    <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'><circle cx='32' cy='32' r='30' fill='%234f46e5'/><path d='M10 32Q32 8 54 32Q32 56 10 32Z' fill='white'/><circle cx='32' cy='32' r='9' fill='%234c1d95'/><circle cx='35.5' cy='28.5' r='3' fill='white'/></svg>">
    <link rel="stylesheet" href="assets/css/style.css">
    <script src="assets/js/validation.js" defer></script>
</head>
<body class="page">
    <div class="page__glow page__glow--one" aria-hidden="true"></div>
    <div class="page__glow page__glow--two" aria-hidden="true"></div>

    <main class="shell">
        <section class="card auth-card" aria-label="Acceso a Mew">
            <p class="brand"><span class="brand__badge" aria-hidden="true"><svg class="brand__eye" viewBox="0 0 24 24" focusable="false"><path d="M1.4 12Q12 1.5 22.6 12Q12 22.5 1.4 12Z" fill="#fff"/><circle cx="12" cy="12" r="3.8" fill="#4c1d95"/><circle cx="13.6" cy="10.4" r="1.3" fill="#fff"/></svg></span><span class="brand__name">Mew</span></p>

            <?php if (!empty($flash)): ?>
                <div class="alert alert--<?php echo $flash['type'] === 'success' ? 'success' : 'error'; ?>"
                     id="flash"
                     role="<?php echo $flash['type'] === 'success' ? 'status' : 'alert'; ?>">
                    <?php echo e($flash['message']); ?>
                </div>
            <?php endif; ?>

            <!-- ======================= INICIO DE SESIÓN ======================= -->
            <div class="panel" id="panel-login"<?php echo $view === 'register' ? ' hidden' : ''; ?>>
                <h1 class="panel__title">Bienvenido a Mew</h1>
                <p class="panel__subtitle">Introduce tus credenciales para acceder a tu cuenta.</p>

                <form class="form" id="login-form" action="login.php" method="post" autocomplete="on">
                    <input type="hidden" name="csrf_token" value="<?php echo e($csrf); ?>">

                    <div class="field">
                        <label for="login-username">Nombre de Usuario</label>
                        <input class="field__input" type="text" id="login-username" name="nombre_usuario"
                               value="<?php echo e($oldUsername); ?>"
                               placeholder="tu_usuario"
                               required autocomplete="username" maxlength="32"
                               aria-describedby="login-username-error">
                        <p class="field__error" id="login-username-error" role="alert"></p>
                    </div>

                    <div class="field">
                        <label for="login-password">Contraseña</label>
                        <div class="field__control">
                            <input class="field__input" type="password" id="login-password" name="contrasena"
                                   placeholder="••••••••"
                                   required autocomplete="current-password"
                                   aria-describedby="login-password-error">
                            <button class="pwd-toggle" type="button" data-target="login-password"
                                    aria-pressed="false" aria-label="Mostrar contraseña">Mostrar</button>
                        </div>
                        <p class="field__error" id="login-password-error" role="alert"></p>
                    </div>

                    <button class="btn btn--primary" type="submit">Iniciar sesión</button>

                    <p class="form__footer">
                        <a class="link" id="link-register" href="register.php">¿No tienes una cuenta? <strong>Regístrate</strong></a>
                    </p>
                </form>
            </div>

            <!-- ========================== REGISTRO =========================== -->
            <div class="panel" id="panel-register"<?php echo $view === 'register' ? '' : ' hidden'; ?>>
                <h1 class="panel__title">Crea tu cuenta</h1>
                <p class="panel__subtitle">Únete a Mew en un solo paso.</p>

                <form class="form" id="register-form" action="register.php" method="post" autocomplete="on">
                    <input type="hidden" name="csrf_token" value="<?php echo e($csrf); ?>">

                    <div class="field">
                        <label for="register-username">Nombre de Usuario</label>
                        <input class="field__input" type="text" id="register-username" name="nombre_usuario"
                               value="<?php echo e($oldUsername); ?>"
                               placeholder="tu_usuario"
                               required autocomplete="username" maxlength="32"
                               aria-describedby="register-username-error">
                        <p class="field__error" id="register-username-error" role="alert"></p>
                    </div>

                    <div class="field">
                        <label for="register-email">Correo electrónico</label>
                        <input class="field__input" type="email" id="register-email" name="correo"
                               value="<?php echo e($oldEmail); ?>"
                               placeholder="nombre@mew.cl"
                               required autocomplete="email" inputmode="email" maxlength="190"
                               aria-describedby="register-email-error">
                        <p class="field__error" id="register-email-error" role="alert"></p>
                    </div>

                    <div class="field">
                        <label for="register-password">Contraseña</label>
                        <div class="field__control">
                            <input class="field__input" type="password" id="register-password" name="contrasena"
                                   required autocomplete="new-password"
                                   aria-describedby="register-password-error register-rules">
                            <button class="pwd-toggle" type="button" data-target="register-password"
                                    aria-pressed="false" aria-label="Mostrar contraseña">Mostrar</button>
                        </div>
                        <p class="field__error" id="register-password-error" role="alert"></p>

                        <ul class="pwd-rules" id="register-rules" aria-label="Requisitos de la contraseña">
                            <li id="rule-len">Mínimo 6 caracteres</li>
                            <li id="rule-upper">Al menos una letra mayúscula</li>
                            <li id="rule-num">Al menos un número</li>
                            <li id="rule-sym">Al menos un símbolo (!, @, #, $ o %)</li>
                        </ul>
                    </div>

                    <div class="field">
                        <label for="register-confirm">Confirmar contraseña</label>
                        <div class="field__control">
                            <input class="field__input" type="password" id="register-confirm" name="confirmar_contrasena"
                                   required autocomplete="new-password"
                                   aria-describedby="register-confirm-error">
                            <button class="pwd-toggle" type="button" data-target="register-confirm"
                                    aria-pressed="false" aria-label="Mostrar contraseña">Mostrar</button>
                        </div>
                        <p class="field__error" id="register-confirm-error" role="alert"></p>
                    </div>

                    <button class="btn btn--primary" type="submit">Crear cuenta</button>

                    <p class="form__footer">
                        <a class="link" id="link-login" href="login.php">¿Ya tienes una cuenta? <strong>Inicia sesión</strong></a>
                    </p>
                </form>
            </div>
        </section>

        <p class="page__footer">© <?php echo date('Y'); ?> Mew</p>
    </main>
</body>
</html>
