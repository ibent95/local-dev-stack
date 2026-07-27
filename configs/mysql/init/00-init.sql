-- Bootstrap the default app database + user.
-- Runs every time mysqld starts (--init-file). Idempotent via IF NOT EXISTS.
-- Created by the LDS mysql service in docker-compose.yml.
CREATE DATABASE IF NOT EXISTS `app`;
CREATE USER IF NOT EXISTS 'app'@'%' IDENTIFIED BY 'app';
ALTER USER 'app'@'%' IDENTIFIED BY 'app';
GRANT ALL PRIVILEGES ON `app`.* TO 'app'@'%';
FLUSH PRIVILEGES;
