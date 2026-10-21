-- =====================================================================
--  Mew - Base de datos
--  Importar desde phpMyAdmin (http://localhost/phpmyadmin/) en la pestaña
--  "Importar", o desde la consola:
--      mysql -u root -p < database.sql
-- =====================================================================

CREATE DATABASE IF NOT EXISTS `mew_db`
    DEFAULT CHARACTER SET utf8mb4
    DEFAULT COLLATE utf8mb4_unicode_ci;

USE `mew_db`;

-- Cuentas de usuario. La contraseña se guarda siempre como hash (password_hash).
-- nombre_usuario: con lo que se identifica el usuario para iniciar sesión.
CREATE TABLE IF NOT EXISTS `usuarios` (
    `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
    `nombre_usuario` VARCHAR(50)  NOT NULL,
    `correo`         VARCHAR(190) NOT NULL,
    `password_hash`  VARCHAR(255) NOT NULL,
    `fecha_creacion` TIMESTAMP    NOT NULL DEFAULT CURRENT_TIMESTAMP,
    PRIMARY KEY (`id`),
    UNIQUE KEY `uq_usuarios_nombre` (`nombre_usuario`),
    UNIQUE KEY `uq_usuarios_correo` (`correo`)
) ENGINE=InnoDB
  DEFAULT CHARACTER SET utf8mb4
  DEFAULT COLLATE utf8mb4_unicode_ci;
