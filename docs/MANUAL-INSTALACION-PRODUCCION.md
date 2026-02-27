# Manual de Instalación - Sistema de Gestión de Certificados ACG
## Despliegue en Producción (Green - AWS)

**Versión:** 1.0
**Fecha:** 2026-01-13
**Destinatarios:** Desarrollador humano y Claude Code
**Entorno:** EC2 Green (t4g.medium) + RDS MariaDB 10.11.15

---

## 📋 Información del Servidor de Producción

### Servidor Green (AWS EC2)

| Parámetro | Valor |
|-----------|-------|
| **Instancia** | i-000dcbbd4f40af84c (t4g.medium ARM) |
| **IP Pública** | Variable (se asigna al iniciar) |
| **Sistema Operativo** | Amazon Linux 2023 |
| **Apache** | 2.4.65 |
| **PHP** | 8.4.14 |
| **Moodle** | 5.1 (Build: 20251006) |
| **Document Root Moodle** | `/var/www/html/public` |
| **Document Root Backend** | `/var/www/html/certificados` (a crear) |

### Base de Datos (AWS RDS)

| Parámetro | Valor |
|-----------|-------|
| **Instancia** | acgdb |
| **Engine** | MariaDB 10.11.15 |
| **Endpoint** | `acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com` |
| **Puerto** | 3306 |
| **Bases de Datos** | `moodle` (Blue) / `moodle51` (Green) |
| **Usuario** | `root` |
| **Password** | `cl4v3dbr00t!` |

**⚠️ Arquitectura Importante:**

Existe una **única instancia RDS** compartida entre Blue y Green con dos bases de datos:
- `moodle` - Base de datos de producción Blue (Moodle 4.x)
- `moodle51` - Base de datos de producción Green (Moodle 5.1)

**Implicaciones:**
- Las credenciales de acceso (`root` / `cl4v3dbr00t!`) son las mismas para ambas bases de datos
- Cualquier operación en la instancia RDS puede afectar ambos ambientes
- **PRECAUCIÓN:** Al ejecutar scripts de migración, asegurarse de conectar a la base de datos correcta (`moodle51` para Green)

### Credenciales

**⚠️ IMPORTANTE:** Las credenciales de base de datos son compartidas entre ambos ambientes.

**Producción (Green):**
- **Usuario BD:** `root`
- **Password BD:** `cl4v3dbr00t!`
- **Base de Datos:** `moodle51`
- **Endpoint:** `acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com`
- **Moodle Token:** (obtener del plugin instalado en Green)

---

## 🔄 Proceso de Instalación

### Fase 1: Pre-requisitos y Verificación

#### 1.1 Acceso SSH al Servidor Green

```bash
# IP Elástica de Green — fija, no cambia nunca
GREEN_IP="52.7.23.191"

# Conectar vía SSH
ssh -i ~/.ssh/ClaveACG.pem ec2-user@${GREEN_IP}
```

**Estado:** ⏳ Pendiente

---

#### 1.2 Verificar Versiones de Software

```bash
# Una vez conectado a Green, verificar:

# Apache
apache2 -v
# Esperado: Server version: Apache/2.4.65

# PHP
php -v
# Esperado: PHP 8.4.14

# PHP Extensions necesarias
php -m | grep -E "pdo|mysqli|mbstring|curl|json|zip"
# Esperado: Todas presentes

# Composer (si no está instalado, instalarlo)
composer --version
# Si no existe: instalar desde https://getcomposer.org/installer
```

**Estado:** ⏳ Pendiente

---

#### 1.3 Verificar Estructura de Directorios

```bash
# Verificar que existe el directorio de Moodle
ls -la /var/www/html/

# Verificar Document Root
grep DocumentRoot /etc/httpd/conf/httpd.conf

# Debe mostrar:
# DocumentRoot "/var/www/html/public"
```

**Estado:** ⏳ Pendiente

---

### Fase 2: Backup de Datos Legacy

#### 2.1 Conectar a RDS y Crear Backup

