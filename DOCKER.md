# 🐳 Ambiente de Desarrollo Docker - ACG Certificados

Configuración Docker completa para desarrollo local del sistema de gestión de certificados.

---

## 📋 Stack de Servicios

| Servicio | Imagen | Puerto | Descripción |
|----------|--------|--------|-------------|
| **php** | php:8.4-apache | 8080 | Backend PHP + Apache |
| **mariadb** | mariadb:10.11.15 | 3307 | Base de datos |
| **phpmyadmin** | phpmyadmin/phpmyadmin | 8081 | Administración de BD |

---

## 🚀 Inicio Rápido

### Prerrequisitos

- **Docker Desktop** instalado ([Descargar](https://www.docker.com/products/docker-desktop))
- **Docker Compose** (incluido con Docker Desktop)
- Al menos **4GB de RAM** libres
- **5GB de espacio** en disco

### Levantar el Ambiente

```bash
# 1. Navegar al directorio del proyecto
cd acg-gestor-certificados

# 2. Construir las imágenes
docker-compose build

# 3. Levantar los contenedores
docker-compose up -d

# 4. Verificar que los servicios estén corriendo
docker-compose ps
```

**Salida esperada:**
```
NAME                        STATUS    PORTS
acg-certificados-php        Up        0.0.0.0:8080->80/tcp
acg-certificados-db         Up        0.0.0.0:3307->3306/tcp
acg-certificados-phpmyadmin Up        0.0.0.0:8081->80/tcp
```

---

## 🔗 Acceso a Servicios

### Backend API
- **URL:** http://localhost:8080
- **API Endpoints:** http://localhost:8080/api/
- **Ejemplo:** http://localhost:8080/api/auth/login

### phpMyAdmin
- **URL:** http://localhost:8081
- **Usuario:** `root`
- **Contraseña:** `root_password_dev`

**O usar el usuario de la aplicación:**
- **Usuario:** `certificates_app`
- **Contraseña:** `dev_password`
- **Base de datos:** `moodle51_dev`

### Base de Datos (Conexión Externa)
```bash
# Desde terminal
mysql -h 127.0.0.1 -P 3307 -u certificates_app -p
# Password: dev_password

# Desde aplicaciones (DBeaver, TablePlus, etc.)
Host: 127.0.0.1
Port: 3307
User: certificates_app
Password: dev_password
Database: moodle51_dev
```

---

## 📁 Volúmenes Montados

Los siguientes directorios están sincronizados entre tu máquina y los contenedores:

| Directorio Local | Contenedor | Descripción |
|------------------|------------|-------------|
| `./backend` | `/var/www/html` | Código PHP (hot reload) |
| `./docker/php/php.ini` | `/usr/local/etc/php/conf.d/custom.ini` | Configuración PHP |
| `./docker/logs/apache` | `/var/log/apache2` | Logs de Apache |

**Cambios en el código se reflejan inmediatamente** (no necesitas reiniciar contenedores)

---

## 🛠️ Comandos Útiles

### Ver Logs

```bash
# Logs de todos los servicios
docker-compose logs -f

# Logs de un servicio específico
docker-compose logs -f php
docker-compose logs -f mariadb

# Ver solo las últimas 100 líneas
docker-compose logs --tail=100 php
```

### Ejecutar Comandos dentro de Contenedores

```bash
# Acceder al contenedor PHP (bash)
docker-compose exec php bash

# Ejecutar Composer dentro del contenedor
docker-compose exec php composer install
docker-compose exec php composer update

# Ejecutar script PHP
docker-compose exec php php /var/www/html/scripts/migrate_database.php
```

### Gestión de Servicios

```bash
# Detener todos los servicios
docker-compose stop

# Iniciar servicios detenidos
docker-compose start

# Reiniciar un servicio específico
docker-compose restart php

# Detener y eliminar contenedores (datos persisten)
docker-compose down

# Detener, eliminar contenedores Y volúmenes (¡CUIDADO! Borra BD)
docker-compose down -v
```

### Reconstruir Imágenes

```bash
# Reconstruir después de cambios en Dockerfile
docker-compose build

# Forzar reconstrucción sin caché
docker-compose build --no-cache

# Reconstruir y levantar
docker-compose up -d --build
```

---

## 🗄️ Gestión de Base de Datos

### Crear Tablas (Primera Vez)

```bash
# 1. Acceder al contenedor PHP
docker-compose exec php bash

# 2. Ejecutar script de migración
php /var/www/html/scripts/migrate_database.php

# O desde fuera del contenedor:
docker-compose exec php php /var/www/html/scripts/migrate_database.php
```

### Importar Dump de Producción

```bash
# Copiar dump al contenedor
docker cp backup.sql acg-certificados-db:/tmp/

# Importar
docker-compose exec mariadb mysql -u root -proot_password_dev moodle51_dev < /tmp/backup.sql

# O directamente:
docker-compose exec -T mariadb mysql -u root -proot_password_dev moodle51_dev < backup.sql
```

### Exportar Base de Datos

```bash
# Crear dump
docker-compose exec mariadb mysqldump -u root -proot_password_dev moodle51_dev > dump_$(date +%Y%m%d).sql

# Solo tablas cc_*
docker-compose exec mariadb mysqldump -u root -proot_password_dev moodle51_dev cc_certificados cc_certificados_plantillas cc_certificados_log > dump_cc_tables.sql
```

### Resetear Base de Datos

```bash
# ¡CUIDADO! Esto borra todos los datos
docker-compose down -v
docker-compose up -d mariadb
# Esperar a que inicie (ver logs: docker-compose logs -f mariadb)
docker-compose exec php php /var/www/html/scripts/migrate_database.php
```

---

## 🔧 Instalación de Dependencias PHP

```bash
# Instalar dependencias de Composer
docker-compose exec php composer install

# Agregar nueva dependencia
docker-compose exec php composer require vendor/package

# Actualizar dependencias
docker-compose exec php composer update
```

---

## 📊 Monitoreo

### Ver Estado de Contenedores

```bash
# Estado general
docker-compose ps

# Uso de recursos
docker stats

# Inspeccionar un contenedor
docker-compose logs php | tail -50
```

### Verificar Salud de Servicios

```bash
# Health check de MariaDB
docker-compose exec mariadb healthcheck.sh --connect

# Verificar PHP info
docker-compose exec php php -i

# Ver extensiones PHP instaladas
docker-compose exec php php -m
```

---

## 🐛 Troubleshooting

### Puerto 8080 ya está en uso

```bash
# Opción 1: Cambiar puerto en docker-compose.yml
# Editar línea: - "8080:80" por - "8090:80"

# Opción 2: Detener servicio que usa el puerto
lsof -ti:8080 | xargs kill -9
```

### Contenedor PHP no inicia

```bash
# Ver logs detallados
docker-compose logs php

# Verificar permisos
docker-compose exec php ls -la /var/www/html

# Reiniciar desde cero
docker-compose down
docker-compose build --no-cache php
docker-compose up -d
```

### Base de datos no conecta

```bash
# Verificar que MariaDB esté saludable
docker-compose exec mariadb healthcheck.sh --connect

# Ver logs de MariaDB
docker-compose logs mariadb

# Probar conexión manual
docker-compose exec php php -r "new PDO('mysql:host=mariadb;dbname=moodle51_dev', 'certificates_app', 'dev_password');"
```

### Permisos en storage/

```bash
# Dar permisos completos a storage
docker-compose exec php chmod -R 777 /var/www/html/storage

# O desde tu máquina
chmod -R 777 backend/storage
```

---

## 🧹 Limpieza

### Liberar Espacio

```bash
# Eliminar contenedores detenidos
docker container prune

# Eliminar imágenes sin usar
docker image prune

# Eliminar volúmenes huérfanos
docker volume prune

# Limpieza completa (¡CUIDADO!)
docker system prune -a --volumes
```

### Eliminar Solo Este Proyecto

```bash
# Detener y eliminar contenedores
docker-compose down

# Eliminar volúmenes (borra BD)
docker volume rm acg-certificados-mariadb-data

# Eliminar red
docker network rm acg-certificados-network

# Eliminar imágenes
docker rmi acg-gestor-certificados-php
```

---

## 🔐 Seguridad

### Credenciales de Desarrollo

**⚠️ IMPORTANTE:** Estas credenciales son SOLO para desarrollo local.

| Servicio | Usuario | Contraseña |
|----------|---------|------------|
| MariaDB (root) | `root` | `root_password_dev` |
| MariaDB (app) | `certificates_app` | `dev_password` |
| phpMyAdmin | root o certificates_app | (ver arriba) |

**NUNCA** uses estas credenciales en producción.

---

## 📝 Configuración Personalizada

### Modificar PHP.ini

Editar: `docker/php/php.ini`

```ini
# Ejemplo: Aumentar memoria
memory_limit = 1024M

# Aplicar cambios
docker-compose restart php
```

### Modificar MariaDB

Editar: `docker/mariadb/mariadb.cnf`

```ini
# Ejemplo: Aumentar buffer
innodb_buffer_pool_size = 1G

# Aplicar cambios
docker-compose restart mariadb
```

---

## 🚀 Integración con Angular

### Configurar Angular para Usar Docker Backend

En `frontend/acg-certificados-frontend/src/environments/environment.ts`:

```typescript
export const environment = {
  production: false,
  apiUrl: 'http://localhost:8080/api'  // Backend Docker
};
```

### Levantar Stack Completo (Backend + Frontend)

```bash
# Terminal 1: Backend (Docker)
cd acg-gestor-certificados
docker-compose up

# Terminal 2: Frontend (Angular)
cd acg-gestor-certificados/frontend/acg-certificados-frontend
npm install
ng serve
```

Acceso:
- **Frontend:** http://localhost:4200
- **Backend API:** http://localhost:8080/api
- **phpMyAdmin:** http://localhost:8081

---

## 📦 Datos de Prueba

Para facilitar el desarrollo, puedes crear datos de prueba:

```bash
# Acceder al contenedor
docker-compose exec php bash

# Crear script de datos de prueba
php /var/www/html/scripts/seed_test_data.php
```

---

## 🔄 Workflow Recomendado

### Desarrollo Diario

1. **Iniciar ambiente:**
   ```bash
   docker-compose up -d
   ```

2. **Ver logs en tiempo real:**
   ```bash
   docker-compose logs -f php
   ```

3. **Trabajar en el código** (los cambios se reflejan automáticamente)

4. **Al terminar:**
   ```bash
   docker-compose stop
   ```

### Antes de Commitear

```bash
# 1. Asegurarse que todo funciona
docker-compose up -d
docker-compose exec php composer test

# 2. Detener servicios
docker-compose stop

# 3. No commitear archivos de Docker en .gitignore
```

---

## 📖 Documentación Adicional

- [Docker Documentation](https://docs.docker.com/)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [PHP Official Docker Image](https://hub.docker.com/_/php)
- [MariaDB Official Docker Image](https://hub.docker.com/_/mariadb)

---

## 🆘 Soporte

Si tienes problemas:

1. Revisar logs: `docker-compose logs`
2. Verificar estado: `docker-compose ps`
3. Reiniciar servicios: `docker-compose restart`
4. Reconstruir: `docker-compose build --no-cache`

---

**¡Listo para desarrollar! 🚀**

*Última actualización: 2026-01-08*
