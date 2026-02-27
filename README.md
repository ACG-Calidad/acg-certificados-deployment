# ACG Gestor de Certificados

Sistema completo de gestión de certificados para ACG Calidad, integrado con Moodle 5.1.

## 📦 Componentes del Proyecto

Este proyecto está compuesto por **4 repositorios independientes**:

### 1. Plugin Moodle SSO
**Repositorio:** [acg-certificados-plugin](https://github.com/ACG-Calidad/acg-certificados-plugin)
- Plugin local de Moodle para Single Sign-On
- Generación de tokens temporales (TTL 5 min)
- Web Services para validación
- Enlace automático en navegación (compatible con Boost Union)
- Limpieza automática de tokens

**Clonar en:** `./moodle-plugin/`

### 2. Backend API (PHP 8.4)
**Repositorio:** [acg-certificados-backend](https://github.com/ACG-Calidad/acg-certificados-backend)
- API REST en PHP 8.4
- Generación de PDFs con FPDF + FPDI
- Integración con Moodle Web Services
- Integración con Google Apps Script para emails

**Clonar en:** `./backend/`

### 3. Frontend (Angular 21)
**Repositorio:** [acg-certificados-frontend](https://github.com/ACG-Calidad/acg-certificados-frontend)
- Aplicación web en Angular 21 + Angular Material
- Interfaz responsiva para gestores y participantes
- Autenticación SSO desde Moodle
- Dashboard de estadísticas y reportes

**Clonar en:** `./frontend/acg-certificados-frontend/`

### 4. Deployment (Este repositorio)
**Repositorio:** [acg-certificados-deployment](https://github.com/ACG-Calidad/acg-certificados-deployment)
- Configuración de Docker Compose
- Scripts de utilidad (clone-green-to-local, reset-database)
- Documentación completa
- Manuales de configuración

---

## 🚀 Inicio Rápido

### Prerrequisitos
- Docker & Docker Compose
- Node.js 20+ (para Angular)
- PHP 8.4.14
- Composer
- Angular CLI 21
- Acceso a servidor Moodle 5.1
- Acceso a base de datos MariaDB 10.11.15

### Instalación Local con Docker

#### 1. Clonar repositorio de deployment
```bash
git clone https://github.com/ACG-Calidad/acg-certificados-deployment.git
cd acg-certificados-deployment
```

#### 2. Clonar los 3 sub-repositorios
```bash
# Plugin Moodle
git clone https://github.com/ACG-Calidad/acg-certificados-plugin.git moodle-plugin

# Backend
git clone https://github.com/ACG-Calidad/acg-certificados-backend.git backend

# Frontend
git clone https://github.com/ACG-Calidad/acg-certificados-frontend.git frontend/acg-certificados-frontend
```

#### 3. Iniciar servicios Docker
```bash
docker-compose up -d
```

Esto levanta:
- **Moodle:** http://localhost:8082
- **Backend API:** http://localhost:8080 (cuando esté desarrollado)
- **phpMyAdmin:** http://localhost:8081
- **Frontend:** http://localhost:4200 (cuando esté desarrollado)

#### 4. Configurar Moodle

Seguir los manuales de configuración:
- [SETUP-LOCAL-MOODLE.md](./docs/SETUP-LOCAL-MOODLE.md) - Setup completo del ambiente local
- [MANUAL-CONFIGURACION-PLUGIN.md](./docs/MANUAL-CONFIGURACION-PLUGIN.md) - Configuración del plugin SSO

---

## 📚 Documentación

### Manuales de Configuración
- [Setup Local Moodle](./docs/SETUP-LOCAL-MOODLE.md) - Instalación completa del ambiente de desarrollo
- [Manual de Configuración del Plugin](./docs/MANUAL-CONFIGURACION-PLUGIN.md) - Configuración paso a paso del plugin SSO

### Sesiones de Trabajo
- [Sesión 2026-01-08](./docs/SESION-2026-01-08.md) - Diseño inicial y arquitectura
- [Sesión 2026-01-09](./docs/SESION-2026-01-09.md) - Configuración Docker y clonado de Green
- [Sesión 2026-01-10](./docs/SESION-2026-01-10.md) - Configuración final del plugin

### Documentación Técnica Completa
En el repositorio de actualización:
- Diseño Técnico
- Arquitectura de Base de Datos
- Especificación de API
- Diseño de Interfaz
- Plan de Trabajo

---

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────┐
│                     FRONTEND (Angular 21)                       │
│  • Dashboard de gestor/participante                             │
│  • Listado y descarga de certificados                           │
│  • Validación pública                                            │
└─────────────────────────────────────────────────────────────────┘
                              ↓ ↑ (HTTP REST)
┌─────────────────────────────────────────────────────────────────┐
│                      BACKEND (PHP 8.4)                          │
│  • API REST (19 endpoints)                                       │
│  • Generación de PDFs                                            │
│  • Lógica de negocio                                             │
└─────────────────────────────────────────────────────────────────┘
         ↓ ↑                   ↓ ↑                    ↓ ↑
┌─────────────────┐  ┌─────────────────┐  ┌─────────────────────┐
│  Moodle 5.1     │  │  MariaDB        │  │  Google Apps Script │
│  + Plugin SSO   │  │  10.11.15       │  │  (Emails con PDF)   │
└─────────────────┘  └─────────────────┘  └─────────────────────┘
```

---

## 🔑 Características Principales

### Plugin Moodle SSO
- ✅ **Generación de tokens temporales** con TTL de 5 minutos
- ✅ **Validación de tokens** vía Web Services REST
- ✅ **Enlace en navegación principal** de Moodle (compatible con Boost Union)
- ✅ **Limpieza automática** de tokens expirados (tarea programada cada 15 min)
- ✅ **Tokens de uso único** (se eliminan después de validar)
- ✅ **Auditoría completa** de generación y uso de tokens

### Para Gestores
- ✅ Dashboard con estadísticas en tiempo real
- ✅ Detección automática de usuarios aprobados
- ✅ Aprobación masiva de certificados
- ✅ Generación de PDFs en lote
- ✅ Envío de notificaciones por email
- ✅ Reportes exportables (CSV, Excel)
- ✅ Gestión de plantillas

### Para Participantes
- ✅ Acceso directo desde Moodle (SSO)
- ✅ Listado de todos sus certificados
- ✅ Descarga de PDFs
- ✅ Historial de certificados

### Validación Pública
- ✅ Verificación de autenticidad sin login
- ✅ Búsqueda por ID de certificado
- ✅ Información completa del certificado

---

## 🔐 Seguridad

- **Autenticación:** JWT + SSO desde Moodle
- **Autorización:** Role-based (Admin/Gestor/Participante)
- **Tokens SSO:** Aleatorios seguros (random_bytes + SHA-256)
- **TTL:** 5 minutos para tokens SSO
- **Uso único:** Tokens se invalidan después de usar
- **Validación:** Prevención de SQL injection y XSS
- **Rate Limiting:** Por endpoint
- **HTTPS:** Obligatorio en producción

---

## 📊 Estado del Proyecto

**Fase actual:** Listo para Despliegue en Producción (Green)
**Última validación local:** 2026-01-27 ✅

### ✅ Desarrollo Completado

- [x] Ambiente Docker local funcional
- [x] Moodle 5.1 clonado y configurado
- [x] Plugin SSO instalado y configurado (local)
- [x] Web Services habilitados
- [x] Enlace "Mis Certificados" funcional
- [x] Backend API completo (19 endpoints)
- [x] Frontend Angular 21 completo
- [x] Generación de PDFs con FPDF + FPDI
- [x] Integración con Google Apps Script para notificaciones
- [x] Scripts de migración de datos
- [x] Documentación de despliegue
- [x] Validación completa en entorno local

### 🚀 Pendiente para Go-Live

1. [ ] **Instalar en Green** - Plugin Moodle + Backend + Frontend
2. [ ] **Validación con cliente** - Pruebas de flujos completos
3. [ ] **Ajustes según feedback** - Si el cliente lo requiere
4. [ ] **Sincronizar datos** - Ejecutar sync-blue-to-green.sh antes del switch

Ver guía completa: [DEPLOY-GREEN.md](./docs/DEPLOY-GREEN.md)

---

## 🚀 Despliegue en Producción

### URLs de Producción

| Componente     | URL                                                  |
| -------------- | ---------------------------------------------------- |
| **Frontend**   | `https://aulavirtual.acgcalidad.co/certificados/`    |
| **Backend API**| `https://aulavirtual.acgcalidad.co/certificados/api/`|
| **Moodle**     | `https://aulavirtual.acgcalidad.co/`                 |

### Documentación de Despliegue

- [DEPLOY-GREEN.md](./docs/DEPLOY-GREEN.md) - Guía completa de despliegue en Green
- [MANUAL-INSTALACION-PRODUCCION.md](./docs/MANUAL-INSTALACION-PRODUCCION.md) - Manual detallado de instalación

### Pasos Rápidos

```bash
# 1. Compilar y empaquetar
./scripts/build-production.sh

# 2. (Pre-GoLive) Sincronizar datos Blue → Green
./scripts/sync-blue-to-green.sh

# 3. Subir a Green (IP Elástica fija, no cambia)
GREEN_IP="52.7.23.191"
scp -i ~/.ssh/ClaveACG.pem /tmp/certificados-deploy-*.zip ec2-user@$GREEN_IP:/tmp/

# 4. Seguir instrucciones en DEPLOY-GREEN.md
```

---

## 🛠️ Scripts Útiles

### Build de Producción
Compila frontend, prepara backend y crea paquete ZIP:
```bash
./scripts/build-production.sh
```

### Sincronización Pre-GoLive
Sincroniza datos de certificados de Blue a Green:
```bash
./scripts/sync-blue-to-green.sh
```

### Clone Green to Local
Clona el ambiente de producción (Green en AWS) al ambiente local:
```bash
./scripts/clone-green-to-local.sh
```

### Reset Database
Restaura la base de datos local a un backup específico:
```bash
# Usar backup más reciente
./scripts/reset-database.sh

# Usar backup de fecha específica
./scripts/reset-database.sh 20260109
```

---

## 🧪 Testing

### Probar SSO desde Moodle
1. Ir a http://localhost:8082
2. Login como `adminav`
3. Hacer clic en "Mis Certificados" en el menú
4. Verificar que abre nueva pestaña con token en URL
5. Verificar token en base de datos: `mdl_local_certsso_tokens`

### Probar Web Service de Validación
```bash
# Reemplazar TOKEN_GENERADO con un token real de la URL
curl "http://localhost:8082/webservice/rest/server.php?wstoken=YOUR_WS_TOKEN&wsfunction=local_certificados_sso_validate_token&moodlewsrestformat=json&token=TOKEN_GENERADO"
```

---

## 🚨 Troubleshooting

### Plugin
- **Enlace no aparece:** Purgar cachés (`Administración del sitio → Desarrollo → Purgar todas las cachés`)
- **Token inválido:** Verificar que no haya expirado (5 min) o ya usado
- **Web service error:** Verificar que Web Services y REST estén habilitados

### Docker
- **Contenedor no inicia:** `docker-compose logs [servicio]`
- **BD no conecta:** Verificar puertos en `docker-compose.yml`
- **Permisos:** `chown -R www-data:www-data moodle-files/`

---

## 👥 Equipo

**Desarrollador:** Oliver Castelblanco  
**Cliente:** ACG Calidad  
**Gestor Principal:** adminav (cursosvirtualesacg@gmail.com)

---

## 📄 Licencia

Proyecto privado - ACG Calidad © 2026

---

*Última actualización: 2026-01-27*