```bash
# Desde tu máquina local (NO desde Green)

# Variables
export DB_HOST="acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com"
export DB_USER="root"
export DB_NAME="moodle51"

# Password de producción
export DB_PASS="cl4v3dbr00t!"

# Crear backup de tabla cc_certificados
mysqldump -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME cc_certificados \
  > backups/cc_certificados_production_$(date +%Y%m%d_%H%M%S).sql

# Verificar que se creó correctamente
ls -lh backups/cc_certificados_production_*.sql

# Comprimir backup
gzip backups/cc_certificados_production_*.sql
```

**Verificación:**
- ✅ Archivo de backup creado
- ✅ Tamaño del archivo > 0 KB
- ✅ Archivo comprimido con gzip

**Estado:** ⏳ Pendiente

---

#### 2.2 Subir Backup a S3 (Opcional pero Recomendado)

```bash
# Subir a S3 para mayor seguridad
export AWS_PROFILE=acg

aws s3 cp backups/cc_certificados_production_*.sql.gz \
  s3://acg-backups/certificados/$(date +%Y%m%d)/ \
  --storage-class STANDARD_IA

# Verificar que se subió
aws s3 ls s3://acg-backups/certificados/$(date +%Y%m%d)/
```

**Estado:** ⏳ Pendiente

---

### Fase 3: Migración de Base de Datos

#### 3.1 Renombrar Tabla Legacy

```bash
# Conectar a RDS (desde local o desde Green)
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME

# Una vez dentro de MySQL:
```

```sql
-- Renombrar tabla existente
ALTER TABLE cc_certificados RENAME TO cc_certificados_legacy;

-- Verificar
SHOW TABLES LIKE 'cc_certificados%';

-- Debe mostrar:
-- cc_certificados_legacy

-- Contar registros
SELECT COUNT(*) as total FROM cc_certificados_legacy;

-- Salir
EXIT;
```

**Verificación:**
- ✅ Tabla renombrada exitosamente
- ✅ Cantidad de registros coincide con lo esperado (~1,490)

**Estado:** ⏳ Pendiente

---

#### 3.2 Ejecutar Script de Creación de Tablas

```bash
# Desde tu máquina local, ubicarse en el proyecto
cd /path/to/acg-gestor-certificados

# Ejecutar script de migración 001
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
  < backend/scripts/migrations/001_create_tables.sql

# Verificar que las tablas se crearon
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
  -e "SHOW TABLES LIKE 'cc_%';"
```

**Salida esperada:**
```
cc_certificados
cc_certificados_legacy
cc_configuracion
cc_descargas_log
cc_generaciones_log
cc_notificaciones_log
cc_plantillas
cc_plantillas_campos
cc_validaciones_log
```

**Verificación:**
- ✅ 9 tablas creadas (incluyendo legacy y plantillas_campos)
- ✅ Sin errores de Foreign Keys

**Estado:** ⏳ Pendiente

---

#### 3.3 Ejecutar Script de Migración de Datos

```bash
# Ejecutar script de migración 002
mysql -h $DB_HOST -u $DB_USER -p$DB_PASS $DB_NAME \
  < backend/scripts/migrations/002_migrate_legacy_data.sql
```

**Salida esperada:**
```
+--------------------------------------------------------+-----------+
| descripcion                                            | cantidad  |
+--------------------------------------------------------+-----------+
| Registros en legacy                                    | ~1490     |
| Registros migrados                                     | ~1409     |
| Registros NO migrados (usuario eliminado o curso inv) | ~81       |
+--------------------------------------------------------+-----------+
```

**Verificación:**
- ✅ Mayoría de registros migrados
- ✅ Campo `migrated_from_legacy` = TRUE
- ✅ Campo `legacy_id` contiene ID original

```sql
-- Verificar migración
SELECT
    COUNT(*) as total_migrados,
    COUNT(DISTINCT userid) as usuarios_unicos,
    COUNT(DISTINCT courseid) as cursos_unicos
FROM cc_certificados
WHERE migrated_from_legacy = TRUE;
```

