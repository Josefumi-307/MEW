<?php
/**
 * Conexión a la base de datos (MySQL/MariaDB mediante PDO + pdo_mysql).
 *
 * Este archivo vive fuera de la vista pública de la aplicación y jamás
 * imprime credenciales en pantalla: los detalles técnicos se escriben en
 * el log de errores de PHP (error_log) y al usuario final solo se le
 * muestra un mensaje genérico y accionable.
 *
 * Configuración:
 *   1) Edite las variables de la función db_settings() de este archivo, o
 *   2) Cree config/database.local.php (excluido de Git) para sobrescribirlas
 *      sin tocar este fichero. Ejemplo de contenido:
 *
 *      <?php
 *      return array(
 *          'host' => 'localhost',
 *          'name' => 'mew_db',
 *          'user' => 'mew_app',
 *          'pass' => 'su-contraseña',
 *      );
 */

if (!defined('MEW_APP')) {
    http_response_code(404);
    exit;
}

/**
 * Variables de configuración de la conexión.
 *
 * Por defecto se usan los valores típicos de una instalación local de
 * XAMPP (usuario "root" sin contraseña). En producción jamás utilice
 * estos valores: cree un usuario dedicado con permisos mínimos.
 *
 * @return array{host: string, name: string, user: string, pass: string}
 */
function db_settings()
{
    $settings = array(
        'host' => 'localhost',
        'name' => 'mew_db',
        'user' => 'root',
        'pass' => '',
    );

    $localFile = __DIR__ . '/database.local.php';
    if (is_file($localFile)) {
        // Se incluye dentro de un búfer: si el archivo tiene BOM o produce
        // cualquier salida, esta se descarta y no rompe las cabeceras HTTP.
        ob_start();
        try {
            $local = require $localFile;
        } catch (Throwable $e) {
            error_log('[Mew] Archivo config/database.local.php inválido: ' . $e->getMessage());
            $local = null;
        }
        ob_end_clean();

        if (is_array($local)) {
            $settings = array_merge($settings, $local);
        }
    }

    return $settings;
}

/**
 * Devuelve una conexión PDO única (patrón singleton).
 *
 * @throws RuntimeException con un mensaje seguro para el usuario final.
 */
function db()
{
    static $pdo = null;

    if ($pdo instanceof PDO) {
        return $pdo;
    }

    if (!extension_loaded('pdo_mysql')) {
        throw new RuntimeException(
            'Falta la extensión PHP "pdo_mysql". Actívela en php.ini y reinicie Apache.'
        );
    }

    $config = db_settings();
    $dsn = 'mysql:host=' . $config['host'] . ';dbname=' . $config['name'] . ';charset=utf8mb4';

    try {
        $pdo = new PDO($dsn, $config['user'], $config['pass'], array(
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false, // consultas preparadas reales
        ));
    } catch (PDOException $e) {
        // El detalle completo (que puede contener el usuario de MySQL) solo
        // se guarda en el log del servidor, nunca se muestra al visitante.
        error_log('[Mew] Error de conexión PDO: ' . $e->getMessage());
        throw new RuntimeException(db_connection_message($e), 0, $e);
    }

    return $pdo;
}

/**
 * Traduce una excepción de conexión en un mensaje sin información sensible.
 *
 * @param PDOException $e
 * @return string
 */
function db_connection_message(PDOException $e)
{
    $sqlState = (string) $e->getCode();
    $driverCode = isset($e->errorInfo[0]) ? (string) $e->errorInfo[0] : '';
    $code = ($driverCode !== '' && $driverCode !== '00000') ? $driverCode : $sqlState;

    switch ($code) {
        case '1049': // base de datos desconocida
            return 'La base de datos no existe. Importe el archivo database.sql desde phpMyAdmin.';

        case '1045': // acceso denegado
            return 'Credenciales de MySQL incorrectas. Revise usuario y contraseña en config/database.php.';

        case '2002': // no se puede conectar al servidor
        case '2006': // el servidor se desconectó
            return 'No se puede conectar con MySQL. Compruebe que MySQL esté iniciado en el panel de XAMPP.';

        case 'HY000':
            return 'No se puede conectar con la base de datos. Consulte el log de errores de PHP para más detalles.';

        default:
            return 'Error al conectar con la base de datos. Consulte el log de errores de PHP para más detalles.';
    }
}
