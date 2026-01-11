# Configuración de Ambiente Local - Moodle Green Clonado

Este documento describe cómo clonar el ambiente Moodle 5.1 de Green a tu máquina local usando Docker, para poder desarrollar la aplicación de certificados localmente.

## 📋 Tabla de Contenidos

1. [Requisitos Previos](#requisitos-previos)
2. [Paso 1: Crear Backup de Green](#paso-1-crear-backup-de-green)
3. [Paso 2: Descargar Archivos de Moodle](#paso-2-descargar-archivos-de-moodle)
4. [Paso 3: Configurar Docker Local](#paso-3-configurar-docker-local)
5. [Paso 4: Restaurar Base de Datos](#paso-4-restaurar-base-de-datos)
6. [Paso 5: Configurar Moodle Local](#paso-5-configurar-moodle-local)
7. [Paso 6: Instalar Plugin SSO](#paso-6-instalar-plugin-sso)
8. [Paso 7: Verificar Instalación](#paso-7-verificar-instalación)

---

## Requisitos Previos

- ✅ Docker Desktop instalado y funcionando
- ✅ Al menos 10GB de espacio libre en disco
- ✅ Acceso SSH a Green (3.94.80.17)
- ✅ Clave SSH (`ClaveACG.pem`)
- ✅ Terminal con bash

---

## Paso 1: Crear Backup de Green

### 1.1 Conectar a Green vía SSH

```bash
# Conectar a Green
ssh -i ~/.ssh/ClaveACG.pem ec2-user@3.94.80.17
```

### 1.2 Crear backup de la base de datos

```bash
# En el servidor Green
cd ~

# Crear backup de la base de datos moodle51
mysqldump \
  -h acgdb.c9f1mlfzllkw.us-east-1.rds.amazonaws.com \
  -u moodle \
  -p \
  moodle51 \
  --single-transaction \
  --quick \
  --lock-tables=false \
  > moodle51_backup_$(date +%Y%m%d).sql

# Comprimir el backup
gzip moodle51_backup_$(date +%Y%m%d).sql

# Ver tamaño del backup
ls -lh moodle51_backup_*.sql.gz
```

> La contraseña de `moodle` es: `m00dl3!`

**Resultado esperado:**
```
moodle51_backup_20260109.sql.gz  (~50-100MB)
```

### 1.3 Crear backup de moodledata

```bash
# En el servidor Green
cd /home/ec2-user

# Crear backup de moodledata (solo archivos esenciales)
sudo tar -czf moodledata_backup_$(date +%Y%m%d).tar.gz \
  -C /home/datos/aulavirtual \
  --exclude='cache' \
  --exclude='localcache' \
  --exclude='sessions' \
  --exclude='temp' \
  --exclude='trashdir' \
  .

# Cambiar permisos para poder descargarlo
sudo chown ec2-user:ec2-user moodledata_backup_*.tar.gz

# Ver tamaño
ls -lh moodledata_backup_*.tar.gz
```

**Resultado esperado:**
```
moodledata_backup_20260109.tar.gz  (~500MB-2GB)
```

---

## Paso 2: Descargar Archivos de Moodle

### 2.1 Descargar backups desde Green

Abre una **nueva terminal** en tu Mac (no cierres la sesión SSH):

```bash
# Navegar al proyecto
cd /Users/ocastelblanco/Documents/ACG/Actualizacion2026/acg-gestor-certificados

# Crear directorio para backups
mkdir -p backups

# Descargar backup de BD
scp -i ~/.ssh/ClaveACG.pem \
  ec2-user@3.94.80.17:~/moodle51_backup_*.sql.gz \
  ./backups/

# Descargar backup de moodledata
scp -i ~/.ssh/ClaveACG.pem \
  ec2-user@3.94.80.17:~/moodledata_backup_*.tar.gz \
  ./backups/
```

### 2.2 Clonar archivos de Moodle

Vamos a clonar solo los archivos de Moodle (código PHP), no la data:

```bash
# Desde tu Mac, sincronizar archivos de Moodle
rsync -avz --progress \
  -e "ssh -i ~/.ssh/ClaveACG.pem" \
  --exclude='cache' \
  --exclude='.git' \
  ec2-user@3.94.80.17:/var/www/html/aulavirtual/ \
  ./moodle-files/
```

**Nota:** Esto puede tardar 5-10 minutos dependiendo de tu conexión.

---

## Paso 3: Configurar Docker Local

### 3.1 Verificar que Docker está corriendo

```bash
# Verificar Docker
docker --version
docker-compose --version
```

### 3.2 Preparar directorios locales

```bash
# Navegar al proyecto
cd /Users/ocastelblanco/Documents/ACG/Actualizacion2026/acg-gestor-certificados

# Crear directorio para moodledata
mkdir -p moodle-data

# Descomprimir moodledata
tar -xzf backups/moodledata_backup_*.tar.gz -C ./moodle-data/

# Establecer permisos (importante para que Apache pueda escribir)
chmod -R 777 ./moodle-data/
```

### 3.3 Levantar contenedores de Docker

```bash
# Levantar solo MariaDB primero
docker-compose up -d mariadb

# Esperar a que MariaDB esté listo (30 segundos)
sleep 30

# Verificar que MariaDB está corriendo
docker-compose ps mariadb
```

**Resultado esperado:**
```
NAME                    STATUS       PORTS
acg-certificados-db     Up           0.0.0.0:3307->3306/tcp
```

---

## Paso 4: Restaurar Base de Datos

### 4.1 Descomprimir backup de BD

```bash
# Descomprimir backup
gunzip backups/moodle51_backup_*.sql.gz
```

### 4.2 Crear base de datos para Moodle

```bash
# Conectar a MariaDB y crear base de datos
docker-compose exec mariadb mysql -u root -proot_password_dev -e "
CREATE DATABASE IF NOT EXISTS moodle_dev CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
GRANT ALL PRIVILEGES ON moodle_dev.* TO 'moodle_user'@'%' IDENTIFIED BY 'moodle_password_dev';
GRANT ALL PRIVILEGES ON moodle_dev.* TO 'certificates_app'@'%';
FLUSH PRIVILEGES;
"
```

### 4.3 Restaurar backup en base de datos local

```bash
# Restaurar backup (esto puede tardar 5-15 minutos)
docker-compose exec -T mariadb mysql \
  -u moodle_user \
  -pmoodle_password_dev \
  moodle_dev \
  < backups/moodle51_backup_*.sql

# Verificar que se restauró correctamente
docker-compose exec mariadb mysql \
  -u moodle_user \
  -pmoodle_password_dev \
  -e "USE moodle_dev; SHOW TABLES; SELECT COUNT(*) as total_tables FROM information_schema.tables WHERE table_schema='moodle_dev';"
```

**Resultado esperado:**
```
total_tables
-----------
400+
```

---

## Paso 5: Configurar Moodle Local

### 5.1 Actualizar config.php de Moodle

```bash
# Editar config.php
vim moodle-files/config.php
```

Actualizar las siguientes líneas:

```php
<?php
unset($CFG);
global $CFG;
$CFG = new stdClass();

// ============================================================================
// DATABASE CONFIGURATION - Docker Local
// ============================================================================
$CFG->dbtype    = 'mariadb';
$CFG->dblibrary = 'native';
$CFG->dbhost    = 'mariadb';  // Nombre del servicio Docker
$CFG->dbname    = 'moodle_dev';
$CFG->dbuser    = 'moodle_user';
$CFG->dbpass    = 'moodle_password_dev';
$CFG->prefix    = 'mdl_';
$CFG->dboptions = array(
    'dbpersist' => false,
    'dbsocket'  => false,
    'dbport'    => '3306',
    'dbcollation' => 'utf8mb4_unicode_ci',
);

// ============================================================================
// WEB CONFIGURATION - Local
// ============================================================================
$CFG->wwwroot   = 'http://localhost:8082';  // Puerto para Moodle local

// ============================================================================
// DATA DIRECTORY
// ============================================================================
$CFG->dataroot  = '/var/www/moodledata';

// ============================================================================
// ADMIN DIRECTORY
// ============================================================================
$CFG->admin     = 'admin';

// ============================================================================
// DIRECTORIES
// ============================================================================
$CFG->dirroot   = '/var/www/html';
$CFG->libdir    = $CFG->dirroot . '/lib';

// ============================================================================
// DEBUG MODE (Development)
// ============================================================================
$CFG->debug = E_ALL;
$CFG->debugdisplay = 1;
@error_reporting(E_ALL);
@ini_set('display_errors', '1');

// ============================================================================
// PERFORMANCE
// ============================================================================
$CFG->cachedir = '/var/www/moodledata/cache';
$CFG->localcachedir = '/var/www/moodledata/localcache';

require_once(__DIR__ . '/lib/setup.php');

// There is no php closing tag in this file,
// it is intentional because it prevents trailing whitespace problems!
```

### 5.2 Actualizar docker-compose.yml para Moodle

Necesitamos agregar un servicio para Moodle en el docker-compose:

```bash
# Editar docker-compose.yml
vim docker-compose.yml
```

Agregar después del servicio `php`:

```yaml
  # ============================================================
  # Moodle 5.1 (Clone de Green)
  # ============================================================
  moodle:
    build:
      context: ./docker/php
      dockerfile: Dockerfile
    container_name: acg-moodle-local
    ports:
      - "8082:80"  # Moodle accesible en http://localhost:8082
    volumes:
      - ./moodle-files:/var/www/html:cached
      - ./moodle-data:/var/www/moodledata:cached
      - ./docker/php/php.ini:/usr/local/etc/php/conf.d/custom.ini:ro
      - ./docker/logs/moodle:/var/log/apache2
    environment:
      - APACHE_DOCUMENT_ROOT=/var/www/html/public
      - PHP_DISPLAY_ERRORS=On
      - PHP_ERROR_REPORTING=E_ALL
    networks:
      - acg-network
    depends_on:
      - mariadb
    restart: unless-stopped
```

### 5.3 Levantar servicio de Moodle

```bash
# Levantar todos los servicios
docker-compose up -d

# Verificar que todos los servicios están corriendo
docker-compose ps
```

**Resultado esperado:**
```
NAME                      STATUS       PORTS
acg-certificados-php      Up           0.0.0.0:8080->80/tcp
acg-certificados-db       Up           0.0.0.0:3307->3306/tcp
acg-certificados-phpmyadmin Up         0.0.0.0:8081->80/tcp
acg-moodle-local          Up           0.0.0.0:8082->80/tcp
```

### 5.4 Verificar acceso a Moodle

```bash
# Abrir navegador en:
open http://localhost:8082
```

**Credenciales:**
- Usuario: `adminav`
- Contraseña: `4dm1n1str4d0rM00dl3!`

---

## Paso 6: Instalar Plugin SSO

### 6.1 Copiar plugin a Moodle local

```bash
# Copiar plugin al directorio local de Moodle
cp -r moodle-plugin/ moodle-files/public/local/certificados_sso

# Verificar que se copió correctamente
ls -la moodle-files/public/local/certificados_sso/
```

### 6.2 Instalar desde interfaz de Moodle

1. Abrir navegador: `http://localhost:8082`
2. Iniciar sesión como `adminav`
3. Ir a: **Administración del sitio → Notificaciones**
4. Hacer clic en: **"Actualizar base de datos de Moodle ahora"**
5. Seguir el asistente de instalación del plugin

### 6.3 Configurar plugin (seguir manual MANUAL-CONFIGURACION-PLUGIN.md)

Seguir los pasos del manual [MANUAL-CONFIGURACION-PLUGIN.md](MANUAL-CONFIGURACION-PLUGIN.md) desde el **Paso 1** en adelante:

- ✅ Habilitar Web Services
- ✅ Configurar servicio web "ACG Certificados SSO"
- ✅ Crear token permanente
- ✅ Configurar URLs del plugin

---

## Paso 7: Verificar Instalación

### 7.1 Checklist de verificación

- [ ] Docker contenedores corriendo (4 servicios)
- [ ] MariaDB accesible en puerto 3307
- [ ] phpMyAdmin accesible en `http://localhost:8081`
- [ ] Backend accesible en `http://localhost:8080`
- [ ] Moodle accesible en `http://localhost:8082`
- [ ] Login en Moodle funciona con `adminav`
- [ ] Base de datos restaurada (400+ tablas)
- [ ] Plugin SSO instalado y habilitado
- [ ] Enlace "Mis Certificados" aparece en navegación

### 7.2 Comandos útiles

```bash
# Ver logs de Moodle
docker-compose logs -f moodle

# Ver logs del backend
docker-compose logs -f php

# Ver logs de MariaDB
docker-compose logs -f mariadb

# Reiniciar todos los servicios
docker-compose restart

# Detener todos los servicios
docker-compose down

# Eliminar todo y empezar de cero (⚠️ CUIDADO)
docker-compose down -v
```

### 7.3 Acceso a los servicios

| Servicio | URL | Credenciales |
|----------|-----|--------------|
| **Moodle Local** | http://localhost:8082 | adminav / 4dm1n1str4d0rM00dl3! |
| **Backend API** | http://localhost:8080 | N/A |
| **phpMyAdmin** | http://localhost:8081 | root / root_password_dev |
| **MariaDB** | localhost:3307 | moodle_user / moodle_password_dev |

---

## Troubleshooting

### Problema: "Can't connect to database"

**Solución:**
```bash
# Verificar que MariaDB está corriendo
docker-compose ps mariadb

# Ver logs de MariaDB
docker-compose logs mariadb

# Reiniciar MariaDB
docker-compose restart mariadb
```

### Problema: "Permission denied" en moodledata

**Solución:**
```bash
# Dar permisos completos
chmod -R 777 ./moodle-data/

# O desde dentro del contenedor
docker-compose exec moodle chown -R www-data:www-data /var/www/moodledata
```

### Problema: Moodle muestra página en blanco

**Solución:**
```bash
# Ver logs de PHP
docker-compose logs moodle

# Verificar config.php
cat moodle-files/config.php | grep dbhost

# Limpiar cachés
docker-compose exec moodle php admin/cli/purge_caches.php
```

### Problema: "Table doesn't exist"

**Solución:**
```bash
# La restauración de BD no terminó correctamente
# Reintentar restauración:
docker-compose exec -T mariadb mysql -u moodle_user -pmoodle_password_dev moodle_dev < backups/moodle51_backup_*.sql
```

---

## Estructura Final de Directorios

```
acg-gestor-certificados/
├── backend/                 # Backend PHP de certificados
├── frontend/                # Frontend Angular
├── moodle-plugin/           # Plugin SSO (código fuente)
├── moodle-files/            # Archivos de Moodle clonados de Green
│   ├── admin/
│   ├── local/
│   │   └── certificados_sso/  # Plugin instalado
│   ├── config.php           # Configurado para Docker
│   └── ...
├── moodle-data/             # Moodledata clonado de Green
│   ├── filedir/
│   ├── cache/
│   └── ...
├── backups/                 # Backups de Green
│   ├── moodle51_backup_YYYYMMDD.sql
│   └── moodledata_backup_YYYYMMDD.tar.gz
├── docker/
│   ├── php/
│   └── mariadb/
├── docker-compose.yml       # Configuración Docker actualizada
└── SETUP-LOCAL-MOODLE.md    # Este documento
```

---

## Próximos Pasos

Una vez completada la instalación:

1. ✅ **Desarrollar backend** de certificados en `./backend/`
2. ✅ **Desarrollar frontend** en `./frontend/`
3. ✅ **Probar integración** SSO entre Moodle local y aplicación
4. ✅ **Migrar certificados** legacy (1,490 registros)
5. ✅ **Testing completo** en ambiente local
6. ✅ **Desplegar a Green** cuando esté listo

---

## Limpieza y Backups

### Hacer backup del ambiente local

```bash
# Crear backup de la BD local
docker-compose exec mariadb mysqldump -u moodle_user -pmoodle_password_dev moodle_dev | gzip > backups/local_backup_$(date +%Y%m%d).sql.gz
```

### Limpiar ambiente local

```bash
# Detener y eliminar contenedores
docker-compose down

# Eliminar volúmenes (⚠️ esto elimina la BD)
docker-compose down -v

# Limpiar archivos descargados
rm -rf moodle-files/
rm -rf moodle-data/
rm -rf backups/*.sql backups/*.tar.gz
```

---

## Notas Importantes

- ⚠️ **No modificar** archivos en `moodle-files/` directamente desde Green. Todos los cambios se hacen localmente y luego se despliegan.
- ⚠️ Los puertos utilizados son:
  - `8080`: Backend API
  - `8081`: phpMyAdmin
  - `8082`: Moodle
  - `3307`: MariaDB
- ⚠️ El ambiente local usa bases de datos separadas de Green (seguro para desarrollo)
- ⚠️ Credenciales de desarrollo son diferentes a las de producción

---

*Última actualización: 2026-01-09*
*Ambiente: Local Development*