**Estado:** ⏳ Pendiente

---

### Fase 4: Preparar Backend en Servidor

#### 4.1 Crear Estructura de Directorios

```bash
# Conectado a Green vía SSH

# Crear directorio principal para el backend
sudo mkdir -p /var/www/html/certificados
sudo chown ec2-user:apache /var/www/html/certificados
cd /var/www/html/certificados

# Crear estructura de directorios
mkdir -p {config,lib/{services,models,utils},public,storage/{logs,certificates,temp,backups},scripts/migrations}

# Verificar estructura
tree -L 2 /var/www/html/certificados
```

**Estructura esperada:**
```
/var/www/html/certificados/
├── config/
├── lib/
│   ├── services/
│   ├── models/
│   └── utils/
├── public/
├── storage/
│   ├── logs/
│   ├── certificates/
│   ├── temp/
│   └── backups/
└── scripts/
    └── migrations/
```

**Verificación:**
- ✅ Directorios creados
- ✅ Permisos correctos (ec2-user:apache)

**Estado:** ⏳ Pendiente

---

#### 4.2 Configurar Permisos

```bash
# Ajustar permisos de storage para que Apache pueda escribir
sudo chown -R ec2-user:apache /var/www/html/certificados/storage
sudo chmod -R 775 /var/www/html/certificados/storage

# Verificar
ls -la /var/www/html/certificados/
```

**Estado:** ⏳ Pendiente

---

### Fase 5: Copiar Archivos del Backend

#### 5.1 Desde Máquina Local a Green

```bash
# Desde tu máquina local

# Comprimir backend (excluyendo node_modules, vendor, .git)
cd /path/to/acg-gestor-certificados
tar -czf backend-$(date +%Y%m%d).tar.gz \
  --exclude='backend/vendor' \
  --exclude='backend/storage/logs/*' \
  --exclude='backend/storage/temp/*' \
  --exclude='backend/.git' \
  backend/

# Copiar a Green
scp -i ~/.ssh/ClaveACG.pem backend-*.tar.gz ec2-user@${GREEN_IP}:/tmp/

# SSH a Green
ssh -i ~/.ssh/ClaveACG.pem ec2-user@${GREEN_IP}

# Descomprimir
cd /var/www/html/certificados
sudo tar -xzf /tmp/backend-*.tar.gz --strip-components=1
```

**Estado:** ⏳ Pendiente

---

#### 5.2 Instalar Dependencias de Composer

```bash
# En Green, dentro de /var/www/html/certificados

# Instalar dependencias de producción
composer install --no-dev --optimize-autoloader

# Verificar que se instaló correctamente
ls -la vendor/

# Debe contener:
# - fpdf/
# - setasign/fpdi
# - aws/aws-sdk-php
# - firebase/php-jwt
# - autoload.php
```

**Verificación:**
- ✅ Directorio `vendor/` creado
- ✅ `vendor/autoload.php` existe
- ✅ Sin errores de instalación

**Estado:** ⏳ Pendiente

---

### Fase 6: Configuración de Variables de Entorno

#### 6.1 Crear archivo .env de Producción

```bash
# En Green

cd /var/www/html/certificados
nano .env
```

**Contenido del archivo `.env`:**
```env
# ============================================================================
# Configuración de Producción - Sistema de Certificados ACG
# ============================================================================

# Base de datos
DB_HOST=acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com
DB_PORT=3306
DB_NAME=moodle51
DB_USER=root
DB_PASSWORD=cl4v3dbr00t!
DB_PREFIX=mdl_

# Moodle Web Service
MOODLE_URL=http://localhost:80
MOODLE_WS_TOKEN=OBTENER_DEL_PLUGIN_INSTALADO
MOODLE_WS_FUNCTION_VALIDATE=local_certificados_sso_validate_token

# API Configuration
API_DEBUG=false
API_LOG_PATH=/var/www/html/certificados/storage/logs
API_CORS_ORIGIN=https://aulavirtual.acgcalidad.co

# Certificados
CERTIFICATES_STORAGE_PATH=/var/www/html/certificados/storage/certificates
CERTIFICATES_TABLE_PREFIX=cc_

# Security
API_SECRET_KEY=GENERAR_CLAVE_SEGURA_64_CARACTERES

# Environment
APP_ENV=production
```

