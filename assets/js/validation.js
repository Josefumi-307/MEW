/* =====================================================================
   Mew — validación de formularios e interacciones de la interfaz
   (sin dependencias; las reglas coinciden con includes/auth.php)
   ===================================================================== */

(function () {
    'use strict';

    var MAX_EMAIL = 190;
    var EMAIL_RE = /^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$/;

    /* Dominio propio de la empresa: idéntico a MEW_EMAIL_DOMAIN en PHP. */
    var EMAIL_DOMAIN = 'mew.cl';
    var EMAIL_DOMAIN_ERROR = 'El correo electrónico debe pertenecer a la empresa (@' + EMAIL_DOMAIN + ').';

    /* Nombre de usuario: idéntico a is_valid_username() en PHP. */
    var USERNAME_RE = /^[A-Za-z0-9._-]{3,32}$/;
    var USERNAME_ERROR = 'El nombre de usuario debe tener entre 3 y 32 caracteres y solo puede contener letras, números, puntos, guiones o guion bajo.';

    /* Reglas de contraseña: idénticas a password_rule_errors() en PHP. */
    var RULES = [
        { id: 'rule-len',   test: function (p) { return p.length >= 6 && p.length <= 72; } },
        { id: 'rule-upper', test: function (p) { return /[A-ZÁÉÍÓÚÜÑ]/.test(p); } },
        { id: 'rule-num',   test: function (p) { return /[0-9]/.test(p); } },
        { id: 'rule-sym',   test: function (p) { return /[^A-Za-z0-9áéíóúüñÁÉÍÓÚÜÑ]/.test(p); } }
    ];

    function $(id) { return document.getElementById(id); }

    /* ------------------------- Mensajes de error --------------------- */

    function setError(input, message) {
        if (!input) { return; }
        var box = $(input.id + '-error');
        if (message) {
            input.setAttribute('aria-invalid', 'true');
            input.classList.remove('is-valid');
            if (box) { box.textContent = message; }
        } else {
            input.removeAttribute('aria-invalid');
            if (box) { box.textContent = ''; }
        }
    }

    function validateUsername(input, emptyMessage) {
        var value = (input.value || '').trim();
        if (!value) {
            setError(input, emptyMessage);
            return false;
        }
        if (!USERNAME_RE.test(value)) {
            setError(input, USERNAME_ERROR);
            return false;
        }
        setError(input, '');
        return true;
    }

    function validateEmail(input, emptyMessage) {
        var value = (input.value || '').trim();
        if (!value) {
            setError(input, emptyMessage);
            return false;
        }
        if (value.length > MAX_EMAIL || !EMAIL_RE.test(value)) {
            setError(input, 'Introduzca un correo electrónico válido.');
            return false;
        }
        var at = value.lastIndexOf('@');
        if (at === -1 || value.slice(at + 1).toLowerCase() !== EMAIL_DOMAIN) {
            setError(input, EMAIL_DOMAIN_ERROR);
            return false;
        }
        setError(input, '');
        return true;
    }

    function validateFilled(input, message) {
        if (!input.value) {
            setError(input, message);
            return false;
        }
        setError(input, '');
        return true;
    }

    function passwordProblems(value) {
        var missing = 0;
        for (var i = 0; i < RULES.length; i++) {
            if (!RULES[i].test(value)) { missing++; }
        }
        return missing;
    }

    function validatePasswordRules(input, emptyMessage) {
        var value = input.value;
        if (!value) {
            setError(input, emptyMessage);
            return false;
        }
        if (passwordProblems(value) > 0) {
            setError(input, 'La contraseña no cumple los requisitos indicados.');
            return false;
        }
        setError(input, '');
        return true;
    }

    function validateConfirm(passInput, confirmInput) {
        if (!confirmInput.value) {
            setError(confirmInput, 'Repita la contraseña.');
            return false;
        }
        if (confirmInput.value !== passInput.value) {
            setError(confirmInput, 'Las contraseñas no coinciden');
            return false;
        }
        setError(confirmInput, '');
        confirmInput.classList.add('is-valid');
        return true;
    }

    function focusFirstInvalid(inputs) {
        for (var i = 0; i < inputs.length; i++) {
            if (inputs[i] && inputs[i].getAttribute('aria-invalid') === 'true') {
                inputs[i].focus();
                return;
            }
        }
    }

    /* --------------------- Requisitos (en vivo) ---------------------- */

    function updateRules() {
        var input = $('register-password');
        if (!input) { return; }
        var value = input.value;
        for (var i = 0; i < RULES.length; i++) {
            var item = $(RULES[i].id);
            if (!item) { continue; }
            var ok = value.length > 0 && RULES[i].test(value);
            if (ok) { item.classList.add('is-valid'); }
            else { item.classList.remove('is-valid'); }
        }
    }

    /* ------------------- Mostrar / ocultar contraseña ---------------- */

    function initPasswordToggles() {
        var toggles = document.querySelectorAll('.pwd-toggle');
        Array.prototype.forEach.call(toggles, function (button) {
            button.addEventListener('click', function () {
                var input = $(button.getAttribute('data-target'));
                if (!input) { return; }
                var show = input.type === 'password';
                input.type = show ? 'text' : 'password';
                button.textContent = show ? 'Ocultar' : 'Mostrar';
                button.setAttribute('aria-pressed', show ? 'true' : 'false');
                button.setAttribute('aria-label', (show ? 'Ocultar' : 'Mostrar') + ' contraseña');
                input.focus();
            });
        });
    }

    /* -------------- Alternancia de formularios (sin recarga) --------- */

    function initPanelSwitch() {
        var loginPanel = $('panel-login');
        var registerPanel = $('panel-register');
        var linkRegister = $('link-register');
        var linkLogin = $('link-login');
        var flash = $('flash');

        if (!loginPanel || !registerPanel) { return; }

        function currentView() {
            return registerPanel.hasAttribute('hidden') ? 'login' : 'register';
        }

        function viewFromLocation() {
            if (/register\.php$/i.test(location.pathname)) { return 'register'; }
            return /[?&]form=register(&|$)/.test(location.search) ? 'register' : 'login';
        }

        function showView(view, options) {
            options = options || {};
            var toRegister = view === 'register';
            var visible = toRegister ? registerPanel : loginPanel;
            var hidden = toRegister ? loginPanel : registerPanel;

            hidden.setAttribute('hidden', '');
            hidden.setAttribute('aria-hidden', 'true');
            visible.removeAttribute('hidden');
            visible.removeAttribute('aria-hidden');

            document.title = toRegister ? 'Mew — Crear cuenta' : 'Mew — Iniciar sesión';

            if (options.clearFlash && flash) {
                flash.setAttribute('hidden', '');
            }
            if (options.push) {
                try {
                    history.pushState({ view: view }, '', toRegister ? 'register.php' : 'index.php');
                } catch (err) { /* navegación no soportada: se ignora */ }
            }
            if (options.focus) {
                var first = visible.querySelector('input:not([type="hidden"]), button, a');
                if (first) { first.focus(); }
            }
        }

        if (linkRegister) {
            linkRegister.addEventListener('click', function (event) {
                event.preventDefault();
                if (currentView() !== 'register') {
                    showView('register', { push: true, focus: true, clearFlash: true });
                }
            });
        }

        if (linkLogin) {
            linkLogin.addEventListener('click', function (event) {
                event.preventDefault();
                if (currentView() !== 'login') {
                    showView('login', { push: true, focus: true, clearFlash: true });
                }
            });
        }

        window.addEventListener('popstate', function (event) {
            var view = (event.state && event.state.view) ? event.state.view : viewFromLocation();
            showView(view, {});
        });
    }

    /* --------------------------- Formularios ------------------------- */

    function initForms() {
        /* --- Inicio de sesión --- */
        var loginForm = $('login-form');
        if (loginForm) {
            var loginUsername = $('login-username');
            var loginPassword = $('login-password');

            loginForm.noValidate = true; // validación propia con mensajes propios

            loginUsername.addEventListener('blur', function () {
                validateUsername(loginUsername, 'Introduzca su nombre de usuario.');
            });
            loginUsername.addEventListener('input', function () {
                if (loginUsername.getAttribute('aria-invalid') === 'true') {
                    validateUsername(loginUsername, 'Introduzca su nombre de usuario.');
                }
            });
            loginPassword.addEventListener('blur', function () {
                validateFilled(loginPassword, 'Introduzca su contraseña.');
            });
            loginPassword.addEventListener('input', function () {
                if (loginPassword.getAttribute('aria-invalid') === 'true' && loginPassword.value) {
                    setError(loginPassword, '');
                }
            });

            loginForm.addEventListener('submit', function (event) {
                var okUser = validateUsername(loginUsername, 'Introduzca su nombre de usuario.');
                var okPass = validateFilled(loginPassword, 'Introduzca su contraseña.');
                if (!okUser || !okPass) {
                    event.preventDefault();
                    focusFirstInvalid([loginUsername, loginPassword]);
                }
            });
        }

        /* --- Registro --- */
        var registerForm = $('register-form');
        if (registerForm) {
            var regUsername = $('register-username');
            var regEmail = $('register-email');
            var regPassword = $('register-password');
            var regConfirm = $('register-confirm');

            registerForm.noValidate = true;

            regUsername.addEventListener('blur', function () {
                validateUsername(regUsername, 'Introduzca su nombre de usuario.');
            });
            regUsername.addEventListener('input', function () {
                if (regUsername.getAttribute('aria-invalid') === 'true') {
                    validateUsername(regUsername, 'Introduzca su nombre de usuario.');
                }
            });

            regEmail.addEventListener('blur', function () {
                validateEmail(regEmail, 'Introduzca su correo electrónico.');
            });
            regEmail.addEventListener('input', function () {
                if (regEmail.getAttribute('aria-invalid') === 'true') {
                    validateEmail(regEmail, 'Introduzca su correo electrónico.');
                }
            });

            // Los requisitos se actualizan mientras el usuario escribe.
            regPassword.addEventListener('input', function () {
                updateRules();
                setError(regPassword, '');
                regConfirm.classList.remove('is-valid');
                if (regConfirm.value) {
                    validateConfirm(regPassword, regConfirm);
                }
            });
            regPassword.addEventListener('blur', function () {
                if (regPassword.value) {
                    validatePasswordRules(regPassword, 'Introduzca su contraseña.');
                }
            });

            // Coincidencia exacta de la confirmación (en vivo).
            regConfirm.addEventListener('input', function () {
                if (regConfirm.value) {
                    validateConfirm(regPassword, regConfirm);
                } else {
                    setError(regConfirm, '');
                    regConfirm.classList.remove('is-valid');
                }
            });
            regConfirm.addEventListener('blur', function () {
                if (regConfirm.value || regPassword.value) {
                    validateConfirm(regPassword, regConfirm);
                }
            });

            registerForm.addEventListener('submit', function (event) {
                var okUser = validateUsername(regUsername, 'Introduzca su nombre de usuario.');
                var okEmail = validateEmail(regEmail, 'Introduzca su correo electrónico.');
                var okPass = validatePasswordRules(regPassword, 'Introduzca su contraseña.');
                var okConfirm = validateConfirm(regPassword, regConfirm);
                if (!okUser || !okEmail || !okPass || !okConfirm) {
                    event.preventDefault();
                    focusFirstInvalid([regUsername, regEmail, regPassword, regConfirm]);
                }
            });
        }
    }

    /* ----------------------------- Arranque -------------------------- */

    function init() {
        initPasswordToggles();
        initPanelSwitch();
        initForms();
        updateRules();
    }

    if (document.readyState === 'loading') {
        document.addEventListener('DOMContentLoaded', init);
    } else {
        init();
    }
}());