**⚠️ IMPORTANTE - Valores configurados:**

1. **DB_PASSWORD:** `cl4v3dbr00t!` (credencial RDS compartida)
2. **MOODLE_WS_TOKEN:** Obtener del plugin `local_certificados_sso` instalado en Green
3. **API_SECRET_KEY:** Generar con: `php -r "echo bin2hex(random_bytes(32));"`

**Nota:** La contraseña de base de datos es la misma para ambos ambientes (Blue y Green) ya que comparten la misma instancia RDS.

**Estado:** ⏳ Pendiente

---

#### 6.2 Crear archivo config.php de Producción

```bash
# Copiar desde example
cp config/config.example.php config/config.php

# Editar con valores de producción
nano config/config.php
```

**Cambios principales en `config.php`:**

```php
// Cambiar a producción
define('ENVIRONMENT', 'production');
define('DEBUG_MODE', false);

// Usar valores del .env o directamente aquí
define('DB_HOST', 'acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com');
define('DB_PORT', '3306');
define('DB_NAME', 'moodle51');
define('DB_USER', 'root');
define('DB_PASS', 'cl4v3dbr00t!');

// Moodle URL interno (mismo servidor)
define('MOODLE_URL', 'http://localhost:80');
define('MOODLE_TOKEN', 'OBTENER_TOKEN_REAL');

// CORS solo para dominio de producción
define('ALLOWED_ORIGINS', [
    'https://aulavirtual.acgcalidad.co'
]);
```

**Verificación:**
- ✅ Archivo `config.php` creado
- ✅ Valores de producción configurados
- ✅ Debug mode = false

**Estado:** ⏳ Pendiente

---

#### 6.3 Proteger Archivos de Configuración

```bash
# Asegurar que .env y config.php NO sean accesibles por web
sudo chmod 600 .env
sudo chmod 600 config/config.php

# Verificar permisos
ls -la .env config/config.php
```

**Salida esperada:**
```
-rw------- 1 ec2-user apache ... .env
-rw------- 1 ec2-user apache ... config/config.php
```

**Estado:** ⏳ Pendiente

---

### Fase 7: Configuración de Apache

#### 7.1 Crear archivo .htaccess

```bash
cd /var/www/html/certificados/public
nano .htaccess
```

**Contenido:**
```apache
# ACG Certificados Backend - Apache Configuration

# Enable RewriteEngine
<IfModule mod_rewrite.c>
    RewriteEngine On
    RewriteBase /certificados/

    # Redirect all requests to index.php except for existing files
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteRule ^(.*)$ index.php [QSA,L]
</IfModule>

# Security Headers
<IfModule mod_headers.c>
    # CORS Headers (solo dominio de producción)
    Header set Access-Control-Allow-Origin "https://aulavirtual.acgcalidad.co"
    Header set Access-Control-Allow-Methods "GET, POST, PUT, DELETE, OPTIONS"
    Header set Access-Control-Allow-Headers "Content-Type, Authorization"
    Header set Access-Control-Allow-Credentials "true"

    # Security Headers
    Header set X-Content-Type-Options "nosniff"
    Header set X-Frame-Options "SAMEORIGIN"
    Header set X-XSS-Protection "1; mode=block"
    Header always set Strict-Transport-Security "max-age=31536000; includeSubDomains"
</IfModule>

# Deny access to sensitive files
<FilesMatch "^\.">
    Order allow,deny
    Deny from all
</FilesMatch>

# Protect config files
<FilesMatch "(\.env|config\.php)$">
    Order allow,deny
    Deny from all
</FilesMatch>

# PHP Settings
<IfModule mod_php.c>
    php_flag display_errors Off
    php_value error_reporting 0
    php_value max_execution_time 300
    php_value memory_limit 256M
    php_value post_max_size 50M
    php_value upload_max_filesize 50M
</IfModule>
```

**Estado:** ⏳ Pendiente

---

#### 7.2 Configurar Virtual Host o Alias

**Opción A: Usar Alias (Recomendado)**

```bash
# Crear archivo de configuración
sudo nano /etc/httpd/conf.d/certificados.conf
```

**Contenido:**
```apache
# ACG Certificados API
Alias /certificados /var/www/html/certificados/public

<Directory /var/www/html/certificados/public>
    Options -Indexes +FollowSymLinks
    AllowOverride All
    Require all granted

    # Habilitar mod_rewrite
    RewriteEngine On
</Directory>

# Bloquear acceso a directorios sensibles
<DirectoryMatch "^/var/www/html/certificados/(config|lib|storage|scripts|vendor)">
    Require all denied
</DirectoryMatch>
```

**Reiniciar Apache:**
```bash
sudo systemctl restart httpd
sudo systemctl status httpd
```

**Estado:** ⏳ Pendiente

---

### Fase 8: Testing de Funcionamiento

#### 8.1 Test Básico - Endpoint Root

```bash
# Desde Green o desde tu máquina local

# Test 1: Info del API
curl -s http://localhost/certificados/ | python3 -m json.tool

# O desde external:
curl -s https://aulavirtual.acgcalidad.co/certificados/ | python3 -m json.tool
```

**Respuesta esperada:**
```json
{
  "success": true,
  "data": {
    "name": "ACG Certificados API",
    "version": "1.0.0",
    "environment": "production",
    "database": {
      "connected": true,
      "version": "10.11.15-MariaDB"
    },
    "moodle": {
      "url": "http://localhost:80",
      "token_configured": true
    }
  }
}
```

**Verificación:**
- ✅ `"success": true`
- ✅ `"environment": "production"`
- ✅ `"database.connected": true`
- ✅ `"moodle.token_configured": true`

**Estado:** ⏳ Pendiente

---

#### 8.2 Test de Conexión a BD

```bash
# Test 2: Verificar que puede leer certificados
# Usar un userid conocido que tenga certificados

curl -s http://localhost/certificados/certificates/user/8 | python3 -m json.tool
```

**Respuesta esperada:**
```json
{
  "success": true,
  "data": {
    "certificates": [
      {
        "id": 147,
        "numero_certificado": "CV-2119",
        "course_name": "Gestión del riesgo...",
        ...
      }
    ],
    "total": 2
  }
}
```

**Verificación:**
- ✅ Retorna certificados migrados
- ✅ Datos completos (nombre de curso, usuario, etc.)

**Estado:** ⏳ Pendiente

---

#### 8.3 Test de Validación de Token SSO

```bash
# Test 3: Validar token SSO

# Paso 1: Generar token desde Moodle
# - Hacer login en https://aulavirtual.acgcalidad.co
# - Hacer clic en "Mis Certificados" en el menú
# - Copiar el token de la URL: ?moodle_token=XXXXX

# Paso 2: Validar token con backend
TOKEN="COPIAR_TOKEN_AQUI"

curl -X POST http://localhost/certificados/auth/validate \
  -H "Content-Type: application/json" \
  -d "{\"token\": \"$TOKEN\"}" | python3 -m json.tool
```

**Respuesta esperada (éxito):**
```json
{
  "success": true,
  "data": {
    "user": {
      "id": 2,
      "username": "adminav",
      "firstname": "Admin",
      "lastname": "AV",
      "email": "cursosvirtualesacg@gmail.com"
    }
  },
  "message": "Token válido"
}
```

**Verificación:**
- ✅ Token válido retorna datos del usuario
- ✅ Token expirado (>5 min) retorna error 401
- ✅ Token inválido retorna error 401

**Estado:** ⏳ Pendiente

---

#### 8.4 Test de Logs

```bash
# Verificar que los logs se están escribiendo
tail -f /var/www/html/certificados/storage/logs/moodle-service.log
tail -f /var/www/html/certificados/storage/logs/api-errors.log

# Hacer algunas llamadas al API y verificar que se registran
```

**Verificación:**
- ✅ Archivos de log se crean
- ✅ Logs tienen formato correcto con timestamp
- ✅ Logs incluyen información útil para debugging

**Estado:** ⏳ Pendiente

---

### Fase 9: Integración con Plugin Moodle

#### 9.1 Obtener Token del Plugin

```bash
# En la interfaz de Moodle:
# 1. Ir a: Administración del sitio → Servidor → Servicios web → Gestionar tokens
# 2. Buscar el token para el servicio "ACG Certificados SSO"
# 3. Copiar el token
```

**Estado:** ⏳ Pendiente

---

#### 9.2 Actualizar Configuración con Token Real

```bash
# Editar .env o config.php con el token real
nano /var/www/html/certificados/.env

# Actualizar:
MOODLE_WS_TOKEN=TOKEN_REAL_COPIADO_ARRIBA
```

**Estado:** ⏳ Pendiente

---

#### 9.3 Configurar URL del Backend en el Plugin

```bash
# En la interfaz de Moodle:
# 1. Ir a: Administración del sitio → Plugins → Plugins locales → Certificados SSO
# 2. Configurar URL de producción:
#    - URL producción: https://aulavirtual.acgcalidad.co/certificados/
# 3. Desactivar debug mode
# 4. Guardar cambios
```

**Estado:** ⏳ Pendiente

---

### Fase 10: Monitoreo y Validación Final

#### 10.1 Configurar Monitoreo de Logs

```bash
# Configurar logrotate para rotar logs automáticamente
sudo nano /etc/logrotate.d/certificados
```

**Contenido:**
```
/var/www/html/certificados/storage/logs/*.log {
    daily
    rotate 30
    compress
    delaycompress
    notifempty
    create 0640 ec2-user apache
    sharedscripts
}
```

**Estado:** ⏳ Pendiente

---

#### 10.2 Checklist Final de Validación

Antes de declarar la instalación como exitosa, verificar:

**Backend:**
- [ ] API responde en `/certificados/`
- [ ] Conexión a BD funciona
- [ ] Puede listar certificados migrados
- [ ] Logs se escriben correctamente
- [ ] Permisos de archivos correctos (600 para config, 775 para storage)

**Integración Moodle:**
- [ ] Plugin SSO instalado y configurado
- [ ] Token de Web Service válido
- [ ] URL del backend configurada en plugin
- [ ] Enlace "Mis Certificados" visible en menú
- [ ] Clic en enlace genera token y redirige

**Seguridad:**
- [ ] Debug mode desactivado
- [ ] CORS solo permite dominio de producción
- [ ] Archivos .env y config.php NO accesibles por web
- [ ] HTTPS habilitado (Strict-Transport-Security header)
- [ ] Secrets Manager configurado (opcional pero recomendado)

**Datos:**
- [ ] Tabla `cc_certificados_legacy` preservada
- [ ] ~1,409 certificados migrados a nueva tabla
- [ ] Foreign keys funcionando correctamente
- [ ] Queries de listado retornan datos correctos

**Estado General:** ⏳ Pendiente

---

### Fase 11: Copiar Plantillas PDF y Datos

#### 11.1 Copiar Datos de Plantillas desde BD Local

Las tablas `cc_plantillas` y `cc_plantillas_campos` se crean automáticamente por el TemplateService, pero necesitan datos iniciales.

```bash
# Desde máquina local, exportar datos de plantillas
docker exec acg-certificados-db mysqldump -ucertificates_app -pdev_password moodle_dev \
  cc_plantillas cc_plantillas_campos --no-create-info > /tmp/plantillas_data.sql

# Importar en Green (vía RDS)
mysql -h acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com -uroot -p'cl4v3dbr00t!' moodle51 \
  < /tmp/plantillas_data.sql
```

**Estado:** ⏳ Pendiente

---

#### 11.2 Copiar Archivos PDF de Plantillas

```bash
# Extraer archivos del contenedor Moodle local
docker cp acg-moodle-local:/var/www/html/certificados/storage/templates/base/. /tmp/templates-base/
docker cp acg-moodle-local:/var/www/html/certificados/storage/templates/cursos/. /tmp/templates-cursos/

# Subir a Green
scp -r /tmp/templates-base/* ec2-user@${GREEN_IP}:/tmp/
scp -r /tmp/templates-cursos/* ec2-user@${GREEN_IP}:/tmp/

# En Green, mover a ubicación final
ssh ec2-user@${GREEN_IP} 'sudo mkdir -p /var/www/html/certificados/storage/templates/base /var/www/html/certificados/storage/templates/cursos && sudo mv /tmp/certificado-base*.* /var/www/html/certificados/storage/templates/base/ && sudo mv /tmp/curso-*.* /var/www/html/certificados/storage/templates/cursos/ && sudo chown -R ec2-user:apache /var/www/html/certificados/storage/templates/'
```

**Archivos esperados:**
- `storage/templates/base/certificado-base.pdf`
- `storage/templates/base/certificado-base-preview.png`
- `storage/templates/cursos/curso-29-contenidos.pdf`
- `storage/templates/cursos/curso-29-contenidos-preview.png`

**Estado:** ⏳ Pendiente

---

### Fase 12: Configuración SSL para Go-Live

#### 12.1 Arquitectura de VirtualHosts

Green tiene la siguiente configuración de Apache:

| Archivo | ServerName | Puerto | DocumentRoot | Notas |
|---------|------------|--------|--------------|-------|
| `sites-enabled/aulavirtual.acgcalidad.co.conf` | aulavirtual.acgcalidad.co | 80 | `/var/www/html/aulavirtual/public` | Moodle HTTP |
| `sites-enabled/aulavirtual.acgcalidad.co-ssl.conf` | aulavirtual.acgcalidad.co | 443 | `/var/www/html/aulavirtual/public` | Moodle HTTPS + Alias /certificados |
| `conf.d/00-default-ip.conf` | IP directa | 80/443 | `/var/www/html/public` | WordPress + Alias /aulavirtual |

**Importante:** El Alias `/certificados` solo está configurado en el VirtualHost SSL.

#### 12.2 Reemplazar Certificado SSL Temporal

Actualmente Green usa un certificado auto-firmado. Para Go-Live:

```bash
# 1. Obtener certificado SSL real (ej: Let's Encrypt o GoDaddy)
# 2. Reemplazar archivos en Green:
sudo cp /path/to/real-cert.crt /etc/pki/tls/certs/aulavirtual.acgcalidad.co.crt
sudo cp /path/to/real-key.key /etc/pki/tls/private/aulavirtual.acgcalidad.co.key

# 3. Actualizar VirtualHost SSL
sudo nano /etc/httpd/sites-available/aulavirtual.acgcalidad.co-ssl.conf

# Cambiar:
#   SSLCertificateFile /etc/pki/tls/certs/localhost.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/localhost.key
# Por:
#   SSLCertificateFile /etc/pki/tls/certs/aulavirtual.acgcalidad.co.crt
#   SSLCertificateKeyFile /etc/pki/tls/private/aulavirtual.acgcalidad.co.key

# 4. Reiniciar Apache
sudo systemctl restart httpd
```

#### 12.3 Cambio de DNS (Go-Live)

Al momento de Go-Live, en GoDaddy cambiar el registro A de `aulavirtual.acgcalidad.co` para apuntar a la IP de Green.

**No se requiere recompilar la aplicación** - todas las URLs ya están configuradas para usar `https://aulavirtual.acgcalidad.co`.

**Estado:** ⏳ Pendiente

---

## 🔧 Troubleshooting

### Error: "500 Internal Server Error"

**Posibles causas:**
1. Permisos incorrectos en storage/
2. Error en config.php
3. Dependencias de Composer no instaladas

**Solución:**
```bash
# Verificar logs de Apache
sudo tail -50 /var/log/httpd/error_log

# Verificar logs del backend
tail -50 /var/www/html/certificados/storage/logs/api-errors.log

# Verificar permisos
sudo chown -R ec2-user:apache /var/www/html/certificados/storage
sudo chmod -R 775 /var/www/html/certificados/storage
```

---

### Error: "Database connection failed"

**Posibles causas:**
1. Credenciales incorrectas
2. RDS no accesible desde EC2
3. Security Group bloqueando puerto 3306

**Solución:**
```bash
# Test de conexión a RDS desde Green
mysql -h acgdb.c2uujyoezwbf.us-east-1.rds.amazonaws.com \
      -u root -p moodle51
# Password: cl4v3dbr00t!

# Verificar Security Group de RDS permite conexión desde Green
aws ec2 describe-security-groups --group-ids sg-0a885a579f329e23d
```

---

### Error: "Token inválido" en validación SSO

**Posibles causas:**
1. Token expiró (TTL 5 minutos)
2. MOODLE_WS_TOKEN incorrecto en config
3. Función del Web Service no agregada al servicio

**Solución:**
1. Verificar que el token del plugin está configurado correctamente
2. Verificar que la función `local_certificados_sso_validate_token` está agregada al servicio
3. Generar nuevo token y validar inmediatamente

---

## 📊 Checklist de Post-Instalación

### Tareas Inmediatas (Día 1)
- [ ] Backup de BD en S3
- [ ] Monitorear logs por 24 horas
- [ ] Probar flujo completo con usuario real
- [ ] Documentar cualquier issue encontrado

### Tareas Corto Plazo (Semana 1)
- [ ] Implementar generación de PDFs
- [ ] Configurar AWS Secrets Manager
- [ ] Implementar rate limiting
- [ ] Configurar alertas de errores

### Tareas Mediano Plazo (Mes 1)
- [ ] Dashboard de gestores
- [ ] Sistema de notificaciones
- [ ] Detección automática de aprobados
- [ ] Métricas y analytics

---

## 📝 Notas Importantes

### Para Desarrollador Humano (Oliver)

1. **Credenciales:** Todas las credenciales de producción deben obtenerse de AWS Secrets Manager o del cliente directamente. NUNCA hardcodear en código.

2. **Backups:** Antes de cualquier operación en producción, SIEMPRE crear backup.

3. **Testing:** Probar primero en ambiente local/staging antes de aplicar en Green.

4. **Rollback:** Si algo sale mal, el rollback es simplemente:
   ```sql
   DROP TABLE cc_certificados;
   ALTER TABLE cc_certificados_legacy RENAME TO cc_certificados;
   ```

5. **Documentación:** Actualizar este manual a medida que se completan fases.

---

### Para Claude Code

1. **Contexto:** Este manual está diseñado para ser ejecutado paso a paso. Cada fase depende de la anterior.

2. **Variables:** Al ejecutar comandos, reemplazar valores como `${GREEN_IP}`, `$DB_PASS`, etc. con valores reales del contexto.

3. **Verificación:** Después de cada paso, verificar que se completó exitosamente antes de continuar.

4. **Logs:** Siempre revisar logs cuando hay errores antes de intentar soluciones.

5. **Estado:** Actualizar el estado de cada fase (⏳ Pendiente → 🔄 En progreso → ✅ Completado) a medida que se ejecuta.

---

## 📞 Contacto y Soporte

**Desarrollador:** Oliver Castelblanco
**Email:** oliver@acgcalidad.co
**Fecha de creación:** 2026-01-13
**Última actualización:** 2026-01-13

---

**Fin del Manual - Versión 1.0**

*Este documento se actualizará a medida que se complete el desarrollo del backend y se agreguen nuevas funcionalidades.*
